#!/usr/bin/with-contenv bashio
# ==============================================================================
# Home Assistant Add-on: TimescaleDb
# Initializes the container during startup
# ==============================================================================
declare postgres_data
declare version_file
declare new_install

postgres_data=/data/postgres
version_file=/data/version
new_install=false;

# Applies permission to the data directory
applyPermissions () {
	chown -R postgres:postgres ${postgres_data}
	chmod 700 ${postgres_data}
}

# Initializes the data directory
initializeDataDirectory () {
	# Init data-directory
    bashio::log.info "Initializing new postgres directory.."
	mkdir -p ${postgres_data}
	applyPermissions
	su - postgres -c "initdb -D ${postgres_data}"
	# Set timescaledb as being enabled in the postgres config file.
	sed -r -i "s/[#]*\s*(shared_preload_libraries)\s*=\s*'(.*)'/\1 = 'timescaledb,\2'/;s/,'/'/" ${postgres_data}/postgresql.conf
	# Set Password protect IPv4 hosts by default
	echo "host    all             all             0.0.0.0/0               md5" >> ${postgres_data}/pg_hba.conf
	echo "local    all             all                                    md5" >> ${postgres_data}/pg_hba.conf
	echo "local    all             all                                   peer" >> ${postgres_data}/pg_hba.conf
	# Set Listen on all addresses (*)
	sed -r -i "s/[#]listen_addresses.=.'.*'/listen_addresses\ \=\ \'\*\'/g" ${postgres_data}/postgresql.conf
	# Set telemetry level
	echo "timescaledb.telemetry_level=$(bashio::config 'timescaledb.telemetry')" >> ${postgres_data}/postgresql.conf
	bashio::log.info "done"
}

# Upgrades the timescale extensions on all databases.
upgradeTimeScaleExtension () {
	# Upgrade Timescale..
	bashio::log.info "Upgrading Timescale extentions.."
	bashio::log.info "Updating Timescale Extension for database system databases.."

	# Fetch all databases..
	psql \
		-X \
		-U "postgres" \
		-c "select datname from pg_database where datallowconn = true;" \
		--set ON_ERROR_STOP=on \
		--no-align \
		-t \
		--field-separator ' ' \
		--quiet \
	| while read datname; do
		psql -X -U postgres -d ${datname} -c "select 1 from pg_extension where extname = 'timescaledb';" | grep -q 1 \
		&& (bashio::log.info "Try updating Timescale Extension for database: '${datname}'.."; 
		(psql -X -U postgres -d ${datname} -c "ALTER EXTENSION timescaledb UPDATE;" || true))
	done

	bashio::log.info "done"
}

# Upgrades the PostgreSQL databases from 12 to 14
upgradePostgreSQL12to14 () {
	bashio::log.notice "Upgrading databases now. This could take a while. Please be patient..."

	# Move the old data directory out of our way..
	mv ${postgres_data} ${postgres_data}12

	# And upgrade PostgreSQL
	bashio::log.notice "Upgrading PostgreSql..."

	# Backup old HBA.conf and create a temp one...
	mv ${postgres_data}12/pg_hba.conf ${postgres_data}12/pg_hba_backup.conf
	echo "local    all             all                                     trust" > ${postgres_data}12/pg_hba.conf

	#Start postgres on the old data-dir
	bashio::log.info "Starting PostgreSQL-12 first.."
	su - postgres -c "/usr/libexec/postgresql12/postgres -D ${postgres_data}12" &
	postgres_pid=$!

	# Wait for postgres to become available..
	while ! psql -X -U "postgres" postgres -c "" 2> /dev/null; do
		sleep 1
	done

	# Upgrade Timescale first, otherwise, pg_upgrade will fail.
	upgradeTimeScaleExtension

	# Stop server
	kill ${postgres_pid}
	wait ${postgres_pid} || true

	# Restore HBA.CONF
	rm ${postgres_data}12/pg_hba.conf
	mv ${postgres_data}12/pg_hba_backup.conf ${postgres_data}12/pg_hba.conf

	# Create a fresh data-directory
	initializeDataDirectory

	# And upgrade!
	bashio::log.notice "Upgrading databases.."
	cd ${postgres_data}12
	if su -c "pg_upgrade --old-bindir=/usr/libexec/postgresql12 --new-bindir=/usr/libexec/postgresql14 --old-datadir=${postgres_data}12 --new-datadir=${postgres_data} --link --username=postgres" -s /bin/sh postgres; then
		bashio::log.notice "PostgreSQL upgraded succesfully!"
		return 0
	else
		# Rollback..
		rm -r ${postgres_data}
		mv ${postgres_data}12 ${postgres_data}

		bashio::log.error "PostgreSQL could not upgrade! Please inspect any errors in the lines above!"
		return 1
	fi
}

if ! bashio::fs.directory_exists "${postgres_data}"; then
    bashio::log.info "Detected a fresh installation! Welcome! We're setting things up for you.."
    new_install=true
else
    touch ${version_file}
	# Always re-apply permissions, because they seem to be reset after a snapshot restore
	applyPermissions
fi

# Initialize for new installs
if bashio::var.true "${new_install}"; then
	touch /data/firstrun
	bashio::addon.version > ${version_file}
	initializeDataDirectory
else

	# # Check if an aborted upgrade is present.. (not working.. some users already upgraded..)
	# if bashio::fs.directory_exists "${postgres_data}12"; then
	# 	bashio::log.notice "An aborted upgrade from 12 to 14 was detected. Retrying..."
	# 	mv ${postgres_data} ${postgres_data}_backup_2_0_1 || true
	# 	mv ${postgres_data}12 ${postgres_data} || true
	# fi

	# Check if we need to upgrade from 12 to 14.
	if [[ $(< ${postgres_data}/PG_VERSION) == "12" ]]; then
		bashio::log.notice "A database upgrade is required from Postgres 12."
		if upgradePostgreSQL12to14; then
			# Restart addon.
			sleep 3
			bashio::addon.restart
		else
			bashio::log.error "Upgrade was not succesfull."
			exit 1
		fi
	fi
fi

bashio::log.info "done"

# Apply TimescaleDb mem/cpu tuning settings
bashio::log.info "Tuning resources.."

# Always patch telemetry level
sed -r -i "s/timescaledb.telemetry_level.=.'.*'/timescaledb.telemetry_level=$(bashio::config 'timescaledb.telemetry')/g" ${postgres_data}/postgresql.conf

chmod 707 "/usr/share/timescaledb/002_timescaledb_tune.sh"
TS_TUNE_MEMORY=$(bashio::config 'timescaledb.maxmemory') \
	TS_TUNE_NUM_CPUS=$(bashio::config 'timescaledb.maxcpus') \
	POSTGRESQL_CONF_DIR=${postgres_data} \
	/usr/share/timescaledb/002_timescaledb_tune.sh
bashio::log.info "done"

# Appy max connections 
bashio::log.info "Applying max connections.."
sed -i -e "/max_connections =/ s/= .*/= $(bashio::config 'max_connections')/" ${postgres_data}/postgresql.conf
bashio::log.info "done"
