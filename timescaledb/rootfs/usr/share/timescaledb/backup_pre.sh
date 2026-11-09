#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Home Assistant Add-on: TimescaleDb
# Pre-backup script - dumps all databases before the Home Assistant backup runs.
# The data directory itself is excluded from the backup (backup_exclude), so these
# dumps are what a restore brings back.
#
# Per database a compressed pg_dump (custom format), plus the roles in globals.sql.
# A watchdog stops the dump when the free space on /data drops below
# BACKUP_MIN_FREE_MB, and a failed dump is always removed, so the backup can never
# fill the disk and take PostgreSQL down.
# ==============================================================================
# shellcheck source=/dev/null
source /usr/share/timescaledb/backup_common.sh

declare DUMP_PID=""

removeDump() {
    rm -rf "${BACKUP_DIR}" "${LEGACY_BACKUP_FILE}" "${LEGACY_GZ_BACKUP_FILE}"
}

fail() {
    bashio::log.error "${1}"
    if [[ -n "${DUMP_PID}" ]]; then
        kill "${DUMP_PID}" 2>/dev/null || true
        wait "${DUMP_PID}" 2>/dev/null || true
    fi
    removeDump
    bashio::log.error "The database dump was removed again; this backup does not contain the database."
    exit 1
}

# Runs a dump command in the background and stops it when the disk gets too full
# $@: command
runGuarded() {
    "$@" &
    DUMP_PID=$!
    while kill -0 "${DUMP_PID}" 2>/dev/null; do
        if [[ $(backupFreeSpaceMb) -lt ${BACKUP_MIN_FREE_MB} ]]; then
            fail "Not enough free disk space: stopped the dump to keep at least ${BACKUP_MIN_FREE_MB} MiB free for PostgreSQL."
        fi
        sleep 1
    done
    if ! wait "${DUMP_PID}"; then
        DUMP_PID=""
        return 1
    fi
    DUMP_PID=""
}

bashio::log.info "Starting pre-backup process..."

if ! pg_isready -U postgres -h localhost -p 5432 >/dev/null 2>&1; then
    bashio::log.warning "PostgreSQL is not running. Skipping database dump."
    bashio::log.warning "Note: Only file-level backup will be performed."
    exit 0
fi

# Leftovers of an interrupted backup
removeDump

if [[ $(backupFreeSpaceMb) -lt ${BACKUP_MIN_FREE_MB} ]]; then
    fail "Only $(backupFreeSpaceMb) MiB free on /data, the dump needs to leave at least ${BACKUP_MIN_FREE_MB} MiB free. Free up disk space and try again."
fi

mkdir -p "${BACKUP_DIR}"
chmod 700 "${BACKUP_DIR}"

bashio::log.info "Dumping roles..."
if ! runGuarded pg_dumpall -U postgres --globals-only -f "${BACKUP_DIR}/globals.sql"; then
    fail "Failed to dump the roles!"
fi

{
    echo "# TimescaleDB add-on backup"
    echo "# $(psql -X -tA -U postgres -d postgres -c 'select version()')"
} > "${BACKUP_DIR}/databases.txt"

INDEX=0
while IFS= read -r database; do
    INDEX=$(( INDEX + 1 ))
    DUMP_FILE="database-${INDEX}.dump"
    bashio::log.info "Dumping database '${database}'..."
    if ! runGuarded pg_dump -U postgres -d "${database}" -Fc --compress=zstd:3 -f "${BACKUP_DIR}/${DUMP_FILE}"; then
        fail "Failed to dump database '${database}'!"
    fi
    # Tab separated: dump file, then the database name as is
    printf '%s\t%s\n' "${DUMP_FILE}" "${database}" >> "${BACKUP_DIR}/databases.txt"
done < <(psql -X -tA -U postgres -d postgres -c "select datname from pg_database where datallowconn and not datistemplate order by datname")

chmod 600 "${BACKUP_DIR}"/*
bashio::log.info "Database dump created in ${BACKUP_DIR}: ${INDEX} database(s), $(du -sh "${BACKUP_DIR}" | cut -f1)"
bashio::log.info "Pre-backup process completed."
