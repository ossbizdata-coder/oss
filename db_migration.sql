-- Add daily salary columns
ALTER TABLE users ADD COLUMN daily_salary DOUBLE DEFAULT 0;
ALTER TABLE users ADD COLUMN deduction_rate_per_hour DOUBLE DEFAULT 0;

-- Set salary rates
UPDATE users SET daily_salary = 3000, deduction_rate_per_hour = 200 WHERE id = 7; -- Piumi
UPDATE users SET daily_salary = 1500, deduction_rate_per_hour = 125 WHERE id = 8; -- Dammi
UPDATE users SET daily_salary = 750, deduction_rate_per_hour = 125 WHERE id = 9; -- Vidusha

-- Add overtime/deduction tracking
ALTER TABLE attendance ADD COLUMN overtime_hours DOUBLE DEFAULT 0;
ALTER TABLE attendance ADD COLUMN deduction_hours DOUBLE DEFAULT 0;
ALTER TABLE attendance ADD COLUMN overtime_reason TEXT;
ALTER TABLE attendance ADD COLUMN deduction_reason TEXT;

