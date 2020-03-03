
/* SETUP: SQLite data preparation
CREATE TABLE aircraft_origin (AircraftID integer not null, ModeS varchar(6) not null unique, ModeSCountry varchar(24), Registration varchar(20), Status varchar(10), Manufacturer varchar(60), ICAOTypeCode varchar(10), Type varchar(40));

INSERT INTO aircraft_origin(AircraftID,ModeS,ModeSCountry,Registration,Status,Manufacturer,ICAOTypeCode,Type) SELECT AircraftID,ModeS,ModeSCountry,Registration,Status,Manufacturer,ICAOTypeCode,Type FROM Aircraft;
*/

/* STEP 1: Create source connector to load Aircraft table from SQLite */
CREATE SOURCE CONNECTOR `jdbc_connector` WITH(
  "connector.class"='io.confluent.connect.jdbc.JdbcSourceConnector',
  "connection.url"='jdbc:sqlite:/sqlite3/basestation.sqb',
  "mode"='bulk',
  "tasks.max"='1',
  "poll.interval.ms"='5000',
  "table.whitelist"='aircraft_origin',
  "topic.prefix"='jdbc_',
  "key"='ModeS');

/* STEP 2: Create Avro formatted table on top of raw SQLite data */
CREATE TABLE aircraft_origin_table WITH(value_format='AVRO', kafka_topic='jdbc_aircraft_origin', key='ModeS');

/* EXTRA: Validate loaded table
SET 'auto.offset.reset'='earliest';
SELECT * FROM AIRCRAFT_ORIGIN_TABLE EMIT CHANGES LIMIT 10;
*/

/* STEP 3: Create delimited stream on top of raw SBS topic */
CREATE STREAM sbs1090_stream (
  message_type VARCHAR, 
  transmission_type INT, 
  session_id INT, 
  aircraft_id INT, 
  hex_ident VARCHAR, 
  flight_id VARCHAR, 
  message_generated_date VARCHAR, 
  message_generated_time VARCHAR, 
  message_logged_date VARCHAR, 
  message_logged_time VARCHAR, 
  callsign VARCHAR, 
  altitude BIGINT, 
  ground_speed BIGINT, 
  track INT, 
  latitude DOUBLE, 
  longitude DOUBLE, 
  vertical_rate BIGINT, 
  squawk VARCHAR, 
  alert VARCHAR, 
  emergency VARCHAR, 
  spi_ident VARCHAR, 
  is_on_ground BOOLEAN)
  WITH (VALUE_FORMAT = 'DELIMITED', KAFKA_TOPIC = 'sbs1090_raw');

/* STEP 4: Create and parition key Avro formatted SBS stream */
CREATE STREAM sbs1090_stream_avro 
  WITH (KAFKA_TOPIC='sbs1090_avro',VALUE_FORMAT='AVRO') 
  AS SELECT * FROM SBS1090_STREAM
  PARTITION BY hex_ident;

/* EXTRA: Validate Avro stream
SELECT * FROM SBS1090_STREAM_AVRO EMIT CHANGES;
*/

/* STEP 5: Create origin enriched stream by joining the table and stream */
CREATE STREAM aircraft_log AS
  SELECT sbs.hex_ident,
         sbs.flight_id,
         sbs.callsign,
         sbs.altitude,
         sbs.ground_speed,
         sbs.latitude,
         sbs.longitude,
         GEO_DISTANCE(sbs.latitude, sbs.longitude, 47.4502, -122.3088, 'miles') AS distance
  FROM SBS1090_STREAM_AVRO sbs
  EMIT CHANGES;

/* EXTRA: Validate enriched  stream
SELECT * FROM AIRCRAFT_LOG EMIT CHANGES;
*/

/* STEP 6: Create an aggregate table of observed airplanes */
CREATE TABLE aircraft_observed AS
SELECT hex_ident AS id, 
  MIN(altitude) AS altitude_min, MAX(altitude) AS altitude_max,
  MIN(ground_speed) AS ground_speed_min, MAX(ground_speed) AS ground_speed_max,
  ROUND(MIN(distance),2) AS distance_min, ROUND(MAX(distance),2) AS distance_max
  FROM AIRCRAFT_LOG a
  GROUP BY a.hex_ident
  EMIT CHANGES;

/* STEP 7: Push Query that allows us to continually see updates */
SELECT *
  FROM AIRCRAFT_OBSERVED
  EMIT CHANGES;

/* EXTRA: Push Query with JOIN to see Country, Manufacturer, and Type
SELECT 
  ao.id,
  ao.distance_min,
  ao.distance_max,
  aot.modescountry,
  aot.manufacturer,
  aot.type
FROM AIRCRAFT_OBSERVED ao
JOIN AIRCRAFT_ORIGIN_TABLE aot ON ao.id = aot.modes
EMIT CHANGES;
*/

/* STEP 8: Pull Query that allows us to see the most recent update */
SELECT *
  FROM AIRCRAFT_OBSERVED
  WHERE ROWKEY = 'A57390';
