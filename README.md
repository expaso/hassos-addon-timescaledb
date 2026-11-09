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
Change it immediately after activating the add-on with the `postgres_password` option, or in SQL:

```
ALTER USER postgres WITH PASSWORD 'strongpassword';
```

A default `pg_hba.conf` is created in the data directory with the following content, which allows local peer users and network users with passwords.:

```
# TYPE  DATABASE        USER            ADDRESS                 METHOD
host    all             all             0.0.0.0/0               scram-sha-256
host    all             all             ::/0                    scram-sha-256
local   all             all                                     scram-sha-256
local   all             all                                     peer
```

New installations use `scram-sha-256` (PostgreSQL 18 deprecates MD5 passwords). Installations upgraded from an older version, and databases restored from a backup, keep `md5`: their roles may still have MD5 password hashes, and `md5` accepts both MD5 and SCRAM hashes.

Please review this configuration carefully by examine the docs:
https://www.postgresql.org/docs/devel/auth-pg-hba-conf.html

## Configuration

#### Option: `postgres_password`

The password of the `postgres` superuser. When set, the add-on applies it on every start, so you can change it here at any time. When not set, a new installation gets the default password `homeassistant`, with a warning in the log, and an existing installation keeps its current password.

Remember to update the password everywhere you connect with the `postgres` user, like the `db_url` of the recorder or LTSS.

## Advanced Configuration

### PostgreSQL Configuration

#### Option: `postgresql_settings`

Allows you to customize PostgreSQL server parameters, as a list of `name=value` entries. The add-on writes them to `/data/postgres/postgresql.user.conf`, which is included at the end of `postgresql.conf`, so they override the settings the addon configures itself (including TimescaleDB tuning).

**Example:**

```yaml
postgresql_settings:
  - "log_statement=all"
  - "log_min_duration_statement=1000"
  - "work_mem=16MB"
  - "maintenance_work_mem=256MB"
  - "effective_cache_size=4GB"
  - "random_page_cost=1.1"
  - "checkpoint_completion_target=0.9"
```

The value is written to the configuration as given. Quote values that contain spaces with single quotes, for example `"log_line_prefix='%m [%p] '"`. Settings of extensions work too, for example `"timescaledb.max_background_workers=16"`.

See the [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config.html) for all available parameters and their meanings.

**Important Notes:**

- Configuration changes require a restart of the addon to take effect
- The file is rewritten on every start: removing an entry also removes the setting
- Some critical parameters cannot be modified (e.g., `shared_preload_libraries`, `port`, `data_directory`) as they are managed by the addon; they are skipped with a warning in the log
- Before PostgreSQL starts, the addon lets PostgreSQL check the settings. If it rejects one, all settings are ignored for that start and the error is shown in the log, so a typo cannot keep the database from starting
- This option replaces `postgresql_config` from version 5.x, which never worked: Home Assistant drops option keys that are not listed by name

**Common Use Cases:**

**Performance Tuning:**

```yaml
postgresql_settings:
  - "work_mem=32MB"
  - "maintenance_work_mem=512MB"
  - "effective_cache_size=8GB"
```

**Query Logging for Debugging:**

```yaml
postgresql_settings:
  - "log_statement=all"
  - "log_duration=on"
  - "log_min_duration_statement=500"
```

**Connection Settings:**

```yaml
postgresql_settings:
  - "idle_in_transaction_session_timeout=60000"
  - "statement_timeout=30000"
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
postgresql_settings:
  - "log_statement=all"
  - "work_mem=32MB"
```

The new approach is simpler, safer, and easier to maintain. The `init_commands` option remains available for advanced use cases that aren't covered by the declarative configuration.

## Immich (VectorChord)

The add-on includes [VectorChord](https://github.com/tensorchord/VectorChord) (`vchord`) and pgvector, the extensions [Immich](https://immich.app/) needs. VectorChord has to be loaded at startup, so it is behind the `vectorchord` option (off by default):

```yaml
vectorchord: true
```

To use the database for [Immich](https://immich.app/), turn the option on, restart the add-on, and prepare a database once (for example in pgAdmin, or `psql` in the add-on console):

```sql
CREATE DATABASE immich;
\c immich
CREATE EXTENSION vchord CASCADE;
CREATE EXTENSION earthdistance CASCADE;
```

Then point Immich at it with `DB_URL=postgresql://postgres:<password>@<home assistant host>:5432/immich` (map the port in the Network section). `vchord CASCADE` also installs pgvector, which VectorChord builds on.

Turning the option off again stops loading VectorChord after the next restart; databases that use it (like Immich's) then fail on their vector indexes until you turn it back on.

## Backup and Restore

This addon implements a robust backup and restore mechanism designed to protect your database from data loss.

### How Backups Work

When Home Assistant's backup system runs, it automatically:

1. **Pre-Backup**: Dumps every database with `pg_dump` in its compressed custom format, and the roles with `pg_dumpall --globals-only`, into `/data/backup`
2. **Backup**: Backs up the dump along with other addon data (but excludes the PostgreSQL data directory)
3. **Post-Backup**: Removes the dump again to save space

This approach has several advantages:

- **Consistency**: Each database dump is a transaction-consistent snapshot
- **Safety**: No risk of backing up corrupted or in-transition database files
- **Small Size**: The dump is compressed (zstd), and the large PostgreSQL data directory is excluded from the backup

**Disk space:** the dump always leaves at least 1 GiB free on the data partition. When there is less space, or the free space drops below that while dumping, the dump is stopped and removed again, and an error is logged: PostgreSQL never runs out of disk because of a backup. The Home Assistant backup then does not contain the database, so free up disk space and back up again.

### How Restore Works

When you restore a Home Assistant backup:

1. The addon starts up with the restored dump in `/data/backup`
2. If the PostgreSQL data directory is missing or corrupted, the addon:
   - Initializes a fresh PostgreSQL database
   - Restores the roles, then every database the way TimescaleDB prescribes (`timescaledb_pre_restore()`, `pg_restore`, `timescaledb_post_restore()`)
   - Moves every sequence up to at least the highest id in its table, so inserts cannot fail with a duplicate key afterwards
   - Removes the dump after successful restoration

Backups of older addon versions contain a plain SQL dump (`/data/backup_db.sql`, or `backup_db.sql.gz`). These are still restored, with the same TimescaleDB restore steps added.

This automatic recovery process ensures your data is safely restored even if:

- The database files were corrupted
- You're restoring to a different system
- A PostgreSQL upgrade failed

### Manual Backup

You can also create manual backups using the PostgreSQL command-line tools:

**Create a backup of one database:**

```bash
docker exec addon_timescaledb_timescaledb su - postgres -c "pg_dump -U postgres -d homeassistant -Fc -f /data/manual_homeassistant_$(date +%Y%m%d).dump"
```

**Restore it into an empty database:**

```bash
docker exec addon_timescaledb_timescaledb su - postgres -c "psql -U postgres -d homeassistant -c 'SELECT timescaledb_pre_restore();'"
docker exec addon_timescaledb_timescaledb su - postgres -c "pg_restore -U postgres -d homeassistant /data/manual_homeassistant_YYYYMMDD.dump"
docker exec addon_timescaledb_timescaledb su - postgres -c "psql -U postgres -d homeassistant -c 'SELECT timescaledb_post_restore();'"
```

Do not use `pg_restore -j` (parallel): it does not restore the TimescaleDB catalog correctly.

### Important Notes

- The dump is only present during the backup process and is automatically cleaned up
- The PostgreSQL data directory (`/data/postgres/*`) is excluded from backups to reduce backup size and improve reliability
- Restore is automatic - no manual intervention required when restoring from a Home Assistant backup

### Troubleshooting

**If restore fails:**

1. Check the addon logs and `/var/log/timescaledb.restore.log` in the addon for detailed error messages
2. The dump is preserved in `/data/backup` (or `/data/backup_db.sql` for older backups) for manual recovery

**If backup fails:**

- Check that PostgreSQL is running during the backup
- Ensure there's sufficient disk space: the compressed dump plus 1 GiB
- Review the addon logs for specific error messages

### Now what..

Well.. Dive in!

You can read additional documentation on how you van work with your data and Grafana here:

https://github.com/expaso/hassos-addons/issues/1
