#!/bin/bash
set -euo pipefail

set -x
source /opt/blacklist_check/db.conf
export PGHOST PGPORT PGDATABASE PGUSER PGPASSWORD
echo "$PGDATABASE"
RETENTION_DAYS=30

# Public IP(s) to check - DNSBLs only track PUBLIC IPs.
CHECK_IPS=(
    "10.10.10.10"   # mail.example.com
    "10.10.10.11"   # mail2.example.com
)

DNSBL_ZONES=(
    "zen.spamhaus.org"
    "bl.spamcop.net"
    "b.barracudacentral.org"
    "dnsbl.sorbs.net"
    "dnsbl-1.uceprotect.net"
    "psbl.surriel.com"
    "cbl.abuseat.org"
    "bl.mailspike.net"
    "bl.blocklist.de"
    "dyna.spamrats.com"
    "ix.dnsbl.manitu.net"
)

psql -v ON_ERROR_STOP=1 -q << 'SQL'
CREATE TABLE IF NOT EXISTS blacklist_checks (
    id SERIAL PRIMARY KEY,
        psql -v ON_ERROR_STOP=1 -q -c \
            "INSERT INTO blacklist_checks (ip, blacklist, listed) VALUES ('${ip}', '${zone}', ${listed});"
    done
done

# Retention: drop rows older than RETENTION_DAYS so the table doesn't grow forever.
psql -v ON_ERROR_STOP=1 -q -c \
    "DELETE FROM blacklist_checks WHERE checked_at < now() - interval '${RETENTION_DAYS} days';"

if [ "$total_listed" -gt 0 ]; then
    echo "[WARNING] ${total_listed} (ip, blacklist) pair(s) currently listed."
else
    echo "[OK] Not listed on any checked blacklist."
fi
