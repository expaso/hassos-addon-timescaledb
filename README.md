# HomeAssistant Add-On: [TimescaleDB](https://www.timescale.com/)
## [PostgreSql](https://www.postgresql.org/) & [Postgis](https://postgis.net/) & [TimescaleDB](https://www.timescale.com/)

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
"databases": [{ homeassistant"} ],
"logins": [{ "username": "homeassistant", "password": null, "timescaledb": true }],
"rights": [
	{
	"username": "homeassistant",
	"database": "homeassistant"
	}
],
"timescaledb": 
	{ 
	"telemetry": "basic",
	"maxmemory": "512MB",
	"maxcpus": "4"
	}
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
for further tuning. Your Postgres.config file it located in the addon's data directory.

## Usage

You are now ready to start using Postgres with TimescaleDb extenstions enabled!

Please do not forget to also map the TCP/IP port in the network-section of the addon to the desired port number.
The default is port `5432`

Seeking a nice web-ased client? **Try the pgAdmin4 addon.**
