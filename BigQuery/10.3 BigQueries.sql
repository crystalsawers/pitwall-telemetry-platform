-- BigQuery SQL Queries for Data Exploration and Analysis

-- NOTE: Replace `project-id` with your actual Google Cloud project ID in the queries below.
-- Also change the dataset name if you are using one not named `experimental_dataset`.

-- Select all tables

SELECT table_name
FROM `project-id.experimental_dataset.INFORMATION_SCHEMA.TABLES`;


-- 1. TEST_USERS — basic exploration + aggregation

SELECT *
FROM `project-id.experimental_dataset.test_users`
LIMIT 50;

SELECT country, COUNT(*) AS total_users
FROM `project-id.experimental_dataset.test_users`
GROUP BY country
ORDER BY total_users DESC;


-- 2. EVENT_TRACKING — behaviour + value analysis

SELECT *
FROM `project-id.experimental_dataset.event_tracking`
LIMIT 50;

SELECT event_type, COUNT(*) AS total_events
FROM `project-id.experimental_dataset.event_tracking`
GROUP BY event_type
ORDER BY total_events DESC;

SELECT event_type, AVG(value) AS avg_value
FROM `project-id.experimental_dataset.event_tracking`
WHERE value IS NOT NULL
GROUP BY event_type
ORDER BY avg_value DESC;


-- 3. SYSTEM_EVENTS — operational analysis

SELECT *
FROM `project-id.experimental_dataset.system_events`
LIMIT 50;

SELECT event_type, COUNT(*) AS total_events
FROM `project-id.experimental_dataset.system_events`
GROUP BY event_type
ORDER BY total_events DESC;

SELECT service, AVG(response_time_ms) AS avg_response_time
FROM `project-id.experimental_dataset.system_events`
GROUP BY service
ORDER BY avg_response_time DESC;

SELECT region, severity, COUNT(*) AS total
FROM `project-id.experimental_dataset.system_events`
GROUP BY region, severity
ORDER BY total DESC;

SELECT *
FROM `project-id.experimental_dataset.system_events`
WHERE response_time_ms > 300
ORDER BY response_time_ms DESC
LIMIT 10;