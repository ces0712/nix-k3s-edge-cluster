#!/bin/sh
set -eu

. "$(dirname "$0")/lib.sh"

NODE_NAME="${NODE_NAME:-cloud-edge-1}"
TARGET_HOST="${TARGET_HOST:-${TAILNET_HOST:-}}"
TARGET_HOST="${TARGET_HOST:?TARGET_HOST or TAILNET_HOST is required}"
DEPLOY_USER="${DEPLOY_USER:-nixos}"
IDENTITY_FILE="${IDENTITY_FILE:-}"
KUBECONFIG_SERVER="${KUBECONFIG_SERVER:-${TARGET_HOST}}"
OUTPUT_PATH="${OUTPUT_PATH:-${HOME}/.kubeconfig/${NODE_NAME}.yaml}"

ssh_ctx="$(ssh_target "${DEPLOY_USER}" "${TARGET_HOST}" "${IDENTITY_FILE}")"
SSH_OPTS="${ssh_ctx%%|*}"
TARGET="${ssh_ctx#*|}"

mkdir -p "$(dirname "${OUTPUT_PATH}")"

remote_run "${SSH_OPTS}" "${TARGET}" '
set -eu

if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi

$SUDO cat /etc/rancher/k3s/k3s.yaml
' | awk -v server="${KUBECONFIG_SERVER}" '
BEGIN { rewritten = 0 }
/^[[:space:]]*server:[[:space:]]*https:\/\// && rewritten == 0 {
  match($0, /^[[:space:]]*/)
  indent = substr($0, RSTART, RLENGTH)
  print indent "server: https://" server ":6443"
  rewritten = 1
  next
}
{ print }
' > "${OUTPUT_PATH}"

chmod 600 "${OUTPUT_PATH}"
printf 'Wrote kubeconfig to %s\n' "${OUTPUT_PATH}"
