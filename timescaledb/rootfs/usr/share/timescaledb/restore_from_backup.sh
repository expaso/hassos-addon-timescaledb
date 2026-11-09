#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Home Assistant Add-on: TimescaleDb
# Restore script - Restores the databases from the dump of a Home Assistant backup
# This script is called during addon initialization when a dump is found
# and the PostgreSQL data directory is missing (i.e., after a backup restore).
# ==============================================================================
# shellcheck source=/dev/null
source /usr/share/timescaledb/backup_common.sh

declare POSTGRES_DATA
declare RESTORE_LOG

POSTGRES_DATA="/data/postgres"
RESTORE_LOG="/var/log/timescaledb.restore.log"

# Returns success when the backup contains a dump to restore
backupAvailable() {
    [[ -f "${BACKUP_DIR}/databases.txt" ]] || [[ -f "${LEGACY_BACKUP_FILE}" ]] || [[ -f "${LEGACY_GZ_BACKUP_FILE}" ]]
}

# Runs SQL from stdin as postgres in a database, with the variable :db set to $2
# $1: database to connect to
# $2: value for :db
psqlWithDb() {
    psql -X -q -tA -U postgres -d "${1}" -v ON_ERROR_STOP=1 -v db="${2}"
}

# Restores one pg_dump (custom format) the way TimescaleDB prescribes:
# create the database, create the extension, pre_restore, pg_restore, post_restore.
# $1: dump file
# $2: database
restoreDatabase() {
    local dump_file="${1}"
    local database="${2}"
    local toc
    local timescale=false

    bashio::log.info "Restoring database '${database}'..."

    if [[ "$(psqlWithDb postgres "${database}" <<< "SELECT 1 FROM pg_database WHERE datname = :'db';")" != "1" ]]; then
        psqlWithDb postgres "${database}" <<< 'CREATE DATABASE :"db";' || return 1
    fi

    # Captured first: piping pg_restore into "grep -q" could fail under pipefail
    toc="$(pg_restore -l "${dump_file}")" || return 1
    if [[ "${toc}" =~ EXTENSION\ -\ timescaledb($'\n'|\ ) ]]; then
        timescale=true
        psqlWithDb "${database}" "${database}" <<< "CREATE EXTENSION IF NOT EXISTS timescaledb; SELECT timescaledb_pre_restore();" >/dev/null || return 1
    fi

    # Errors on objects that already exist (e.g. the extension) are expected and logged,
    # they do not stop the restore. Not parallel (-j): that breaks the TimescaleDB catalog.
    if ! pg_restore -U postgres -d "${database}" "${dump_file}" >> "${RESTORE_LOG}" 2>&1; then
        bashio::log.warning "Restore of '${database}' reported errors (see ${RESTORE_LOG}):"
        { grep -E "^pg_restore: (error|warning)" "${RESTORE_LOG}" || true; } | tail -5 | while IFS= read -r line; do
            bashio::log.warning "  ${line}"
        done
    fi

    if bashio::var.true "${timescale}"; then
        psqlWithDb "${database}" "${database}" <<< "SELECT timescaledb_post_restore();" >/dev/null || return 1
    fi
}

# Restores the dumps written by backup_pre.sh since 6.1.0
restoreDumps() {
    local dump_file
    local database

    bashio::log.info "Restoring roles..."
    # Errors for roles that already exist (postgres) are expected
    psql -X -q -U postgres -d postgres -f "${BACKUP_DIR}/globals.sql" >> "${RESTORE_LOG}" 2>&1 || true

    while IFS=$'\t' read -r dump_file database; do
        if [[ -z "${dump_file}" ]] || [[ "${dump_file}" == \#* ]]; then
            continue
        fi
        if ! restoreDatabase "${BACKUP_DIR}/${dump_file}" "${database}"; then
            bashio::log.error "Failed to restore database '${database}'"
            return 1
        fi
    done < "${BACKUP_DIR}/databases.txt"
}

# Restores the plain pg_dumpall of backups made by older add-on versions (backup_db.sql),
# or gzip compressed by forks of this add-on (backup_db.sql.gz).
# Restored as is, TimescaleDB loses data ("could not find hypertable"): it needs
# timescaledb_pre_restore() before and timescaledb_post_restore() after the data of each
# database, so these are added to the SQL right after "CREATE EXTENSION ... timescaledb"
# and before the next database.
restoreLegacyDump() {
    local reader=(cat "${LEGACY_BACKUP_FILE}")
    if [[ ! -f "${LEGACY_BACKUP_FILE}" ]]; then
        reader=(gzip -dc "${LEGACY_GZ_BACKUP_FILE}")
    fi
    bashio::log.info "Restoring plain SQL dump of an older add-on version (${reader[-1]})..."
    # The dump empties search_path, so the functions are called in the schema of the extension
    "${reader[@]}" | awk '
        /^\\connect / { if (schema != "") print "SELECT " schema ".timescaledb_post_restore();"; schema = "" }
        { print }
        /^CREATE EXTENSION IF NOT EXISTS timescaledb / {
            schema = "public"
            if (match($0, /WITH SCHEMA [^ ;]+/)) schema = substr($0, RSTART + 12, RLENGTH - 12)
            print "SELECT " schema ".timescaledb_pre_restore();"
        }
        END { if (schema != "") print "SELECT " schema ".timescaledb_post_restore();" }
    ' | psql -X -U postgres -d postgres >> "${RESTORE_LOG}" 2>&1
}

restoreFromBackup() {
    local postgres_pid
    local retry_count=0
    local result=0
    local database

    bashio::log.notice "==================================================================="
    bashio::log.notice "  DATABASE RESTORE IN PROGRESS"
    bashio::log.notice "==================================================================="

    if ! backupAvailable; then
        bashio::log.error "No database dump found in ${BACKUP_DIR}, ${LEGACY_BACKUP_FILE} or ${LEGACY_GZ_BACKUP_FILE}"
        return 1
    fi

    mkdir -p /var/log
    : > "${RESTORE_LOG}"

    bashio::log.info "Starting PostgreSQL for restore process..."
    su - postgres -c "postgres -D ${POSTGRES_DATA}" &
    postgres_pid=$!

    while ! psql -X -U postgres postgres -c "" 2>/dev/null; do
        sleep 1
        retry_count=$((retry_count + 1))
        if [[ ${retry_count} -ge 30 ]]; then
            bashio::log.error "PostgreSQL failed to start within 30 seconds"
            kill "${postgres_pid}" 2>/dev/null || true
            return 1
        fi
    done

    if [[ -f "${BACKUP_DIR}/databases.txt" ]]; then
        restoreDumps || result=1
    else
        restoreLegacyDump || result=1
    fi

    if [[ ${result} -eq 0 ]]; then
        bashio::log.info "Checking sequences..."
        while IFS= read -r database; do
            fixSequences "${database}" >> "${RESTORE_LOG}" 2>&1 \
                || bashio::log.warning "Could not check the sequences of '${database}'"
        done < <(psql -X -tA -U postgres -d postgres -c "select datname from pg_database where datallowconn and not datistemplate")
    fi

    bashio::log.info "Stopping PostgreSQL..."
    kill "${postgres_pid}"
    wait "${postgres_pid}" || true

    if [[ ${result} -ne 0 ]]; then
        bashio::log.error "Failed to restore database from backup!"
        bashio::log.error "Check ${RESTORE_LOG} for details"
        bashio::log.notice "==================================================================="
        bashio::log.notice "  DATABASE RESTORE FAILED"
        bashio::log.notice "==================================================================="
        return 1
    fi

    bashio::log.info "Removing the database dump after successful restore..."
    rm -rf "${BACKUP_DIR}" "${LEGACY_BACKUP_FILE}" "${LEGACY_GZ_BACKUP_FILE}"
    bashio::log.notice "==================================================================="
    bashio::log.notice "  DATABASE RESTORE COMPLETED SUCCESSFULLY"
    bashio::log.notice "==================================================================="
    return 0
}

export -f restoreFromBackup
