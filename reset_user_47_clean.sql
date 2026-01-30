-- ========================================
-- RESET ATTENDANCE DATA FOR USER 47
-- ========================================
-- Date: January 30, 2026
-- Clean slate with consistent data
-- ========================================

-- Step 1: Delete ALL existing attendance records for user 47
DELETE FROM attendance WHERE user_id = 47;

-- Step 2: Create clean attendance data for January 2026
-- Today is January 30, 2026
-- Only create records up to and including TODAY (no future dates)

-- January 1 - Worked
INSERT INTO attendance (user_id, work_date, status, is_working, overtime_hours, deduction_hours, overtime_reason, deduction_reason, manual_checkout)
VALUES (47, 1767225000000, 'WORKING', 1, 0.0, 0.0, NULL, NULL, 0);

-- January 2 - Worked with 2h overtime
INSERT INTO attendance (user_id, work_date, status, is_working, overtime_hours, deduction_hours, overtime_reason, deduction_reason, manual_checkout)
VALUES (47, 1767311400000, 'WORKING', 1, 2.0, 0.0, 'Client presentation preparation', NULL, 0);

-- January 3 - Worked
INSERT INTO attendance (user_id, work_date, status, is_working, overtime_hours, deduction_hours, overtime_reason, deduction_reason, manual_checkout)
VALUES (47, 1767397800000, 'WORKING', 1, 0.0, 0.0, NULL, NULL, 0);

-- January 6 - Worked
INSERT INTO attendance (user_id, work_date, status, is_working, overtime_hours, deduction_hours, overtime_reason, deduction_reason, manual_checkout)
VALUES (47, 1767670200000, 'WORKING', 1, 0.0, 0.0, NULL, NULL, 0);

-- January 7 - Worked with 1.5h deduction
INSERT INTO attendance (user_id, work_date, status, is_working, overtime_hours, deduction_hours, overtime_reason, deduction_reason, manual_checkout)
VALUES (47, 1767756600000, 'WORKING', 1, 0.0, 1.5, NULL, 'Medical appointment', 0);

-- January 8 - Worked
INSERT INTO attendance (user_id, work_date, status, is_working, overtime_hours, deduction_hours, overtime_reason, deduction_reason, manual_checkout)
VALUES (47, 1767843000000, 'WORKING', 1, 0.0, 0.0, NULL, NULL, 0);

-- January 9 - Worked with 3h overtime
INSERT INTO attendance (user_id, work_date, status, is_working, overtime_hours, deduction_hours, overtime_reason, deduction_reason, manual_checkout)
VALUES (47, 1767929400000, 'WORKING', 1, 3.0, 0.0, 'System deployment and monitoring', NULL, 0);

-- January 10 - Worked
INSERT INTO attendance (user_id, work_date, status, is_working, overtime_hours, deduction_hours, overtime_reason, deduction_reason, manual_checkout)
VALUES (47, 1768015800000, 'WORKING', 1, 0.0, 0.0, NULL, NULL, 0);

-- January 13 - Worked
INSERT INTO attendance (user_id, work_date, status, is_working, overtime_hours, deduction_hours, overtime_reason, deduction_reason, manual_checkout)
VALUES (47, 1768288200000, 'WORKING', 1, 0.0, 0.0, NULL, NULL, 0);

-- January 14 - Worked with both overtime and deduction
INSERT INTO attendance (user_id, work_date, status, is_working, overtime_hours, deduction_hours, overtime_reason, deduction_reason, manual_checkout)
VALUES (47, 1768374600000, 'WORKING', 1, 1.5, 0.5, 'Evening team meeting', 'Left early for bank', 0);

-- January 15 - Worked
INSERT INTO attendance (user_id, work_date, status, is_working, overtime_hours, deduction_hours, overtime_reason, deduction_reason, manual_checkout)
VALUES (47, 1768461000000, 'WORKING', 1, 0.0, 0.0, NULL, NULL, 0);

-- January 16 - Did NOT work
INSERT INTO attendance (user_id, work_date, status, is_working, overtime_hours, deduction_hours, overtime_reason, deduction_reason, manual_checkout)
VALUES (47, 1768547400000, 'NOT_WORKING', 0, 0.0, 0.0, NULL, NULL, 0);

-- January 17 - Worked with 4h overtime
INSERT INTO attendance (user_id, work_date, status, is_working, overtime_hours, deduction_hours, overtime_reason, deduction_reason, manual_checkout)
VALUES (47, 1768633800000, 'WORKING', 1, 4.0, 0.0, 'Critical bug fix and testing', NULL, 0);

-- January 20 - Worked
INSERT INTO attendance (user_id, work_date, status, is_working, overtime_hours, deduction_hours, overtime_reason, deduction_reason, manual_checkout)
VALUES (47, 1768906200000, 'WORKING', 1, 0.0, 0.0, NULL, NULL, 0);

-- January 21 - Worked with 2.5h deduction
INSERT INTO attendance (user_id, work_date, status, is_working, overtime_hours, deduction_hours, overtime_reason, deduction_reason, manual_checkout)
VALUES (47, 1768992600000, 'WORKING', 1, 0.0, 2.5, NULL, 'Personal matter - left at 2 PM', 0);

-- January 22 - Worked
INSERT INTO attendance (user_id, work_date, status, is_working, overtime_hours, deduction_hours, overtime_reason, deduction_reason, manual_checkout)
VALUES (47, 1769079000000, 'WORKING', 1, 0.0, 0.0, NULL, NULL, 0);

-- January 23 - Worked with 1.5h overtime
INSERT INTO attendance (user_id, work_date, status, is_working, overtime_hours, deduction_hours, overtime_reason, deduction_reason, manual_checkout)
VALUES (47, 1769165400000, 'WORKING', 1, 1.5, 0.0, 'Monthly report completion', NULL, 0);

-- January 24 - Worked
INSERT INTO attendance (user_id, work_date, status, is_working, overtime_hours, deduction_hours, overtime_reason, deduction_reason, manual_checkout)
VALUES (47, 1769251800000, 'WORKING', 1, 0.0, 0.0, NULL, NULL, 0);

-- January 27 - Worked
INSERT INTO attendance (user_id, work_date, status, is_working, overtime_hours, deduction_hours, overtime_reason, deduction_reason, manual_checkout)
VALUES (47, 1769524200000, 'WORKING', 1, 0.0, 0.0, NULL, NULL, 0);

-- January 28 - Worked with 2h overtime
INSERT INTO attendance (user_id, work_date, status, is_working, overtime_hours, deduction_hours, overtime_reason, deduction_reason, manual_checkout)
VALUES (47, 1769610600000, 'WORKING', 1, 2.0, 0.0, 'Training session for new staff', NULL, 0);

-- January 29 - Did NOT work
INSERT INTO attendance (user_id, work_date, status, is_working, overtime_hours, deduction_hours, overtime_reason, deduction_reason, manual_checkout)
VALUES (47, 1769697000000, 'NOT_WORKING', 0, 0.0, 0.0, NULL, NULL, 0);

-- January 30 - TODAY - Worked (ready for user to modify via YES/NO buttons)
INSERT INTO attendance (user_id, work_date, status, is_working, overtime_hours, deduction_hours, overtime_reason, deduction_reason, manual_checkout)
VALUES (47, 1769817600000, 'WORKING', 1, 0.0, 0.0, NULL, NULL, 0);

-- ========================================
-- SUMMARY OF CLEAN DATA
-- ========================================
-- Total records: 22
-- Days worked (is_working=1): 20 days
-- Days NOT worked (is_working=0): 2 days (Jan 16, Jan 29)
-- Total overtime: 14.0 hours
-- Total deductions: 4.5 hours
-- No check-in timestamps (all NULL)
-- No future dates (only up to Jan 30)
-- ========================================

