#!/bin/sh
set -eu

LOG="${LOG:-/var/log/nginx/access.log}"
DB="${DB_PATH:-/data/visits.db}"

mkdir -p "$(dirname "$DB")"

sqlite3 "$DB" <<'SQL'
PRAGMA journal_mode=WAL;
CREATE TABLE IF NOT EXISTS wallet_ips (
  wallet TEXT PRIMARY KEY,
  ips    TEXT NOT NULL DEFAULT '[]',
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
SQL

echo "[logger] db=$DB log=$LOG"
while [ ! -f "$LOG" ]; do sleep 1; done

is_image() {
  case "$1" in
    *.png|*.jpg|*.jpeg|*.gif|*.webp|*.svg) return 0 ;;
    *) return 1 ;;
  esac
}

sql_escape() { printf "%s" "$1" | sed "s/'/''/g"; }

tail -F -n 0 "$LOG" | while IFS= read -r line; do
  wallet=$(printf "%s" "$line" | sed -n 's/.*wallet=\([^\t]*\).*/\1/p')
  ip=$(printf "%s"     "$line" | sed -n 's/.*ip=\([^\t]*\).*/\1/p')
  path=$(printf "%s"   "$line" | sed -n 's/.*path=\([^\t]*\).*/\1/p')
  status=$(printf "%s" "$line" | sed -n 's/.*status=\([^\t]*\).*/\1/p')

  [ -z "$wallet" ] && continue
  [ -z "$ip" ]     && continue
  [ "$status" != "200" ] && continue
  is_image "$path" || continue

  w=$(sql_escape "$wallet")
  i=$(sql_escape "$ip")

  sqlite3 "$DB" <<SQL
INSERT INTO wallet_ips(wallet, ips, updated_at)
VALUES('$w', json_array('$i'), datetime('now'))
ON CONFLICT(wallet) DO UPDATE SET
  ips = (
    SELECT json_group_array(v) FROM (
      SELECT value AS v FROM json_each(wallet_ips.ips)
      UNION
      SELECT '$i'
    )
  ),
  updated_at = datetime('now');
SQL

  echo "[logger] $wallet <- $ip ($path)"
done
