#!/bin/bash
set -euo pipefail

source /opt/blacklist_check/db.conf
export PGHOST PGPORT PGDATABASE PGUSER PGPASSWORD

SMTP_HOST="smtp.example.com"
SMTP_PORT="25"
MAIL_FROM=""
MAIL_TO=""
REPORT_DATE=$(date '+%Y-%m-%d')

LISTED_ROWS=$(psql -v ON_ERROR_STOP=1 -q -A -t -F'|' -c "
    SELECT ip, blacklist
    FROM (
        SELECT DISTINCT ON (ip, blacklist) ip, blacklist, listed
        FROM blacklist_checks
        ORDER BY ip, blacklist, checked_at DESC
    ) latest
    WHERE listed = true
    ORDER BY ip, blacklist;
")

TOTAL_LISTED=$(psql -v ON_ERROR_STOP=1 -q -A -t -c "
    SELECT COUNT(*) FROM (
        SELECT DISTINCT ON (ip, blacklist) ip, blacklist, listed
        FROM blacklist_checks
        ORDER BY ip, blacklist, checked_at DESC
    ) latest WHERE listed = true;
")

LAST_CHECK=$(psql -v ON_ERROR_STOP=1 -q -A -t -c "SELECT MAX(checked_at) FROM blacklist_checks;")

# Only send an email when at least one (ip, blacklist) pair is currently listed.
if [ "$TOTAL_LISTED" -eq 0 ]; then
    echo "[OK] Not listed on any checked blacklist. No email sent."
    exit 0
fi

SUBJECT="[WARNING] DNSBL Blacklist Report ${REPORT_DATE} - ${TOTAL_LISTED} listing(s) found"

BODY_FILE=$(mktemp)
trap 'rm -f "$BODY_FILE"' EXIT

{
    echo "Дневен DNSBL blacklist доклад (${REPORT_DATE})"
    echo "Последна проверка: ${LAST_CHECK}"
    echo ""
    while IFS='|' read -r ip blacklist; do
        [ -z "$ip" ] && continue
        echo "Сървъра ${ip} участва в черен списък \"${blacklist}\"."
    done <<< "$LISTED_ROWS"
} > "$BODY_FILE"

{
    printf 'From: %s\r\n' "$MAIL_FROM"
    printf 'To: %s\r\n' "$MAIL_TO"
    printf 'Subject: %s\r\n' "$SUBJECT"
    printf 'MIME-Version: 1.0\r\n'
    printf 'Content-Type: text/plain; charset=UTF-8\r\n'
    printf '\r\n'
    sed 's/$/\r/' "$BODY_FILE"
} | curl -s --url "smtp://${SMTP_HOST}:${SMTP_PORT}" \
        --mail-from "$MAIL_FROM" \
        --mail-rcpt "$MAIL_TO" \
        --upload-file -
