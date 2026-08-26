#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

if [[ ! -f "$PROJECT_DIR/.env" ]]; then
  cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
  secret="$(python3 - <<'PY'
import secrets
print(secrets.token_hex(32))
PY
)"
  postgres_secret="$(python3 - <<'PY'
import secrets
print(secrets.token_hex(32))
PY
)"
  uid="$(id -u)"
  gid="$(id -g)"
  python3 - "$PROJECT_DIR/.env" "$secret" "$postgres_secret" "$uid" "$gid" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
s=s.replace('SEARXNG_SECRET=REPLACE_ME', f'SEARXNG_SECRET={sys.argv[2]}')
s=s.replace('POSTGRES_PASSWORD=REPLACE_ME', f'POSTGRES_PASSWORD={sys.argv[3]}')
s=s.replace('SANDBOX_UID=1000', f'SANDBOX_UID={sys.argv[4]}')
s=s.replace('SANDBOX_GID=1000', f'SANDBOX_GID={sys.argv[5]}')
p.write_text(s)
PY
  echo "Created .env with random SearXNG and PostgreSQL secrets."
else
  echo ".env already exists; leaving it unchanged."
fi

mkdir -p "$PROJECT_DIR"/{models,data/searxng,data/postgres,logs,workspace,package}
chmod 700 "$PROJECT_DIR/.env"
echo "Setup complete."
