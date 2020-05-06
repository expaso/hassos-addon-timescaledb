# HassOS Addon: [TimescaleDB](https://www.timescale.com/)
## [PostgreSql](https://www.postgresql.org/) + [Postgis](https://postgis.net/) + [TimescaleDB](https://www.timescale.com/)

Say, you wanted to record all those nice Home Assistant measurements from your house into a decent store, so you can run all kinds of queries on it
like [Grafana](https://grafana.com) for your dashboards, and maybe [Prometheus](https://prometheus.io/) for monitoring..

__That means you need a decent datastore.__

Well, you could use [InfluxDB](www.influxdata.com) for this.
This works pretty good.. but.. being a NoSQL database, this means you have to learn Flux (it's query language) to do anything usefull with it.

For the Home Assistant recorder you probaly need some SQL storage, so that means you also need MariaDb or the default SqlLite implementation.

BUT.. Before you do install all these.. Please read this blogpost:

https://blog.timescale.com/blog/why-sql-beating-nosql-what-this-means-for-future-of-data-time-series-database-348b777b847a/

_You can stop right here._

Use the power of your already existing SQL skills for PostgreSQL, combined with time-series functionality of TimeScaleDb.

And as a bonus, I also added a Geospatial extention: Postgis.




