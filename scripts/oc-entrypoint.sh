#!/usr/bin/env bash
set -uo pipefail

CONFIG_SRC="${HOME}/.config/opencode/opencode.json"
CONFIG_GEN="${HOME}/.cache/opencode-config.json"

OLLAMA_HOST_VALUE="${OLLAMA_HOST:-http://host.docker.internal:11434}"
OLLAMA_HOST_VALUE="${OLLAMA_HOST_VALUE%/}"
TAGS_URL="${OLLAMA_HOST_VALUE}/api/tags"

if [[ ! -f "${CONFIG_SRC}" ]]; then
    echo "oc-entrypoint: no config at ${CONFIG_SRC}; starting opencode without ollama provider" >&2
    exec opencode "$@"
fi

MODEL_NAMES_CSV="$(curl -fsS --max-time 5 "$TAGS_URL" 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    print(",".join(m.get("name", "") for m in (data.get("models") or []) if m.get("name")))
except Exception:
    pass
' 2>/dev/null || true)"

if [[ -z "${MODEL_NAMES_CSV}" ]]; then
    echo "oc-entrypoint: no ollama models reachable at ${OLLAMA_HOST_VALUE}; starting opencode with mounted config" >&2
    exec opencode "$@"
fi

mkdir -p "$(dirname "${CONFIG_GEN}")"
python3 - "${CONFIG_SRC}" "${CONFIG_GEN}" "${MODEL_NAMES_CSV}" <<'PY'
import json, sys, shutil
src, dst, csv = sys.argv[1], sys.argv[2], sys.argv[3]
shutil.copyfile(src, dst)
with open(dst) as f:
    cfg = json.load(f)
provider = cfg.setdefault("provider", {}).setdefault("ollama", {})
names = [n for n in csv.split(",") if n]
provider["models"] = {n: {"name": n} for n in names}
with open(dst, "w") as f:
    json.dump(cfg, f, indent=2)
PY

FIRST_MODEL="${MODEL_NAMES_CSV%%,*}"
COUNT=$(echo "${MODEL_NAMES_CSV}" | tr ',' '\n' | wc -l | tr -d ' ')
echo "oc-entrypoint: found ${COUNT} ollama model(s) at ${OLLAMA_HOST_VALUE}; using default ollama/${FIRST_MODEL}" >&2

export OPENCODE_CONFIG="${CONFIG_GEN}"
exec opencode --model "ollama/${FIRST_MODEL}" "$@"