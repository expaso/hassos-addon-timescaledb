#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Home Assistant Add-on: TimescaleDb
# Shared settings of the backup and restore scripts
# ==============================================================================

# Since 6.1.0: the roles in globals.sql, and one compressed pg_dump per database
# shellcheck disable=SC2034
BACKUP_DIR="/data/backup"
# Up to 6.0.x: one plain pg_dumpall; still restored when a backup contains it
# shellcheck disable=SC2034
LEGACY_BACKUP_FILE="/data/backup_db.sql"
# The same, gzip compressed (forks of this add-on)
# shellcheck disable=SC2034
LEGACY_GZ_BACKUP_FILE="/data/backup_db.sql.gz"

# Free space (MiB) the dump always leaves on /data, so PostgreSQL never runs out of disk.
# BACKUP_MIN_FREE_MB in the environment overrides it (used for testing).
# shellcheck disable=SC2034
BACKUP_MIN_FREE_MB="${BACKUP_MIN_FREE_MB:-1024}"

# Free space on the /data file system in MiB
backupFreeSpaceMb() {
    df -Pm /data | awk 'NR==2 {print $4}'
}

# Moves every column sequence (serial and identity) of a database up to at least the
# highest value in its column. Sequences that are already ahead are left alone.
# A sequence behind its table makes every insert fail with a duplicate key (issue #85).
# $1: database
fixSequences() {
    local database="${1}"
    psql -X -q -U postgres -d "${database}" -v ON_ERROR_STOP=1 <<'SQL'
DO $$
DECLARE
  r record;
  max_value bigint;
  fixed integer := 0;
BEGIN
  FOR r IN
    SELECT s.oid::regclass AS seq, t.oid::regclass AS tbl, a.attname AS col
    FROM pg_class s
    JOIN pg_depend d ON d.classid = 'pg_class'::regclass AND d.objid = s.oid
                    AND d.refclassid = 'pg_class'::regclass AND d.deptype IN ('a', 'i')
    JOIN pg_class t ON t.oid = d.refobjid
    JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = d.refobjsubid
    WHERE s.relkind = 'S'
  LOOP
    EXECUTE format('SELECT max(%I) FROM %s', r.col, r.tbl) INTO max_value;
    IF max_value IS NOT NULL THEN
      EXECUTE format('SELECT setval(%L, greatest(%s, (SELECT last_value FROM %s)))', r.seq, max_value, r.seq);
      fixed := fixed + 1;
    END IF;
  END LOOP;
  RAISE NOTICE 'Checked % sequence(s)', fixed;
END $$;
SQL
}
