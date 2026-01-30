-- ========================================
-- QUICK FIX: Add January 30, 2026 Record
-- ========================================
-- Run this NOW to add today's record manually
-- Then fix the backend timezone issue permanently
-- ========================================

-- Add January 30, 2026 record (TODAY)
INSERT INTO attendance (user_id, work_date, status, is_working, overtime_hours, deduction_hours, overtime_reason, deduction_reason, manual_checkout)
VALUES (47, 1769817600000, 'WORKING', 1, 0.0, 0.0, NULL, NULL, 0);

-- Verify it was added
SELECT
    id,
    datetime(work_date/1000, 'unixepoch', 'localtime') as date,
    status,
    is_working,
    overtime_hours,
    deduction_hours
FROM attendance
WHERE user_id = 47
  AND work_date = 1769817600000;

