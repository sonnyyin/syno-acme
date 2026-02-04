#!/bin/bash

# path of this script
BASE_ROOT="$(cd "$(dirname "$0")" && pwd)"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}
# date time
DATE_TIME="$(date +%Y%m%d%H%M%S)"
# base crt path
CRT_BASE_PATH="/usr/syno/etc/certificate"
PKG_CRT_BASE_PATH="/usr/local/etc/certificate"

ACME_BIN_PATH="${BASE_ROOT}/acme.sh" # acme.sh home dir (contains acme.sh, acme.sh.env, etc.)
TEMP_PATH="${BASE_ROOT}/temp"

CRT_PATH_NAME="$(cat "${CRT_BASE_PATH}/_archive/DEFAULT")"
CRT_PATH="${CRT_BASE_PATH}/_archive/${CRT_PATH_NAME}"

backupCrt() {
  log '[INFO] Backing up current certificates...'
  BACKUP_PATH="${BASE_ROOT}/backup/${DATE_TIME}"
  mkdir -p "${BACKUP_PATH}"
  cp -r "${CRT_BASE_PATH}" "${BACKUP_PATH}"
  cp -r "${PKG_CRT_BASE_PATH}" "${BACKUP_PATH}/package_cert"
  echo "${BACKUP_PATH}" >"${BASE_ROOT}/backup/latest"
  log '[INFO] Backup completed.'
  return 0
}

installAcme() {
  log '[INFO] Checking acme.sh installation...'

  if [ -z "${TEMP_PATH}" ] || [ -z "${ACME_BIN_PATH}" ]; then
    log "[ERROR] Required path variables are not set (TEMP_PATH or ACME_BIN_PATH)."
    return 1
  fi

  if [ -x "${ACME_BIN_PATH}/acme.sh" ]; then
    log "[INFO] acme.sh already installed at ${ACME_BIN_PATH}, skipping."
    log '[INFO] acme.sh is ready.'
    return 0
  fi

  mkdir -p "${TEMP_PATH}" "${ACME_BIN_PATH}" || {
    log "[ERROR] Failed to create directories."
    return 1
  }
  rm -rf "${TEMP_PATH:?}/acme-src" 2>/dev/null || true
  mkdir -p "${TEMP_PATH}/acme-src"
  cd "${TEMP_PATH}/acme-src" || {
    log "[ERROR] Failed to enter temp directory."
    return 1
  }

  LOCAL_ARCHIVE=""
  for f in "${TEMP_PATH}"/acme.sh*.zip "${TEMP_PATH}"/acme.sh*.gz; do
    if [ -f "$f" ]; then
      LOCAL_ARCHIVE="$f"
      break
    fi
  done

  if [ -n "${LOCAL_ARCHIVE}" ]; then
    log "[INFO] Using local archive (skipping download): ${LOCAL_ARCHIVE}"
    SRC_TAR_NAME="$(basename "${LOCAL_ARCHIVE}")"
    cp "${LOCAL_ARCHIVE}" "${TEMP_PATH}/acme-src/${SRC_TAR_NAME}" || {
      log "[ERROR] Failed to copy local archive: ${LOCAL_ARCHIVE}"
      return 1
    }
    case "${SRC_TAR_NAME}" in
    *.zip) unzip -q "${SRC_TAR_NAME}" || {
      log "[ERROR] Failed to extract zip archive."
      return 1
    } ;;
    *.gz) tar -xzf "${SRC_TAR_NAME}" || {
      log "[ERROR] Failed to extract archive."
      return 1
    } ;;
    *)
      log "[ERROR] Unsupported archive type (use .zip or .gz)."
      return 1
      ;;
    esac
  else
    log '[INFO] Downloading acme.sh from GitHub...'

    SRC_TAR_NAME="master.tar.gz"
    SRC_URL="https://github.com/acmesh-official/acme.sh/archive/master.tar.gz"

    curl -fL --retry 3 --retry-delay 2 --connect-timeout 20 \
      -o "${SRC_TAR_NAME}" "${SRC_URL}" || {
      log "[ERROR] Download failed: ${SRC_URL}"
      return 1
    }

    tar -xzf "${SRC_TAR_NAME}" || {
      log "[ERROR] Failed to extract downloaded archive."
      return 1
    }
  fi

  SRC_DIR="$(ls -1d acme.sh-* 2>/dev/null | head -n 1)"
  if [ -z "${SRC_DIR}" ] || [ ! -d "${SRC_DIR}" ]; then
    log "[ERROR] Source directory not found after extraction."
    return 1
  fi

  log '[INFO] Installing acme.sh (this may take a moment)...'
  cd "${SRC_DIR}" || {
    log "[ERROR] Failed to enter source directory: ${SRC_DIR}"
    return 1
  }

  if [ ! -x "./acme.sh" ]; then
    log "[ERROR] acme.sh executable not found in source directory."
    return 1
  fi

  ./acme.sh --install --nocron --home "${ACME_BIN_PATH}" || {
    log "[ERROR] acme.sh installation failed."
    return 1
  }

  if [ ! -x "${ACME_BIN_PATH}/acme.sh" ]; then
    log "[ERROR] acme.sh not found after installation: ${ACME_BIN_PATH}/acme.sh"
    return 1
  fi

  log '[INFO] acme.sh is ready.'
  rm -rf "${TEMP_PATH:?}/acme-src" 2>/dev/null || true
  [ -n "${LOCAL_ARCHIVE}" ] && [ -f "${LOCAL_ARCHIVE}" ] && rm -f "${LOCAL_ARCHIVE}" && log '[INFO] Removed local archive after install.'
  return 0
}

generateCrt() {
  log '[INFO] Requesting/renewing certificate...'
  cd "${BASE_ROOT}"
  source config

  log '[INFO] Updating default certificate with acme.sh...'

  if [ -f "${ACME_BIN_PATH}/acme.sh.env" ]; then
    source "${ACME_BIN_PATH}/acme.sh.env"
  fi

  "${ACME_BIN_PATH}/acme.sh" --set-default-ca --server letsencrypt >/dev/null 2>&1 || true

  ISSUE_LOG="$("${ACME_BIN_PATH}/acme.sh" --server letsencrypt --log --issue \
    --dns "${DNS}" --dnssleep "${DNS_SLEEP}" \
    -d "${DOMAIN}" -d "*.${DOMAIN}" 2>&1)"
  ISSUE_RC=$?
  echo "${ISSUE_LOG}"

  if [ ${ISSUE_RC} -ne 0 ]; then
    if echo "${ISSUE_LOG}" | grep -qE 'Skip, Next renewal time|Domains not changed'; then
      log "[INFO] Certificate not due for renewal; using existing cert for install."
    else
      log '[ERROR] Certificate issue/renewal failed.'
      log '[INFO] Reverting to backup...'
      revertCrt
      exit 1
    fi
  fi

  "${ACME_BIN_PATH}/acme.sh" --server letsencrypt --install-cert \
    -d "${DOMAIN}" -d "*.${DOMAIN}" \
    --cert-file "${CRT_PATH}/cert.pem" \
    --key-file "${CRT_PATH}/privkey.pem" \
    --fullchain-file "${CRT_PATH}/fullchain.pem" || {
    log '[ERROR] Failed to install certificate files to DSM archive path.'
    log '[INFO] Reverting to backup...'
    revertCrt
    exit 1
  }

  if [ -s "${CRT_PATH}/cert.pem" ] && [ -s "${CRT_PATH}/privkey.pem" ] && [ -s "${CRT_PATH}/fullchain.pem" ]; then
    log '[INFO] Certificate is ready.'
    return 0
  else
    log '[ERROR] Certificate files missing or invalid.'
    log '[INFO] Reverting to backup...'
    revertCrt
    exit 1
  fi
}

updateService() {
  log '[INFO] Updating services with new certificate...'
  log '[INFO] Copying certificate to service paths...'
  CP_LOG="$(python3 "${BASE_ROOT}/crt_cp.py" "${CRT_PATH_NAME}" 2>&1)"
  CP_RC=$?
  while IFS= read -r line; do log "$line"; done <<<"${CP_LOG}"
  if [ ${CP_RC} -ne 0 ]; then
    log "[WARN] Certificate copy script failed; check INFO format or permissions."
  fi
  log '[INFO] Services updated.'
}

reloadWebService() {
  log '[INFO] Reloading web services...'
  log '[INFO] Applying new certificate...'

  if command -v synow3tool >/dev/null 2>&1; then
    SW_LOG="$(synow3tool --gen-all 2>&1)" || true
    [ -n "${SW_LOG}" ] && while IFS= read -r line; do log "$line"; done <<<"${SW_LOG}"
  fi

  if command -v systemctl >/dev/null 2>&1; then
    NGX_LOG="$(systemctl reload nginx 2>&1)" || NGX_LOG="$(systemctl restart nginx 2>&1)"
    [ -n "${NGX_LOG}" ] && while IFS= read -r line; do log "$line"; done <<<"${NGX_LOG}"
  fi

  if command -v systemctl >/dev/null 2>&1; then
    for srv in pkg-apache24 apache24 httpd; do
      if systemctl list-unit-files "${srv}.service" 2>/dev/null | grep -qE '\.service'; then
        AP_LOG="$(systemctl restart "$srv" 2>&1)" || true
        [ -n "${AP_LOG}" ] && while IFS= read -r line; do log "$line"; done <<<"${AP_LOG}"
      fi
    done
  fi

  log '[INFO] Web services reloaded.'
}

revertCrt() {
  log '[INFO] Restoring certificates from backup...'
  BACKUP_PATH="${BASE_ROOT}/backup/$1"
  if [ -z "$1" ]; then
    BACKUP_PATH="$(cat "${BASE_ROOT}/backup/latest")"
  fi
  if [ ! -d "${BACKUP_PATH}" ]; then
    log "[ERROR] Backup path not found: ${BACKUP_PATH}"
    return 1
  fi

  log "[INFO] Restoring: ${BACKUP_PATH}/certificate -> ${CRT_BASE_PATH}"
  cp -rf "${BACKUP_PATH}/certificate/"* "${CRT_BASE_PATH}"

  log "[INFO] Restoring: ${BACKUP_PATH}/package_cert -> ${PKG_CRT_BASE_PATH}"
  cp -rf "${BACKUP_PATH}/package_cert/"* "${PKG_CRT_BASE_PATH}"

  reloadWebService
  log '[INFO] Restore completed.'
}

updateCrt() {
  log '[INFO] ------ Certificate update started ------'
  backupCrt
  installAcme
  generateCrt
  updateService
  reloadWebService
  log '[INFO] ------ Certificate update completed ------'
}

case "$1" in
update)
  log '[INFO] Starting certificate update...'
  updateCrt
  ;;

revert)
  log '[INFO] Restoring from backup...'
  revertCrt "$2"
  ;;

*)
  log "[INFO] Usage: $0 {update|revert}"
  exit 1
  ;;
esac
