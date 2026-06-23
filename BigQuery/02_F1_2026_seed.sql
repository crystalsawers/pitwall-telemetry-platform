-- FORMULA 1 2026 DATABASE DATA (BigQuery)

-- INSERT DATA TO TABLES

INSERT INTO `project-id.f1_2026.constructors` (constructor_id, constructor_name, team_principal)
VALUES
    (1, 'Oracle Red Bull Racing', 'Laurent Mekies'),
    (2, 'Mercedes-AMG Petronas F1 Team', 'Toto Wolff'),
    (3, 'Scuderia Ferrari HP', 'Fred Vasseur'),
    (4, 'McLaren Mastercard F1 Team', 'Andrea Stella'),
    (5, 'BWT Alpine F1 Team', 'Flavio Briatore'),
    (6, 'Visa CashApp Racing Bulls F1 Team', 'Alan Permane'),
    (7, 'Aston Martin Aramco F1 Team', 'Adrian Newey'),
    (8, 'Audi Revolut F1 Team', 'Mattia Binotto'),
    (9, 'Atlassian Williams F1 Team', 'James Vowles'),
    (10, 'TGR Haas F1 Team', 'Ayao Komatsu'),
    (11, 'Cadillac Formula 1 Team', 'Graeme Lowdon');

-- Example drivers (two drivers per team)
INSERT INTO `project-id.f1_2026.drivers` (driver_id, driver_name, driver_number, nationality, constructor_id)
VALUES
    -- Red Bull
    (1, 'Max Verstappen', 3, 'Dutch', 1),
    (2, 'Isack Hadjar', 6, 'French', 1),

    -- Mercedes
    (3, 'Kimi Antonelli', 12, 'Italian', 2),
    (4, 'George Russell', 63, 'British', 2),
     
    -- Ferrari
    (5, 'Charles Leclerc', 16, 'Monégasque', 3),
    (6, 'Lewis Hamilton', 44, 'British', 3),

    -- McLaren
    (7, 'Lando Norris', 1, 'British', 4),
    (8, 'Oscar Piastri', 81, 'Australian', 4),

    -- Alpine
    (9, 'Pierre Gasly', 10, 'French', 5),
    (10, 'Franco Colapinto', 43, 'Argentine', 5),

    -- Racing Bulls
    (11, 'Arvid Lindblad', 41, 'British', 6),
    (12, 'Liam Lawson', 30, 'New Zealander', 6),

    -- Aston Martin
    (13, 'Fernando Alonso', 14, 'Spanish', 7),
    (14, 'Lance Stroll', 18, 'Canadian', 7),

    -- Sauber
    (15, 'Nico Hulkenberg', 27, 'German', 8),
    (16, 'Gabriel Bortoleto', 5, 'Brazilian', 8),

    -- Williams
    (17, 'Alex Albon', 23, 'Thai', 9),
    (18, 'Carlos Sainz', 55, 'Spanish', 9),

    -- Haas
    (19, 'Esteban Ocon', 31, 'French', 10),
    (20, 'Ollie Bearman', 87, 'British', 10),

    -- Cadillac
    (21, 'Valtteri Bottas', 77, 'Finnish', 11),
    (22, 'Sergio Perez', 11, 'Mexican', 11);


-- Example races (all 2026 races)
INSERT INTO `project-id.f1_2026.races` (race_id, race_name, circuit, location, race_date)
VALUES
    (1, 'Australian Grand Prix', 'Albert Park Circuit', 'Melbourne', '2026-03-08'),
    (2, 'Chinese Grand Prix', 'Shanghai International Circuit', 'Shanghai', '2026-03-15'),
    (3, 'Japanese Grand Prix', 'Suzuka International Racing Course', 'Suzuka', '2026-03-29'),
    (4, 'Miami Grand Prix', 'Miami International Autodrome', 'Miami Gardens, Florida', '2026-05-03'),
    (5, 'Canadian Grand Prix', 'Circuit Gilles Villeneuve', 'Montreal', '2026-05-24'),
    (6, 'Monaco Grand Prix', 'Circuit de Monaco', 'Monaco', '2026-06-07'),
    (7, 'Barcelona-Catalunya Grand Prix', 'Circuit de Barcelona-Catalunya', 'Montmeló', '2026-06-14'),
    (8, 'Austrian Grand Prix', 'Red Bull Ring', 'Spielberg', '2026-06-28'),
    (9, 'British Grand Prix', 'Silverstone Circuit', 'Silverstone', '2026-07-05'),
    (10, 'Belgian Grand Prix', 'Circuit de Spa-Francorchamps', 'Stavelot', '2026-07-19'),
    (11, 'Hungarian Grand Prix', 'Hungaroring', 'Mogyoród', '2026-07-26'),
    (12, 'Dutch Grand Prix', 'Circuit Zandvoort', 'Zandvoort', '2026-08-23'),
    (13, 'Italian Grand Prix', 'Monza Circuit', 'Monza', '2026-09-06'),
    (14, 'Spanish Grand Prix', 'Madrid Circuit', 'Madrid', '2026-09-13'),
    (15, 'Azerbaijan Grand Prix', 'Baku City Circuit', 'Baku', '2026-09-26'),
    (16, 'Singapore Grand Prix', 'Marina Bay Street Circuit', 'Singapore', '2026-10-11'),
    (17, 'United States Grand Prix', 'Circuit of the Americas', 'Austin, Texas', '2026-10-25'),
    (18, 'Mexico City Grand Prix', 'Autódromo Hermanos Rodríguez', 'Mexico City', '2026-11-01'),
    (19, 'São Paulo Grand Prix', 'Interlagos Circuit', 'São Paulo', '2026-11-08'),
    (20, 'Las Vegas Grand Prix', 'Las Vegas Strip Circuit', 'Paradise, Nevada', '2026-11-21'),
    (21, 'Qatar Grand Prix', 'Lusail International Circuit', 'Lusail', '2026-11-29'),
    (22, 'Abu Dhabi Grand Prix', 'Yas Marina Circuit', 'Abu Dhabi', '2026-12-06');

-- Race Results for 2026, Podium finishers

INSERT INTO `project-id.f1_2026.race_results` (race_id, driver_id, position, points, fastest_lap)
VALUES
-- =========================
-- Race 1 (Australia)
-- =========================
(1, 4, 1, 25, FALSE),
(1, 3, 2, 18, FALSE),
(1, 5, 3, 15, FALSE),
(1, 6, 4, 12, FALSE),
(1, 7, 5, 10, FALSE),
(1, 1, 6, 8, TRUE),
(1, 20, 7, 6, FALSE),
(1, 11, 8, 4, FALSE),
(1, 16, 9, 2, FALSE),
(1, 9, 10, 1, FALSE),
(1, 19, 11, 0, FALSE),
(1, 17, 12, 0, FALSE),
(1, 12, 13, 0, FALSE),
(1, 10, 14, 0, FALSE),
(1, 18, 15, 0, FALSE),
(1, 22, 16, 0, FALSE),
(1, 14, 17, 0, FALSE),
(1, 13, 18, 0, FALSE),
(1, 21, 19, 0, FALSE),
(1, 2, 20, 0, FALSE),
(1, 8, 21, 0, FALSE),
(1, 15, 22, 0, FALSE),

-- =========================
-- Race 2 (China)
-- =========================
(2, 3, 1, 25, TRUE),
(2, 4, 2, 18, FALSE),
(2, 6, 3, 15, FALSE),
(2, 5, 4, 12, FALSE),
(2, 20, 5, 10, FALSE),
(2, 9, 6, 8, FALSE),
(2, 12, 7, 6, FALSE),
(2, 2, 8, 4, FALSE),
(2, 18, 9, 2, FALSE),
(2, 10, 10, 1, FALSE),
(2, 15, 11, 0, FALSE),
(2, 11, 12, 0, FALSE),
(2, 21, 13, 0, FALSE),
(2, 19, 14, 0, FALSE),
(2, 22, 15, 0, FALSE),
(2, 1, 16, 0, FALSE),
(2, 13, 17, 0, FALSE),
(2, 14, 18, 0, FALSE),
(2, 8, 19, 0, FALSE),
(2, 7, 20, 0, FALSE),
(2, 16, 21, 0, FALSE),
(2, 17, 22, 0, FALSE),

-- =========================
-- Race 3 (Japan)
-- =========================
(3, 3, 1, 25, TRUE),
(3, 8, 2, 18, FALSE),
(3, 5, 3, 15, FALSE),
(3, 4, 4, 12, FALSE),
(3, 7, 5, 10, FALSE),
(3, 6, 6, 8, FALSE),
(3, 9, 7, 6, FALSE),
(3, 1, 8, 4, FALSE),
(3, 12, 9, 2, FALSE),
(3, 19, 10, 1, FALSE),
(3, 15, 11, 0, FALSE),
(3, 2, 12, 0, FALSE),
(3, 16, 13, 0, FALSE),
(3, 11, 14, 0, FALSE),
(3, 18, 15, 0, FALSE),
(3, 10, 16, 0, FALSE),
(3, 22, 17, 0, FALSE),
(3, 13, 18, 0, FALSE),
(3, 21, 19, 0, FALSE),
(3, 17, 20, 0, FALSE),
(3, 14, 21, 0, FALSE),
(3, 20, 22, 0, FALSE);



-- Current driver standings
INSERT INTO `project-id.f1_2026.driver_standings` (race_id, driver_id, position, points)
VALUES
    (3, 3, 1, 72),
    (3, 4, 2, 63),
    (3, 5, 3, 49),
    (3, 6, 4, 41),
    (3, 7, 5, 25),
    (3, 8, 6, 21),
    (3, 20, 7, 17),
    (3, 9, 8, 15),
    (3, 1, 9, 12),
    (3, 12, 10, 10),
    (3, 11, 11, 4),
    (3, 2, 12, 4),
    (3, 16, 13, 2),
    (3, 18, 14, 2),
    (3, 19, 15, 1),
    (3, 10, 16, 1),
    (3, 15, 17, 0),
    (3, 17, 18, 0),
    (3, 21, 19, 0),
    (3, 22, 20, 0),
    (3, 13, 21, 0),
    (3, 14, 22, 0);

-- Current constructor standings
INSERT INTO `project-id.f1_2026.constructor_standings` (race_id, constructor_id, position, points)
VALUES
    (3, 2, 1, 135),
    (3, 3, 2, 90),
    (3, 4, 3, 46),
    (3, 10, 4, 18),
    (3, 5, 5, 16),
    (3, 1, 6, 16),
    (3, 6, 7, 14),
    (3, 8, 8, 2),
    (3, 9, 9, 2),
    (3, 11, 10, 0),
    (3, 7, 11, 0);



-- END OF SCHEMA AND DATA INSERTION