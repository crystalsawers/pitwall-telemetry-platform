-- BigQuery SQL to create a partitioned and clustered table for sensor readings

DROP TABLE IF EXISTS `project-id.experimental_dataset.sensor_readings`;

CREATE TABLE `project-id.experimental_dataset.sensor_readings`
(
  sensor_id INT64,
  sensor_type STRING,
  location STRING,
  value FLOAT64,
  status STRING,
  reading_time TIMESTAMP
)
PARTITION BY DATE(reading_time)
CLUSTER BY sensor_type, location;

-- Inserting sample data into the partitioned and clustered table

INSERT INTO `project-id.experimental_dataset.sensor_readings`
(sensor_id, sensor_type, location, value, status, reading_time)
VALUES
(1, 'temperature', 'lab-a', 21.5, 'ok', TIMESTAMP('2026-06-23 10:00:00')),
(2, 'humidity', 'lab-a', 55.2, 'ok', TIMESTAMP('2026-06-23 10:01:00')),
(3, 'temperature', 'lab-b', 22.1, 'ok', TIMESTAMP('2026-06-23 10:02:00')),
(4, 'pressure', 'lab-b', 101.3, 'warn', TIMESTAMP('2026-06-23 10:03:00'));

SELECT *
FROM `project-id.experimental_dataset.sensor_readings`
WHERE DATE(reading_time) = '2026-06-23'
ORDER BY sensor_id;