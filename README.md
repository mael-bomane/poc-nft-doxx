# poc-nft-doxx

Tiny POC: serve an NFT image via nginx, log requester IPs keyed by wallet in SQLite.

> Threat model demo. The whole point: a public image URL leaks viewer IPs once the wallet is included as a query param. Useful for thinking about NFT metadata privacy.

## Stack

- **nginx** — serves static image, custom log format with `$arg_wallet` + `$remote_addr`
- **logger** — alpine + sqlite3, tails access log, upserts `wallet -> [ip, ...]` JSON array
- **sqlite** — single-file KV at `data/visits.db`

## Layout

```
docker-compose.yaml
nginx/nginx.conf       # log format: wallet, ip, xff, path, status (tab-separated)
html/image.png         # the "NFT"
logger/watch.sh        # tail + upsert (json_each + UNION dedup)
logger/query.sh        # inspect KV store
data/visits.db         # created on first hit (gitignored)
```

## Run

```sh
docker compose up -d
curl "http://localhost:8080/image.png?wallet=AbC123SoLAnAPubKey"
./logger/query.sh                    # dump all wallets
./logger/query.sh AbC123SoLAnAPubKey # ips for one wallet
```

## Schema

```sql
CREATE TABLE wallet_ips (
  wallet     TEXT PRIMARY KEY,
  ips        TEXT NOT NULL DEFAULT '[]',  -- JSON array, deduped
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

## Caveats

- Wallet param is unauthenticated — trivially spoofable. Real flow needs signed nonce.
- `$remote_addr` = proxy IP if behind one. Add `set_real_ip_from` + `real_ip_header X-Forwarded-For` to nginx.conf.
- No retention policy. Set up a cron / `DELETE WHERE updated_at < ...` if you care.
