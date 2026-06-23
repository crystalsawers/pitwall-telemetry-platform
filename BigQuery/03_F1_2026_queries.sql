-- FORMULA 1 2026 DATABASE QUERIES (BigQuery)


-- Show all Constructors
SELECT * FROM `project-id.f1_2026.constructors`;

-- Show all Drivers
SELECT
    d.driver_id,
    d.driver_name,
    d.driver_number,
    d.nationality,
    c.constructor_name AS team
FROM `project-id.f1_2026.drivers` d
LEFT JOIN `project-id.f1_2026.constructors` c
    ON d.constructor_id = c.constructor_id;

-- Show all Races 
SELECT
    race_id,
    race_name,
    circuit,
    location,
    FORMAT_TIMESTAMP('%e %M %Y', race_date) AS race_date
FROM `project-id.f1_2026.races`;

-- Show Race Podium Results from ALL races
SELECT
    r.race_name,
    d.driver_name,
    rr.position,
    rr.points,
    rr.fastest_lap
FROM `project-id.f1_2026.race_results` rr
JOIN `project-id.f1_2026.races` r ON rr.race_id = r.race_id
JOIN `project-id.f1_2026.drivers` d ON rr.driver_id = d.driver_id
ORDER BY rr.race_id, rr.position;

-- Show Winners per race
SELECT
    r.race_name,
    d.driver_name AS winner
FROM `project-id.f1_2026.race_results` rr
JOIN `project-id.f1_2026.races` r ON rr.race_id = r.race_id
JOIN `project-id.f1_2026.drivers` d ON rr.driver_id = d.driver_id
WHERE rr.position = 1;

-- Show Fastest Lap per race

SELECT
    r.race_name,
    d.driver_name AS fastest_lap
FROM `project-id.f1_2026.race_results` rr
JOIN `project-id.f1_2026.races` r ON rr.race_id = r.race_id
JOIN `project-id.f1_2026.drivers` d ON rr.driver_id = d.driver_id
WHERE rr.fastest_lap = TRUE;

-- Show Driver Standings

SELECT
    ds.position,
    d.driver_name,
    ds.points
FROM `project-id.f1_2026.driver_standings` ds
JOIN `project-id.f1_2026.drivers` d ON ds.driver_id = d.driver_id
WHERE ds.race_id = 3
ORDER BY ds.position;

-- Show Constructor Standings
SELECT
    cs.position,
    c.constructor_name,
    cs.points
FROM `project-id.f1_2026.constructor_standings` cs
JOIN `project-id.f1_2026.constructors` c ON cs.constructor_id = c.constructor_id
WHERE cs.race_id = 3
ORDER BY cs.position;