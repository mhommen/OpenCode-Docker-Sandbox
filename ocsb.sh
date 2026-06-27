#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE_NAME:-opencode-sandbox}:${IMAGE_TAG:-latest}"

usage() {
    cat <<EOF
usage: ocsb.sh [-o OLLAMA_HOST] <host-path>

    -o, --ollama URL    Override Ollama host (default: from image, http://host.docker.internal:11434)
    -h, --help          Show this help

Mounts <host-path> into the container as /source and starts OpenCode.
Container name is derived from the directory basename + '-ocsb'.
EOF
}

OLLAMA_OVERRIDE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--ollama)
            [[ $# -ge 2 ]] || { echo "error: $1 requires an argument" >&2; exit 2; }
            OLLAMA_OVERRIDE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "error: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
        *)
            break
            ;;
    esac
done

[[ $# -eq 1 ]] || { echo "error: expected exactly one host path" >&2; usage >&2; exit 2; }

HOST_PATH="$1"

if [[ ! -d "${HOST_PATH}" ]]; then
    echo "error: ${HOST_PATH} is not a directory" >&2
    exit 1
fi

HOST_PATH="$(cd "${HOST_PATH}" && pwd)"
DIR_NAME="$(basename "${HOST_PATH}")"
CONTAINER_NAME="${DIR_NAME}-ocsb"

if [[ -n "${OLLAMA_OVERRIDE}" ]]; then
    OLLAMA_BASE_URL="${OLLAMA_OVERRIDE}"
else
    OLLAMA_BASE_URL="http://host.docker.internal:11434"
fi

OLLAMA_BASE_URL="${OLLAMA_BASE_URL%/}"
OLLAMA_OPENAI_URL="${OLLAMA_BASE_URL}/v1"

CONFIG_FILE="$(mktemp -t ocsb-config.XXXXXX.json)"
trap 'rm -f "${CONFIG_FILE}"' EXIT

cat > "${CONFIG_FILE}" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Ollama (local)",
      "options": {
        "baseURL": "${OLLAMA_OPENAI_URL}"
      },
      "models": {}
    }
  }
}
EOF

DOCKER_ARGS=(
    -it
    --rm
    --name "${CONTAINER_NAME}"
    --add-host=host.docker.internal:host-gateway
    --cap-drop=ALL
    --security-opt=no-new-privileges
    -v "${HOST_PATH}:/source"
    -v "${CONFIG_FILE}:/home/developer/.config/opencode/opencode.json:ro"
    -e "OLLAMA_HOST=${OLLAMA_BASE_URL}"
)

echo "==> Using Ollama at ${OLLAMA_BASE_URL}"
exec docker run "${DOCKER_ARGS[@]}" "${IMAGE}"