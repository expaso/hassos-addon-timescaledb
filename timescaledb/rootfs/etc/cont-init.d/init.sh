#!/usr/bin/with-contenv bashio
# ==============================================================================
# Home Assistant Add-on: TimescaleDb
# Initializes the container during
# ==============================================================================

declare postgres_data
declare version_file
declare new_install

postgres_data=/data/postgres
version_file=/data/version
new_install=false;

# Init data directory
if ! bashio::fs.directory_exists "${postgres_data}"; then
    bashio::log.info "Creating a new PostgreSQL initial system.."
	# Create postgress directory in data directory
    new_install=true
	mkdir -p ${postgres_data}
	bashio::addon.version > ${version_file}
else
    touch ${version_file}
fi

# Always re-apply permissions, because they seem to be reset after a snapshot restore
chown -R postgres:postgres ${postgres_data}
chmod 700 ${postgres_data}

# Initialize for new installs
if bashio::var.true "${new_install}"; then
    bashio::log.info "Initializing postgres directory.."
	touch /data/firstrun

	# Init data-directory
	su - postgres -c "initdb -D ${postgres_data}"
	# Set timescaledb as being enabled in the postgres config file.
	sed -r -i "s/[#]*\s*(shared_preload_libraries)\s*=\s*'(.*)'/\1 = 'timescaledb,\2'/;s/,'/'/" ${postgres_data}/postgresql.conf
	# Password protect IPv4 hosts by default
	echo "host    all             all             0.0.0.0/0               md5" >> ${postgres_data}/pg_hba.conf
	echo "local    all             all                                    md5" >> ${postgres_data}/pg_hba.conf
	echo "local    all             all                                   peer" >> ${postgres_data}/pg_hba.conf
	# Listen on all addresses (*)
	sed -r -i "s/[#]listen_addresses.=.'.*'/listen_addresses\ \=\ \'\*\'/g" ${postgres_data}/postgresql.conf
	# Set telemetry level
	echo "timescaledb.telemetry_level=$(bashio::config 'timescaledb.telemetry')" >> ${postgres_data}/postgresql.conf
else
	# Set telemetry level
	sed -r -i "s/timescaledb.telemetry_level.=.'.*'/timescaledb.telemetry_level=$(bashio::config 'timescaledb.telemetry')/g" ${postgres_data}/postgresql.conf
fi
bashio::log.info "done"

# Apply TimescaleDb mem/cpu tuning settings
bashio::log.info "Tuning resources.."
chmod 707 "/usr/share/timescaledb/002_timescaledb_tune.sh"
TS_TUNE_MEMORY=$(bashio::config 'timescaledb.maxmemory') \
	TS_TUNE_NUM_CPUS=$(bashio::config 'timescaledb.maxcpus') \
	POSTGRESQL_CONF_DIR=${postgres_data} \
	/usr/share/timescaledb/002_timescaledb_tune.sh
bashio::log.info "done"
