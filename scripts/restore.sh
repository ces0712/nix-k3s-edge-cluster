#!/bin/sh
set -eu

. "$(dirname "$0")/lib.sh"

NODE_NAME="${NODE_NAME:-cloud-edge-1}"
TARGET_HOST="${TARGET_HOST:-${TAILNET_HOST:-}}"
TARGET_HOST="${TARGET_HOST:?TARGET_HOST or TAILNET_HOST is required}"
DEPLOY_USER="${DEPLOY_USER:-nixos}"
IDENTITY_FILE="${IDENTITY_FILE:-}"
RESTIC_REPOSITORY_SECRET="${RESTIC_REPOSITORY_SECRET:-restic/borgbase_repo}"
RESTIC_PASSWORD_SECRET="${RESTIC_PASSWORD_SECRET:-restic/borgbase_password}"
RESTIC_ENVIRONMENT_SECRET="${RESTIC_ENVIRONMENT_SECRET:-}"
RESTORE_DRY_RUN="${RESTORE_DRY_RUN:-0}"
RUSTDESK_DATA_DIR="${RUSTDESK_DATA_DIR:-/srv/edge-cluster/rustdesk}"
K3S_TOKEN_PATH="${K3S_TOKEN_PATH:-/var/lib/rancher/k3s/server/token}"
RESTIC_CACHE_DIR="${RESTIC_CACHE_DIR:-/srv/restic-backup}"

ssh_ctx="$(ssh_target "${DEPLOY_USER}" "${TARGET_HOST}" "${IDENTITY_FILE}")"
SSH_OPTS="${ssh_ctx%%|*}"
TARGET="${ssh_ctx#*|}"

echo "Waiting for SSH on ${TARGET} ..."
remote_wait_for_ssh "${SSH_OPTS}" "${TARGET}"

if [ "${RESTORE_DRY_RUN}" = "1" ]; then
  echo "Checking restore readiness on ${TARGET} ..."
  remote_run "${SSH_OPTS}" "${TARGET}" "
    set -eu

    if [ \"\$(id -u)\" -ne 0 ]; then
      SUDO=sudo
    else
      SUDO=
    fi

    \$SUDO test -f /run/secrets/${RESTIC_REPOSITORY_SECRET}
    \$SUDO test -f /run/secrets/${RESTIC_PASSWORD_SECRET}
    \$SUDO install -d -m 750 -o restic-backup -g restic-backup ${RESTIC_CACHE_DIR}

    if [ -n \"${RESTIC_ENVIRONMENT_SECRET}\" ]; then
      \$SUDO test -f /run/secrets/${RESTIC_ENVIRONMENT_SECRET}
      ENV_ARGS=\"--environment-file /run/secrets/${RESTIC_ENVIRONMENT_SECRET}\"
    else
      ENV_ARGS=
    fi

    \$SUDO -u restic-backup env XDG_CACHE_HOME=${RESTIC_CACHE_DIR} \
      sh -c '
        restic snapshots \
          --host ${NODE_NAME} \
          --repository-file /run/secrets/${RESTIC_REPOSITORY_SECRET} \
          --password-file /run/secrets/${RESTIC_PASSWORD_SECRET} \
          '"\${ENV_ARGS}"' \
          --compact
      '

    \$SUDO ls -ld ${RESTIC_CACHE_DIR}
    if \$SUDO test -d ${RUSTDESK_DATA_DIR}; then
      \$SUDO ls -ld ${RUSTDESK_DATA_DIR}
    else
      echo '${RUSTDESK_DATA_DIR} does not exist yet; this is expected before first workload restore.'
    fi

    if \$SUDO test -f ${K3S_TOKEN_PATH}; then
      \$SUDO ls -l ${K3S_TOKEN_PATH}
    else
      echo '${K3S_TOKEN_PATH} does not exist yet; this is expected before first K3s bootstrap.'
    fi
  "
  echo "Restore readiness check complete."
  exit 0
fi

echo "This will restore RustDesk state and the K3s server token from Restic on ${TARGET}."
echo "Existing data under ${RUSTDESK_DATA_DIR} and ${K3S_TOKEN_PATH} may be overwritten."
echo "The restore is filtered to snapshots for host '${NODE_NAME}'."
echo "Press ENTER to continue or Ctrl+C to abort."
read -r

echo "Stopping K3s before restore ..."
remote_run "${SSH_OPTS}" "${TARGET}" "
  set -eu
  sudo systemctl stop k3s || true
"

echo "Restoring workload state from Restic ..."
remote_run "${SSH_OPTS}" "${TARGET}" "
  set -eu

  if [ \"\$(id -u)\" -ne 0 ]; then
    SUDO=sudo
  else
    SUDO=
  fi

  \$SUDO install -d -m 750 -o restic-backup -g restic-backup ${RESTIC_CACHE_DIR}
  \$SUDO install -d -m 750 \$(dirname ${K3S_TOKEN_PATH})

  if [ -e ${RUSTDESK_DATA_DIR} ]; then
    \$SUDO mv ${RUSTDESK_DATA_DIR} ${RUSTDESK_DATA_DIR}.bak.\$(date +%s)
  fi
  if [ -f ${K3S_TOKEN_PATH} ]; then
    \$SUDO cp ${K3S_TOKEN_PATH} ${K3S_TOKEN_PATH}.bak.\$(date +%s)
  fi

  if [ -n \"${RESTIC_ENVIRONMENT_SECRET}\" ]; then
    ENV_ARGS=\"--environment-file /run/secrets/${RESTIC_ENVIRONMENT_SECRET}\"
  else
    ENV_ARGS=
  fi

  \$SUDO -u restic-backup env XDG_CACHE_HOME=${RESTIC_CACHE_DIR} \
    sh -c '
      restic restore latest \
        --host ${NODE_NAME} \
        --repository-file /run/secrets/${RESTIC_REPOSITORY_SECRET} \
        --password-file /run/secrets/${RESTIC_PASSWORD_SECRET} \
        '"\${ENV_ARGS}"' \
        --include ${RUSTDESK_DATA_DIR} \
        --include ${K3S_TOKEN_PATH} \
        --target / \
        --verbose
    '

  \$SUDO chown -R root:root ${RUSTDESK_DATA_DIR}
  \$SUDO chmod 750 ${RUSTDESK_DATA_DIR}
  \$SUDO chmod 600 ${K3S_TOKEN_PATH}
"

echo "Starting K3s after restore ..."
remote_run "${SSH_OPTS}" "${TARGET}" "
  set -eu
  sudo systemctl start k3s
  sudo systemctl is-active k3s
"

echo "Restore complete."
