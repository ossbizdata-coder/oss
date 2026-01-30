-- Fix January 2025 timestamps to January 2026
-- This updates records 200-222 to be in January 2026 instead of January 2025

-- January 2026 starts at: 1735689600000 (Jan 1, 2026 00:00:00 UTC)
-- We need to add exactly 1 year (31,536,000,000 milliseconds) to each timestamp

-- Update all January 2025 records to January 2026
UPDATE attendance
SET work_date = work_date + 31536000000  -- Add 1 year in milliseconds
WHERE user_id = 47
  AND id BETWEEN 200 AND 222
  AND work_date >= 1735689000000  -- Jan 1, 2025
  AND work_date <= 1738367999999; -- Jan 31, 2025

-- Verify the changes
SELECT
    id,
    status,
    work_date,
    FROM_UNIXTIME(work_date/1000) as readable_date,
    overtime_hours,
    deduction_hours,
    overtime_reason,
    deduction_reason
FROM attendance
WHERE user_id = 47
  AND id BETWEEN 200 AND 229
ORDER BY work_date;

-- Expected result: All records 200-222 should now show dates in January 2026

