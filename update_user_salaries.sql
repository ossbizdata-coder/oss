-- Update user salary configurations
-- Run this on your database

-- Piumi (user_id = 7)
-- Daily salary: Rs 3000
-- Deduction rate per hour: Rs 200
UPDATE users
SET daily_salary = 3000.0,
    deduction_rate_per_hour = 200.0
WHERE id = 7;

-- Dammi (user_id = 8)
-- Daily salary: Rs 1500
-- Deduction rate per hour: Rs 125
UPDATE users
SET daily_salary = 1500.0,
    deduction_rate_per_hour = 125.0
WHERE id = 8;

-- Vidusha (user_id = 9)
-- Daily salary: Rs 750
-- Deduction rate per hour: Rs 125
UPDATE users
SET daily_salary = 750.0,
    deduction_rate_per_hour = 125.0
WHERE id = 9;

-- Verify the updates
SELECT id, name, daily_salary, deduction_rate_per_hour
FROM users
WHERE id IN (7, 8, 9);

-- Expected output:
-- 7|Piumi|3000.0|200.0
-- 8|Dammi|1500.0|125.0
-- 9|Vidusha|750.0|125.0

