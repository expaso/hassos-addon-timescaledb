# Home Assistant Add-on: [PostgreSQL](https://www.postgresql.org/) [TimescaleDB](https://www.timescale.com/)
## [PostgreSql 15.3](https://www.postgresql.org/) & [Postgis 3.3.3](https://postgis.net/) & [TimescaleDB 2.11.1](https://www.timescale.com/) & [TimescaleDB Toolit 1.13.1](https://github.com/timescale/timescaledb-toolkit) & [pgAgent 4.2.2](https://www.pgadmin.org/docs/pgadmin4/development/pgagent.html)
## PostgreSQL Overview

From: https://www.postgresql.org/about/

PostgreSQL is a powerful, open source object-relational database system that uses and extends the SQL language combined with many features that safely store and scale the most complicated data workloads. The origins of PostgreSQL date back to 1986 as part of the POSTGRES project at the University of California at Berkeley and has more than 30 years of active development on the core platform.

PostgreSQL has earned a strong reputation for its proven architecture, reliability, data integrity, robust feature set, extensibility, and the dedication of the open source community behind the software to consistently deliver performant and innovative solutions.

## TimescaleDB Overview

From: https://docs.timescale.com/latest/introduction

TimescaleDB is an open-source time-series database optimized for fast ingest and complex queries. It speaks "full SQL" and is correspondingly easy to use like a traditional relational database, yet scales in ways previously reserved for NoSQL databases.

Compared to the trade-offs demanded by these two alternatives (relational vs. NoSQL), TimescaleDB offers the best of both worlds for time-series data:

### Easy to Use
Full SQL interface for all SQL natively supported by PostgreSQL (including secondary indexes, non-time based aggregates, sub-queries, JOINs, window functions).

- Connects to any client or tool that speaks PostgreSQL, no changes needed.
- Time-oriented features, API functions, and optimizations.
- Robust support for Data retention policies.

## Introduction

Say, you want put all those nice Home Assistant measurements from your smarthome to good use, and for example, use something like [Grafana](https://grafana.com) for your dashboards, and maybe [Prometheus](https://prometheus.io/) for monitoring..

__That means you need a decent time-series database.__

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

To install this Hass.io add-on you need to add the Expase add-on repository
first:

You can do this by navigating to the "Add-on Store" tab in the Supervisor panel and then entering https://github.com/Expaso/hassos-addons in the "Add new repository by URL" field.

Now scroll down and select the "TimeScaleDb" add-on.
Press install to download the add-on and unpack it on your machine. This can take some time.

Start the add-on, check the logs of the add-on to see if everything went well.

## Configuation

Example add-on configuration:

```
 {
    "databases": ["homeassistant"],
    "timescale_enabled": ["homeassistant"],
    "timescaledb": { 
      "telemetry": "basic",
      "maxmemory": "512MB",
      "maxcpus": "4"
      },
      "max_connections": 20,
      "system_packages": [],
      "init_commands": []
 }
```

### Option: `databases`

Sets a list of database-names that will be created for you, once you start the add-on.
You can also create databases on your own ofcourse, using a psql client of your choice.

### Option: `timescale_enabled`

Sets a list of database-names where the timescale-extentions will be enabled for.
Databases not in this list will act like normal Postgre databases.

### Option: `timescaledb.telemetry`

Switches the telemetry of TimescaleDb on or off.
Valid options are: 'basic' or 'off'.
See: https://docs.timescale.com/latest/using-timescaledb/telemetry

### Option: `timescaledb.maxmemory`

Sets the maximum amount of memory that PostgreSQL will claim.
It's important to leave breathing room for other processes on your machine (or raspberry pi), so set these level not too high (say max 50% of your total ram).

Example: `maxmemory="1024MB"`
Or leave empty for accepting auto-tune.

### Option: `timescaledb.maxcpu`

Sets the maximum number of cores that PostgreSQL will use.
It's important to leave breathing room for other processes on your machine (or raspberry pi), so set these level not too high (say max 75% of your total number of cores).

Example: `maxcpu="2"`
Or leave empty for accepting auto-tune.

See also:
https://docs.timescale.com/latest/getting-started/configuring
for further tuning. Your Postgres.config file is located in the addon's data directory.

### Option: `max_connections`

Sets the maximum number of connections that PostgreSql will accept.
Setting this higher could lead to more memory usage.

Example: `max_connections=30`


### Option: `system_packages`

Advanced users only!
A list of extra alpine packages to iunstall during addon-startup.

Example: ['nano']


### Option: `init_commands`

Advanced users only!
A list of extra commands to run during startup. 

To alter something in the postgresql.conf file for example:

Example: ['sed -i -e "/max_connections =/ s/= .*/= 50/" /data/postgres/postgresql.conf']

### Option: `retry_upgrade`

Advanced users only!
When set, the upgrade from Postgres 14 to 15 could be retryed if it failed mid-flight. 
Basically this will try to find the old database-files from Postgres 12, and restore them before trying to upgrade to Postgres 14 again.

!! Please don't set this if you don't know what you are doing or before taking a backup. !!

## Usage

You are now ready to start using Postgres with TimescaleDb extenstions enabled!

Seeking a nice web-based client? **Try the pgAdmin4 addon.**

Please do not forget to also map the TCP/IP port in the network-section of the addon to the desired port number.
The default is port `5432`

__Securiy Notice!__

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


