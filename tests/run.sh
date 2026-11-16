#!/usr/bin/env bash
# Apply the vulnerable schema, prove the leaks, apply the fix, prove 0 leaks.
# Requires: psql, a PostgreSQL 14+ server, and DATABASE_URL.
# Usage: DATABASE_URL=postgres://postgres:postgres@localhost:5432/ledgerline bash tests/run.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${DATABASE_URL:?Set DATABASE_URL, e.g. postgres://postgres:postgres@localhost:5432/ledgerline}"

ALICE='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
BOB='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2'
TEAM_A='11111111-1111-4111-8111-111111111111'
TEAM_B='22222222-2222-4222-8222-222222222222'

# psql 15+ accepts a URI. Disable SSL for the local / CI server.
export PGSSLMODE="${PGSSLMODE:-disable}"
export PGPASSWORD="${PGPASSWORD:-}"

RED=$'\033[31m'
GRN=$'\033[32m'
YEL=$'\033[33m'
CYN=$'\033[36m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
RST=$'\033[0m'

psqlx() {
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -X -q "$@"
}

# Run a query as a given role + jwt sub. Prints only tuples (aligned).
as_user() {
  local role="$1" uid="$2"
  shift 2
  local query="$*"
  psqlx -P pager=off <<SQL
SET ROLE ${role};
SELECT set_config('request.jwt.claim.sub', '${uid}', false);
${query}
RESET ROLE;
SQL
}

as_user_t() {
  local role="$1" uid="$2"
  shift 2
  local query="$*"
  psqlx -A -t <<SQL
SET ROLE ${role};
SELECT set_config('request.jwt.claim.sub', '${uid}', false);
${query}
RESET ROLE;
SQL
}

reset_db() {
  psqlx <<'SQL'
DROP SCHEMA IF EXISTS public CASCADE;
DROP SCHEMA IF EXISTS auth CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO CURRENT_USER;
SQL
}

apply_vulnerable() {
  reset_db
  psqlx -f "$ROOT/supabase/migrations/0001_schema.sql"
  psqlx -f "$ROOT/supabase/seed.sql"
  psqlx -f "$ROOT/supabase/migrations/0002_vulnerable.sql"
}

apply_fixed() {
  psqlx -f "$ROOT/supabase/migrations/0003_fixed.sql"
}

print_invoices() {
  local role="$1" uid="$2" label="$3"
  echo "${DIM}-- ${label}${RST}"
  as_user "$role" "$uid" "
SELECT
  invoice_number,
  (SELECT name FROM teams t WHERE t.id = invoices.team_id) AS team,
  client_name,
  to_char(amount_cents / 100.0, 'FM999,999,990.00') AS amount,
  status,
  CASE WHEN team_id = '${TEAM_B}' AND '${uid}' = '${ALICE}' THEN 'LEAKED'
       WHEN team_id = '${TEAM_A}' AND '${uid}' = '${BOB}' THEN 'LEAKED'
       ELSE ''
  END AS flag
FROM invoices
ORDER BY invoice_number;
"
}

print_notes() {
  local role="$1" uid="$2" label="$3"
  echo "${DIM}-- ${label}${RST}"
  as_user "$role" "$uid" "
SELECT
  (SELECT invoice_number FROM invoices i WHERE i.id = invoice_notes.invoice_id) AS invoice,
  (SELECT name FROM teams t WHERE t.id = invoice_notes.team_id) AS team,
  body,
  CASE WHEN team_id = '${TEAM_B}' AND '${uid}' = '${ALICE}' THEN 'LEAKED'
       WHEN team_id = '${TEAM_A}' AND '${uid}' = '${BOB}' THEN 'LEAKED'
       ELSE ''
  END AS flag
FROM invoice_notes
ORDER BY invoice;
"
}

count_leaked() {
  local role="$1" uid="$2" table="$3"
  local other_team
  if [ "$uid" = "$ALICE" ]; then other_team="$TEAM_B"; else other_team="$TEAM_A"; fi
  as_user_t "$role" "$uid" "SELECT count(*) FROM ${table} WHERE team_id = '${other_team}';" | tr -d '[:space:]'
}

count_total() {
  local role="$1" uid="$2" table="$3"
  as_user_t "$role" "$uid" "SELECT count(*) FROM ${table};" | tr -d '[:space:]'
}

# --- API route simulation (findings 3 + 4) ---------------------------------
# Vulnerable handler: no session check, query by attacker-supplied team id,
# connection uses service_role (BYPASSRLS) — same as a server client created
# with the service-role key, or a browser bundle that shipped that key.
api_vulnerable() {
  local team_id="$1"
  psqlx -A -t <<SQL
SET ROLE service_role;
SELECT count(*) FROM invoices WHERE team_id = '${team_id}';
RESET ROLE;
SQL
}

# Fixed handler: require a session (uid). Derive the team from profiles.
# Reject a requested team that is not the caller's. Query as authenticated
# so RLS is a second line of defence.
api_fixed() {
  local uid="${1:-}"
  local requested="${2:-}"
  if [ -z "$uid" ]; then
    echo "401"
    return
  fi
  local caller_team
  caller_team="$(psqlx -A -t <<SQL
SELECT team_id::text FROM profiles WHERE id = '${uid}';
SQL
)"
  caller_team="$(echo "$caller_team" | tr -d '[:space:]')"
  if [ -z "$caller_team" ]; then
    echo "401"
    return
  fi
  if [ -n "$requested" ] && [ "$requested" != "$caller_team" ]; then
    echo "403"
    return
  fi
  as_user_t authenticated "$uid" "SELECT count(*) FROM invoices WHERE team_id = '${caller_team}';" | tr -d '[:space:]'
}

echo "${BOLD}Ledgerline sample audit — RLS tests (fictional data)${RST}"
echo "Database: ${DATABASE_URL%%@*}@…"
echo

echo "${YEL}${BOLD}========== BEFORE THE FIX (vulnerable schema) ==========${RST}"
apply_vulnerable

print_invoices authenticated "$ALICE" "Alice (Apex Studio) SELECT invoices  [USING (true) policy]"
print_notes    authenticated "$ALICE" "Alice (Apex Studio) SELECT invoice_notes  [RLS disabled]"
print_invoices service_role  "$ALICE" "Browser with service-role key (BYPASSRLS) SELECT invoices"

BEFORE_ALICE_INV_LEAK=$(count_leaked authenticated "$ALICE" invoices)
BEFORE_ALICE_INV_TOTAL=$(count_total authenticated "$ALICE" invoices)
BEFORE_ALICE_NOTE_LEAK=$(count_leaked authenticated "$ALICE" invoice_notes)
BEFORE_ALICE_NOTE_TOTAL=$(count_total authenticated "$ALICE" invoice_notes)
BEFORE_SVC_INV=$(count_total service_role "$ALICE" invoices)
BEFORE_API_UNAUTH_B="$(api_vulnerable "$TEAM_B" | tr -d '[:space:]')"

echo
echo "Alice invoice rows:          ${BEFORE_ALICE_INV_TOTAL}  (leaked from team B: ${BEFORE_ALICE_INV_LEAK})"
echo "Alice invoice_notes rows:    ${BEFORE_ALICE_NOTE_TOTAL}  (leaked from team B: ${BEFORE_ALICE_NOTE_LEAK})"
echo "Service-role invoice rows:   ${BEFORE_SVC_INV}"
echo "Unauthenticated API ?teamId=Northwind Labs: ${BEFORE_API_UNAUTH_B} rows"

if [ "$BEFORE_ALICE_INV_LEAK" != "2" ] || [ "$BEFORE_ALICE_NOTE_LEAK" != "2" ] \
   || [ "$BEFORE_SVC_INV" != "4" ] || [ "$BEFORE_API_UNAUTH_B" != "2" ]; then
  echo "${RED}BEFORE counts were not the expected leaks. Aborting.${RST}"
  exit 1
fi
echo "${RED}LEAK CONFIRMED — Alice can read Northwind Labs invoices and notes.${RST}"

echo
echo "${GRN}${BOLD}========== AFTER THE FIX (0003_fixed.sql + fixed API) ==========${RST}"
apply_fixed

print_invoices authenticated "$ALICE" "Alice (Apex Studio) SELECT invoices  [team-scoped policy]"
print_notes    authenticated "$ALICE" "Alice (Apex Studio) SELECT invoice_notes  [RLS enabled + forced]"
print_invoices authenticated "$BOB"   "Bob (Northwind Labs) SELECT invoices"
print_invoices service_role  "$ALICE" "Service-role key still bypasses RLS (why it must never ship to the browser)"

AFTER_ALICE_INV_LEAK=$(count_leaked authenticated "$ALICE" invoices)
AFTER_ALICE_INV_TOTAL=$(count_total authenticated "$ALICE" invoices)
AFTER_ALICE_NOTE_LEAK=$(count_leaked authenticated "$ALICE" invoice_notes)
AFTER_ALICE_NOTE_TOTAL=$(count_total authenticated "$ALICE" invoice_notes)
AFTER_BOB_INV_LEAK=$(count_leaked authenticated "$BOB" invoices)
AFTER_BOB_INV_TOTAL=$(count_total authenticated "$BOB" invoices)
AFTER_SVC_INV=$(count_total service_role "$ALICE" invoices)
AFTER_API_UNAUTH="$(api_fixed '' "$TEAM_B")"
AFTER_API_ALICE_B="$(api_fixed "$ALICE" "$TEAM_B")"
AFTER_API_ALICE_OWN="$(api_fixed "$ALICE" "")"

echo
echo "Alice invoice rows:          ${AFTER_ALICE_INV_TOTAL}  (leaked from team B: ${AFTER_ALICE_INV_LEAK})"
echo "Alice invoice_notes rows:    ${AFTER_ALICE_NOTE_TOTAL}  (leaked from team B: ${AFTER_ALICE_NOTE_LEAK})"
echo "Bob invoice rows:            ${AFTER_BOB_INV_TOTAL}  (leaked from team A: ${AFTER_BOB_INV_LEAK})"
echo "Service-role invoice rows:   ${AFTER_SVC_INV}  (still all rows — key must stay server-side)"
echo "Fixed API, no session:       ${AFTER_API_UNAUTH}"
echo "Fixed API, Alice asks team B:${AFTER_API_ALICE_B}"
echo "Fixed API, Alice own team:   ${AFTER_API_ALICE_OWN} rows"

fail=0
[ "$AFTER_ALICE_INV_LEAK" = "0" ] || { echo "${RED}FAIL: Alice still leaks invoices${RST}"; fail=1; }
[ "$AFTER_ALICE_INV_TOTAL" = "2" ] || { echo "${RED}FAIL: Alice should see 2 of her invoices${RST}"; fail=1; }
[ "$AFTER_ALICE_NOTE_LEAK" = "0" ] || { echo "${RED}FAIL: Alice still leaks notes${RST}"; fail=1; }
[ "$AFTER_ALICE_NOTE_TOTAL" = "2" ] || { echo "${RED}FAIL: Alice should see 2 of her notes${RST}"; fail=1; }
[ "$AFTER_BOB_INV_LEAK" = "0" ] || { echo "${RED}FAIL: Bob still leaks invoices${RST}"; fail=1; }
[ "$AFTER_BOB_INV_TOTAL" = "2" ] || { echo "${RED}FAIL: Bob should see 2 of his invoices${RST}"; fail=1; }
[ "$AFTER_SVC_INV" = "4" ] || { echo "${RED}FAIL: service_role should still see 4 (BYPASSRLS)${RST}"; fail=1; }
[ "$AFTER_API_UNAUTH" = "401" ] || { echo "${RED}FAIL: unauthenticated API should be 401${RST}"; fail=1; }
[ "$AFTER_API_ALICE_B" = "403" ] || { echo "${RED}FAIL: Alice requesting team B should be 403${RST}"; fail=1; }
[ "$AFTER_API_ALICE_OWN" = "2" ] || { echo "${RED}FAIL: Alice own-team API should return 2${RST}"; fail=1; }

if [ "$fail" -ne 0 ]; then
  echo "${RED}${BOLD}TESTS FAILED${RST}"
  exit 1
fi

mkdir -p "$ROOT/docs" "$ROOT/tests"
cat > "$ROOT/tests/results.json" <<JSON
{
  "app": "Ledgerline (fictional demo)",
  "before": {
    "alice_invoices_total": ${BEFORE_ALICE_INV_TOTAL},
    "alice_invoices_leaked": ${BEFORE_ALICE_INV_LEAK},
    "alice_notes_total": ${BEFORE_ALICE_NOTE_TOTAL},
    "alice_notes_leaked": ${BEFORE_ALICE_NOTE_LEAK},
    "service_role_invoices": ${BEFORE_SVC_INV},
    "unauthenticated_api_team_b": ${BEFORE_API_UNAUTH_B}
  },
  "after": {
    "alice_invoices_total": ${AFTER_ALICE_INV_TOTAL},
    "alice_invoices_leaked": ${AFTER_ALICE_INV_LEAK},
    "alice_notes_total": ${AFTER_ALICE_NOTE_TOTAL},
    "alice_notes_leaked": ${AFTER_ALICE_NOTE_LEAK},
    "bob_invoices_total": ${AFTER_BOB_INV_TOTAL},
    "bob_invoices_leaked": ${AFTER_BOB_INV_LEAK},
    "service_role_invoices": ${AFTER_SVC_INV},
    "fixed_api_no_session": "${AFTER_API_UNAUTH}",
    "fixed_api_alice_requests_team_b": "${AFTER_API_ALICE_B}",
    "fixed_api_alice_own": ${AFTER_API_ALICE_OWN}
  }
}
JSON
cp "$ROOT/tests/results.json" "$ROOT/docs/results.json"

echo
echo "${GRN}${BOLD}ALL TESTS PASSED${RST} — leaked rows BEFORE=2+2, AFTER=0. results: tests/results.json"
