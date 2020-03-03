# ADS-B dump190 and ksqlDB
[diagram](./ksqlDB_1090.png)

## Prerequistes
* [Docker desktop](https://www.docker.com/products/docker-desktop)
* [kafkacat](https://github.com/edenhill/kafkacat) utility
* [netcat](https://brewinstall.org/install-netcat-on-mac-with-brew/) utility
* [RTL-SDR dongle or similar with simple antenna](https://www.rtl-sdr.com/buy-rtl-sdr-dvb-t-dongles/)
* [dump1090 cli tool](https://github.com/MalcolmRobb/dump1090) built and installed on local machine
* [BaseStation database](https://data.flightairmap.com/data/basestation/BaseStation.sqb.gz)

## Files
* `basestation.sqb` SQLite database file of known aircraft
* `demo_notes.sql` ksql commented query list to build application
* `docker-compose.yml` environment build for kafka and ksqlDB
* `sbs_offline.csv` sample data to use if RTL-SDR is not available
* `slowcat` bash script to replay sample data slowly
* `start1090` runs first; starts dump1090 and it's output
* `startFakeProducer` use instead of `startProducer` and `start1090` not needed
* `startKsqlDB` runs second; the main startup of kafka and the ksqlDB
* `startProducer` runs third; produces data from the local basestation port

## Notes
Tested only on macOS 10.15.3
