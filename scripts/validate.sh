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

system_state="$($SUDO timeout 180 systemctl is-system-running --wait || true)"
profile="$(cat /etc/edge-cluster-profile 2>/dev/null || true)"
tailscaled_state="$($SUDO systemctl is-active tailscaled || true)"
k3s_state="$($SUDO systemctl is-active k3s || true)"
searxng_serve_state="$($SUDO systemctl is-active tailscale-searxng-serve || true)"

$SUDO kubectl -n rustdesk rollout status deployment/rustdesk-server --timeout=180s
$SUDO kubectl -n searxng rollout status deployment/searxng --timeout=180s

rustdesk_replicas="$($SUDO kubectl -n rustdesk get deployment rustdesk-server -o jsonpath="{.status.availableReplicas}" 2>/dev/null || true)"
searxng_replicas="$($SUDO kubectl -n searxng get deployment searxng -o jsonpath="{.status.availableReplicas}" 2>/dev/null || true)"
searxng_public_url="$($SUDO kubectl -n searxng get deployment searxng -o jsonpath="{.spec.template.spec.containers[0].env[?(@.name==\"SEARXNG_BASE_URL\")].value}")"
serve_status="$($SUDO tailscale serve status --json)"
searxng_config="$(curl --fail --silent --show-error http://127.0.0.1:8080/config)"
tailscale_fqdn="$($SUDO tailscale status --json | jq -r ".Self.DNSName | rtrimstr(\".\")")"

curl --fail --silent --show-error http://127.0.0.1:8080/healthz >/dev/null
curl --fail --silent --show-error "https://${tailscale_fqdn}/healthz" >/dev/null

echo "hostname: $(hostname)"
echo "system: ${system_state}"
echo "profile: ${profile}"
echo "tailscaled: ${tailscaled_state}"
echo "k3s: ${k3s_state}"
echo "tailscale SearXNG Serve: ${searxng_serve_state}"
echo "rustdesk available replicas: ${rustdesk_replicas:-0}"
echo "searxng available replicas: ${searxng_replicas:-0}"
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
echo "searxng deployment:"
$SUDO kubectl -n searxng get deployment,pods -o wide
echo
echo "listening ports:"
$SUDO ss -lntu | awk "NR == 1 || /21115|21116|21117|6443|8080/"

test "${system_state}" = "running"
test "${profile}" = "runtime"
test "${tailscaled_state}" = "active"
test "${k3s_state}" = "active"
test "${searxng_serve_state}" = "active"
test "${rustdesk_replicas:-0}" -ge 1
test "${searxng_replicas:-0}" -ge 1
test "${searxng_public_url}" = "https://${tailscale_fqdn}/"
printf "%s" "${serve_status}" | grep -Fq "127.0.0.1:8080"
printf "%s" "${searxng_config}" | jq -e "[.engines[] | select(.name == \"braveapi\" and .enabled == true)] | length == 1" >/dev/null
printf "%s" "${searxng_config}" | jq -e "[.engines[] | select(.name == \"google images\" and .enabled == true)] | length == 1" >/dev/null
printf "%s" "${searxng_config}" | jq -e "[.engines[] | select(.name == \"google\" or .name == \"brave\")] | length == 0" >/dev/null
$SUDO ss -lnt | grep -Eq "127\\.0\\.0\\.1:8080"
! $SUDO ss -lnt | grep -Eq "(^|[[:space:]])(0\\.0\\.0\\.0|\\[::\\]):8080([[:space:]]|$)"
'
