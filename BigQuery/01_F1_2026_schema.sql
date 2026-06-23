-- FORMULA 1 2026 DATABASE SCHEMA for BigQuery

-- 1. Create a new dataset (schema)
CREATE SCHEMA IF NOT EXISTS `project-id.f1_2026`;


-- CREATE TABLES
-- 2. Constructors
CREATE OR REPLACE TABLE `project-id.f1_2026.constructors` (
  constructor_id INT64,
  constructor_name STRING,
  team_principal STRING
);

-- 3. Drivers
CREATE OR REPLACE TABLE `project-id.f1_2026.drivers` (
  driver_id INT64,
  driver_name STRING,
  driver_number INT64,
  nationality STRING,
  constructor_id INT64
);

-- 4. Races
CREATE OR REPLACE TABLE `project-id.f1_2026.races` (
  race_id INT64,
  race_name STRING,
  circuit STRING,
  location STRING,
  race_date DATE
);

-- 5. Race Results
CREATE OR REPLACE TABLE `project-id.f1_2026.race_results` (
  race_id INT64,
  driver_id INT64,
  position INT64,
  points INT64,
  fastest_lap BOOL
);

-- 6. Driver standings
CREATE OR REPLACE TABLE `project-id.f1_2026.driver_standings` (
  race_id INT64,
  driver_id INT64,
  position INT64,
  points INT64
);

-- 7. Constructor standings
CREATE OR REPLACE TABLE `project-id.f1_2026.constructor_standings` (
  race_id INT64,
  constructor_id INT64,
  position INT64,
  points INT64
);

-- END OF TABLE SCHEMA