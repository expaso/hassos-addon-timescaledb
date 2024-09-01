# Home Assistant Add-on: [PostgreSQL](https://www.postgresql.org/) [TimescaleDB](https://www.timescale.com/)

## [PostgreSql](https://www.postgresql.org/) & [Postgis](https://postgis.net/) & [TimescaleDB](https://www.timescale.com/) & [TimescaleDB Toolkit](https://github.com/timescale/timescaledb-toolkit) & [pgAgent](https://www.pgadmin.org/docs/pgadmin4/development/pgagent.html)

<a href="https://www.buymeacoffee.com/expaso" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" height="41" width="174"></a>

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

To install this Hass.io add-on you need to add the Expase add-on repository
first:

You can do this by navigating to the "Add-on Store" tab in the Supervisor panel and then entering https://github.com/expaso/hassos-addons in the "Add new repository by URL" field.

Now scroll down and select the "TimeScaleDb" add-on.
Press install to download the add-on and unpack it on your machine. This can take some time.

Start the add-on, check the logs of the add-on to see if everything went well.

### Running the container standalone.

In this case, you need to have a working Docker installation on your machine.
pull one of the images for the desired architecture from docker hub:

```
docker pull husselhans/hassos-addon-timescaledb-amd64:latest
docker pull husselhans/hassos-addon-timescaledb-aarch64:latest
docker pull husselhans/hassos-addon-timescaledb-armv7:latest
docker pull husselhans/hassos-addon-timescaledb-armhf:latest
docker pull husselhans/hassos-addon-timescaledb-i386:latest
```

You can replace latest with the version number you want to use.

Simply start it like this:

```
docker run \
  --rm \
  --name timescaledb \
  --v ${PWD}/timescaledb_addon_data:/data \
  -p 5432:5432 \
  husselhans/hassos-addon-timescaledb-amd64:dev
```

This will use ~/timescaledb_addon_data as the data directory for the container, and map the port 5432 to the host.

If you want to start the container as a daemon, simply remove the `--rm` option and add the `-d` option like so:

```
docker run \
  -d \
  --name timescaledb \
  --v ${PWD}/timescaledb_addon_data:/data \
  -p 5432:5432 \
  husselhans/hassos-addon-timescaledb-amd64:dev
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

### Now what..

Well.. Dive in!

You can read additional documentation on how you van work with your data and Grafana here:

https://github.com/expaso/hassos-addons/issues/1
