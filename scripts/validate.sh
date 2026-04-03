#!/bin/sh
set -eu

. "$(dirname "$0")/lib.sh"

TARGET_HOST="${TARGET_HOST:-${TAILNET_HOST:-}}"
TARGET_HOST="${TARGET_HOST:?TARGET_HOST or TAILNET_HOST is required}"
DEPLOY_USER="${DEPLOY_USER:-nixos}"
IDENTITY_FILE="${IDENTITY_FILE:-}"

ssh_ctx="$(ssh_target "${DEPLOY_USER}" "${TARGET_HOST}" "${IDENTITY_FILE}")"
SSH_OPTS="${ssh_ctx%%|*}"
TARGET="${ssh_ctx#*|}"

remote_wait_for_ssh "${SSH_OPTS}" "${TARGET}"

remote_run "${SSH_OPTS}" "${TARGET}" '
set -eu

if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

profile="$(cat /etc/edge-cluster-profile)"
tailscaled_state="$($SUDO systemctl is-active tailscaled || true)"
k3s_state="$($SUDO systemctl is-active k3s || true)"
rustdesk_replicas="$($SUDO kubectl -n rustdesk get deployment rustdesk-server -o jsonpath="{.status.availableReplicas}" 2>/dev/null || true)"

echo "hostname: $(hostname)"
echo "profile: ${profile}"
echo "tailscaled: ${tailscaled_state}"
echo "k3s: ${k3s_state}"
echo "rustdesk available replicas: ${rustdesk_replicas:-0}"
echo
echo "tailscale status:"
$SUDO tailscale status --self || true
echo
echo "k3s nodes:"
$SUDO kubectl get nodes -o wide
echo
echo "rustdesk deployment:"
$SUDO kubectl -n rustdesk get deployment,pods -o wide
echo
echo "listening ports:"
$SUDO ss -lntu | awk "NR == 1 || /21115|21116|21117|6443/"

test "${profile}" = "runtime"
test "${tailscaled_state}" = "active"
test "${k3s_state}" = "active"
test "${rustdesk_replicas:-0}" -ge 1
'
