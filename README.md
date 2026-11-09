# Home Assistant Add-on: [PostgreSQL](https://www.postgresql.org/) [TimescaleDB](https://www.timescale.com/)

## [PostgreSql](https://www.postgresql.org/) & [Postgis](https://postgis.net/) & [TimescaleDB](https://www.timescale.com/) & [TimescaleDB Toolkit](https://github.com/timescale/timescaledb-toolkit) & [pgAgent](https://www.pgadmin.org/docs/pgadmin4/development/pgagent.html) & [pgVector](https://github.com/pgvector/pgvector)

<a href="https://www.buymeacoffee.com/expaso" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" height="41" width="174"></a>

## PostgreSQL Overview

From: https://www.postgresql.org/about/

PostgreSQL is a powerful, open source object-relational database system that uses and extends the SQL language combined with many features that safely store and scale the most complicated data workloads. The origins of PostgreSQL date back to 1986 as part of the POSTGRES project at the University of California at Berkeley and has more than 30 years of active development on the core platform.

PostgreSQL has earned a strong reputation for its proven architecture, reliability, data integrity, robust feature set, extensibility, and the dedication of the open source community behind the software to consistently deliver performant and innovative solutions.

## TimescaleDB Overview

From: https://www.tigerdata.com/docs/about/latest

TimescaleDB is an open-source time-series database optimized for fast ingest and complex queries. It speaks "full SQL" and is correspondingly easy to use like a traditional relational database, yet scales in ways previously reserved for NoSQL databases.

Compared to the trade-offs demanded by these two alternatives (relational vs. NoSQL), TimescaleDB offers the best of both worlds for time-series data:

### Easy to Use

Full SQL interface for all SQL natively supported by PostgreSQL (including secondary indexes, non-time based aggregates, sub-queries, JOINs, window functions).

- Connects to any client or tool that speaks PostgreSQL, no changes needed.
- Time-oriented features, API functions, and optimizations.
- Robust support for Data retention policies.

## Introduction

Say, you want put all those nice Home Assistant measurements from your smarthome to good use, and for example, use something like [Grafana](https://grafana.com) for your dashboards, and maybe [Prometheus](https://prometheus.io/) for monitoring..

**That means you need a decent time-series database.**

You could use [InfluxDB](www.influxdata.com) for this.
This works pretty good.. but.. being a NoSQL database, this means you have to learn Flux (it's query language). Once you get there, you will quickly discover that updating existing data in Influx is near impossible (without overwriting it). That's a bummer, since my data needed some 'tweaking'.

For the Home Assistant recorder, you probaly need some SQL storage too. That means you also need to
bring stuff like MariaDb or Postgres to the table (unless you keep using the SqlLite database).

So.. why not combine these?
Seriously?! You ask...

Yeah! Pleae read this blogpost to get a sense of why:

https://blog.timescale.com/blog/why-sql-beating-nosql-what-this-means-for-future-of-data-time-series-database-348b777b847a/

And so.. Use the power of your already existing SQL skills for PostgreSQL, combined with powerfull time-series functionality of TimeScaleDb and be done with it!

As a bonus, I also added a Geospatial extention: [Postgis](https://postgis.net/).
You can now happily query around your data like a PRO 😎.

## Installation

There are two ways to install this add-on: via the Home Assistant add-on store or, by running the container manually on a separate (more powerfull?) machine.
This could come in handy if you want to use a more powerfull machine for your database, or if you want to use a different OS than Home Assistant OS.

### Home Assistant add-on store

[![Open your Home Assistant instance and show the add add-on repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fexpaso%2Fhassos-addons)

Or in the Home-Assistant add-on store, a possibility to add a repository is provided.
Use the following URL to add this repository:

```txt
https://github.com/expaso/hassos-addons
```

Now scroll down and select the "TimeScaleDb" add-on.
Press install to download the add-on and unpack it on your machine. This can take some time.

Start the add-on, check the logs of the add-on to see if everything went well.

### Running the container standalone.

In this case, you need to have a working Docker installation on your machine.
pull one of the images for the desired architecture from docker hub:

```
docker pull ghcr.io/expaso/timescaledb/amd64:stable
docker pull ghcr.io/expaso/timescaledb/aarch64:stable
```

You can replace latest with the version number you want to use.

Simply start it like this:

```
docker run \
  --rm \
  --name timescaledb \
  --v ${PWD}/timescaledb_addon_data:/data \
  -p 5432:5432 \
  ghcr.io/expaso/timescaledb/amd64:dev
```

This will use ~/timescaledb_addon_data as the data directory for the container, and map the port 5432 to the host.

If you want to start the container as a daemon, simply remove the `--rm` option and add the `-d` option like so:

```
docker run \
  -d \
  --name timescaledb \
  --v ${PWD}/timescaledb_addon_data:/data \
  -p 5432:5432 \
  ghcr.io/expaso/timescaledb/amd64:dev
```

## Usage

You are now ready to start using Postgres with TimescaleDb extenstions enabled!

Seeking a nice web-based client? **Try the pgAdmin4 addon.**

Please do not forget to also map the TCP/IP port in the network-section of the addon to the desired port number.
The default is port `5432`

**Securiy Notice!**

The default username is `postgres` with password `homeassistant`.
Make sure you change this immediately after activating the add-on:

```
ALTER USER user_name WITH PASSWORD 'strongpassword';
```

A default `pg_hba.conf` is created in the data directory with the following content, which allows local peer users and network users with passwords.:

```
# TYPE  DATABASE        USER            ADDRESS                 METHOD
host    all             all             0.0.0.0/0               md5"
local   all             all             0.0.0.0/0               md5"
local   all             all             0.0.0.0/0               peer"
```

Please review this configuration carefully by examine the docs:
https://www.postgresql.org/docs/devel/auth-pg-hba-conf.html

## Advanced Configuration

### PostgreSQL Configuration

#### Option: `postgresql_config`

Allows you to customize PostgreSQL server parameters. These settings are applied to `postgresql.conf` and can override default settings configured by the addon.

**Example:**

```yaml
postgresql_config:
  log_statement: "all"
  log_min_duration_statement: "1000" # Log queries taking > 1 second
  work_mem: "16MB"
  maintenance_work_mem: "256MB"
  effective_cache_size: "4GB"
  random_page_cost: "1.1"
  checkpoint_completion_target: "0.9"
```

See the [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config.html) for all available parameters and their meanings.

**Important Notes:**

- Configuration changes require a restart of the addon to take effect
- Some critical parameters cannot be modified (e.g., `shared_preload_libraries`, `port`, `data_directory`) as they are managed by the addon
- Invalid parameter names or values will be logged and skipped
- Parameters are applied after TimescaleDB tuning, so you can override tuned values if needed

**Common Use Cases:**

**Performance Tuning:**

```yaml
postgresql_config:
  work_mem: "32MB"
  maintenance_work_mem: "512MB"
  effective_cache_size: "8GB"
```

**Query Logging for Debugging:**

```yaml
postgresql_config:
  log_statement: "all"
  log_duration: "on"
  log_min_duration_statement: "500"
```

**Connection Settings:**

```yaml
postgresql_config:
  idle_in_transaction_session_timeout: "60000"
  statement_timeout: "30000"
```

#### Option: `pg_hba_config`

Allows you to add custom authentication rules to `pg_hba.conf`. These rules control which hosts can connect to the database and how they authenticate.

**Example:**

```yaml
pg_hba_config:
  # Allow specific subnet with password authentication
  - type: "host"
    database: "homeassistant"
    user: "all"
    address: "192.168.1.0/24"
    method: "md5"

  # Require SSL for remote admin connections
  - type: "hostssl"
    database: "all"
    user: "admin"
    address: "0.0.0.0/0"
    method: "scram-sha-256"

  # Reject specific user from connecting
  - type: "host"
    database: "all"
    user: "guest"
    address: "0.0.0.0/0"
    method: "reject"

  # Allow local connections without password for specific user
  - type: "local"
    database: "all"
    user: "backup"
    method: "trust"
```

**Rule Format:**

- `type`: Connection type - `local` (Unix socket), `host` (TCP/IP), `hostssl` (TCP/IP with SSL), `hostnossl` (TCP/IP without SSL)
- `database`: Database name or `all` for all databases
- `user`: Username or `all` for all users
- `address`: CIDR address (required for non-local types, e.g., `192.168.1.0/24` or `0.0.0.0/0`)
- `method`: Authentication method - `md5`, `scram-sha-256`, `trust`, `reject`, `peer`, `ident`, etc.
- `options`: Optional authentication options (e.g., `clientcert=verify-full`)

See the [PostgreSQL documentation](https://www.postgresql.org/docs/current/auth-pg-hba-conf.html) for complete details on authentication methods.

**Important Notes:**

- Custom rules are **appended** to the default rules (not replaced)
- Default rules remain in place to ensure basic connectivity
- Rules are evaluated in order - the first matching rule is used
- Invalid rules will be logged and skipped
- Changes require a restart of the addon to take effect

**⚠️ Warning:** Incorrect `pg_hba.conf` configuration can lock you out of the database. Always ensure you have at least one working authentication rule before adding restrictions.

**Common Use Cases:**

**Restrict access to specific network:**

```yaml
pg_hba_config:
  - type: "host"
    database: "all"
    user: "all"
    address: "192.168.1.0/24"
    method: "md5"
  - type: "host"
    database: "all"
    user: "all"
    address: "0.0.0.0/0"
    method: "reject"
```

**Require SSL for all external connections:**

```yaml
pg_hba_config:
  - type: "hostssl"
    database: "all"
    user: "all"
    address: "0.0.0.0/0"
    method: "scram-sha-256"
  - type: "hostnossl"
    database: "all"
    user: "all"
    address: "0.0.0.0/0"
    method: "reject"
```

**Allow passwordless local backup user:**

```yaml
pg_hba_config:
  - type: "local"
    database: "all"
    user: "backup_user"
    method: "peer"
```

### Migration from `init_commands`

If you're currently using `init_commands` to modify PostgreSQL configuration, you can migrate to the new declarative approach:

**Old way (still works):**

```yaml
init_commands:
  - 'sed -i -e "/log_statement =/ s/= .*/= '\''all'\''/" /data/postgres/postgresql.conf'
  - 'sed -i -e "/work_mem =/ s/= .*/= '\''32MB'\''/" /data/postgres/postgresql.conf'
```

**New way (recommended):**

```yaml
postgresql_config:
  log_statement: "all"
  work_mem: "32MB"
```

The new approach is simpler, safer, and easier to maintain. The `init_commands` option remains available for advanced use cases that aren't covered by the declarative configuration.

## Backup and Restore

This addon implements a robust backup and restore mechanism designed to protect your database from data loss.

### How Backups Work

When Home Assistant's backup system runs, it automatically:

1. **Pre-Backup**: Executes `pg_dumpall` to create a complete SQL dump of all databases (`backup_db.sql`)
2. **Backup**: Backs up the SQL dump file along with other addon data (but excludes the PostgreSQL data directory)
3. **Post-Backup**: Removes the temporary SQL dump file to save space

This approach has several advantages:

- **Consistency**: SQL dumps are transaction-consistent snapshots
- **Safety**: No risk of backing up corrupted or in-transition database files
- **Portability**: SQL dumps can be restored across different PostgreSQL versions
- **Small Size**: Excludes the large PostgreSQL data directory from backup

### How Restore Works

When you restore a Home Assistant backup:

1. The addon starts up with the restored `backup_db.sql` file
2. If the PostgreSQL data directory is missing or corrupted, the addon:
   - Initializes a fresh PostgreSQL database
   - Automatically restores all data from the SQL dump
   - Removes the SQL dump after successful restoration

This automatic recovery process ensures your data is safely restored even if:

- The database files were corrupted
- You're restoring to a different system
- A PostgreSQL upgrade failed

### Manual Backup

You can also create manual backups using the PostgreSQL command-line tools:

**Create a backup:**

```bash
docker exec addon_timescaledb_timescaledb su - postgres -c "pg_dumpall -U postgres --clean --if-exists -f /data/manual_backup_$(date +%Y%m%d).sql"
```

**Restore from a manual backup:**

```bash
docker exec addon_timescaledb_timescaledb su - postgres -c "psql -U postgres -f /data/manual_backup_YYYYMMDD.sql -d postgres"
```

### Important Notes

- The SQL dump is only present during the backup process and is automatically cleaned up
- If you need to keep a copy of the backup SQL file, copy it before the backup completes
- The PostgreSQL data directory (`/data/postgres/*`) is excluded from backups to reduce backup size and improve reliability
- Restore is automatic - no manual intervention required when restoring from a Home Assistant backup

### Troubleshooting

**If restore fails:**

1. Check the addon logs for detailed error messages
2. The backup SQL file will be preserved at `/data/backup_db.sql` for manual recovery
3. You can attempt manual restoration using:

   ```bash
   docker exec -it addon_timescaledb_timescaledb su - postgres -c "psql -U postgres -f /data/backup_db.sql -d postgres"
   ```

**If backup fails:**

- Check that PostgreSQL is running during the backup
- Ensure there's sufficient disk space for the SQL dump
- Review the addon logs for specific error messages

### Now what..

Well.. Dive in!

You can read additional documentation on how you van work with your data and Grafana here:

https://github.com/expaso/hassos-addons/issues/1
