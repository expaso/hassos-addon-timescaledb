#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Home Assistant Add-on: TimescaleDb
# Post-backup script - removes the database dump once Home Assistant has it
# ==============================================================================
# shellcheck source=/dev/null
source /usr/share/timescaledb/backup_common.sh

bashio::log.info "Starting post-backup cleanup..."

if [[ -d "${BACKUP_DIR}" ]] || [[ -f "${LEGACY_BACKUP_FILE}" ]] || [[ -f "${LEGACY_GZ_BACKUP_FILE}" ]]; then
    if rm -rf "${BACKUP_DIR}" "${LEGACY_BACKUP_FILE}" "${LEGACY_GZ_BACKUP_FILE}"; then
        bashio::log.info "Database dump removed successfully."
    else
        bashio::log.error "Failed to remove the database dump in ${BACKUP_DIR}"
        exit 1
    fi
else
    bashio::log.debug "No database dump to clean up."
fi

bashio::log.info "Post-backup cleanup completed."
