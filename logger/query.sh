#!/bin/sh
# Inspect KV store. Usage:
#   ./query.sh                    # dump all
#   ./query.sh <wallet>           # ips for one wallet
set -eu
DB="${DB_PATH:-./data/visits.db}"

if [ $# -eq 0 ]; then
  sqlite3 "$DB" "SELECT wallet, ips, updated_at FROM wallet_ips ORDER BY updated_at DESC;"
else
  sqlite3 "$DB" "SELECT ips FROM wallet_ips WHERE wallet = '$1';"
fi
