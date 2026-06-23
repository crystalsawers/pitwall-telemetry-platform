-- NOTE: Replace `project-id` with your actual Google Cloud project ID in the queries below. 
-- Also change the dataset name if you are using one not named `experimental_dataset`.
INSERT INTO `project-id.experimental_dataset.test_users`
(user_id, username, email, age, country, created_at)
VALUES
(1, 'bob', 'bob@test.com', 25, 'NZ', CURRENT_TIMESTAMP()),
(2, 'alex', 'alex@test.com', 30, 'AU', CURRENT_TIMESTAMP()),
(3, 'sam', 'sam@test.com', 22, 'NZ', CURRENT_TIMESTAMP());


SELECT * FROM `project-id.experimental_dataset.test_users` LIMIT 1000;