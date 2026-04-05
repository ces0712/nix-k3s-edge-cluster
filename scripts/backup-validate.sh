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

backup_enabled="$($SUDO nixos-option edgeCluster.backup.enable 2>/dev/null | awk "END { print \$NF }")"

if [ "${backup_enabled}" != "true" ]; then
  echo "Backup module disabled on target; skipping backup validation."
  exit 0
fi

repo_secret="$($SUDO nixos-option edgeCluster.backup.repositorySecret 2>/dev/null | awk "END { print \$NF }")"
password_secret="$($SUDO nixos-option edgeCluster.backup.passwordSecret 2>/dev/null | awk "END { print \$NF }")"
env_secret="$($SUDO nixos-option edgeCluster.backup.environmentSecret 2>/dev/null | awk "END { print \$NF }")"

echo "unit state:"
$SUDO systemctl is-enabled restic-backups-edge-cluster.timer
echo
echo "timer state:"
$SUDO systemctl is-active restic-backups-edge-cluster.timer
echo
echo "secret files:"
for path in \
  "/run/secrets/${repo_secret}" \
  "/run/secrets/${password_secret}" \
  "/run/secrets/${env_secret}"
do
  if $SUDO test -f "$path"; then
    echo "ok  $path"
  else
    echo "missing  $path" >&2
    exit 1
  fi
done

echo
echo "repository access:"
$SUDO -u restic-backup restic snapshots \
  --repository-file "/run/secrets/${repo_secret}" \
  --password-file "/run/secrets/${password_secret}" \
  --environment-file "/run/secrets/${env_secret}" \
  --compact
'
