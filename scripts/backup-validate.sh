#!/bin/sh
set -eu

. "$(dirname "$0")/lib.sh"

TARGET_HOST="${TARGET_HOST:-${TAILNET_HOST:-}}"
TARGET_HOST="${TARGET_HOST:?TARGET_HOST or TAILNET_HOST is required}"
DEPLOY_USER="${DEPLOY_USER:-nixos}"
IDENTITY_FILE="${IDENTITY_FILE:-}"
RESTIC_REPOSITORY_SECRET="${RESTIC_REPOSITORY_SECRET:-restic/borgbase_repo}"
RESTIC_PASSWORD_SECRET="${RESTIC_PASSWORD_SECRET:-restic/borgbase_password}"
RESTIC_ENVIRONMENT_SECRET="${RESTIC_ENVIRONMENT_SECRET:-}"

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

if ! $SUDO systemctl list-unit-files restic-backups-edge-cluster.timer --no-legend 2>/dev/null | grep -q "^restic-backups-edge-cluster.timer"; then
  echo "Backup module disabled on target; skipping backup validation."
  exit 0
fi

echo "unit state:"
$SUDO systemctl is-enabled restic-backups-edge-cluster.timer
echo
echo "timer state:"
$SUDO systemctl is-active restic-backups-edge-cluster.timer
echo
echo "secret files:"
for path in \
  "/run/secrets/'"${RESTIC_REPOSITORY_SECRET}"'" \
  "/run/secrets/'"${RESTIC_PASSWORD_SECRET}"'"
do
  if $SUDO test -f "$path"; then
    echo "ok  $path"
  else
    echo "missing  $path" >&2
    exit 1
  fi
done

if [ -n "'"${RESTIC_ENVIRONMENT_SECRET}"'" ]; then
  path="/run/secrets/'"${RESTIC_ENVIRONMENT_SECRET}"'"
  if $SUDO test -f "$path"; then
    echo "ok  $path"
  else
    echo "missing  $path" >&2
    exit 1
  fi
fi

echo
echo "repository access:"
if [ -z "'"${RESTIC_ENVIRONMENT_SECRET}"'" ]; then
  $SUDO -u restic-backup restic snapshots \
    --repository-file "/run/secrets/'"${RESTIC_REPOSITORY_SECRET}"'" \
    --password-file "/run/secrets/'"${RESTIC_PASSWORD_SECRET}"'" \
    --compact
else
  $SUDO -u restic-backup restic snapshots \
    --repository-file "/run/secrets/'"${RESTIC_REPOSITORY_SECRET}"'" \
    --password-file "/run/secrets/'"${RESTIC_PASSWORD_SECRET}"'" \
    --environment-file "/run/secrets/'"${RESTIC_ENVIRONMENT_SECRET}"'" \
    --compact
fi
'
