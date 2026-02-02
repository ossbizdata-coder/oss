# How to Change Attendance Dates

## Current Situation

You have attendance records with these timestamps:
- Jan 01, 2026 → `1767312000000` ✅ Keep as is
- Jan 02, 2026 → `1767398400000` ✅ Keep as is
- **Jan 06, 2026** → `1767551400000` ❌ Need to change to Jan 03
- **Jan 07, 2026** → `1767637800000` ❌ Need to change to Jan 04

---

## Solution: Update the Timestamps

You need to change the timestamps in your database to reflect the correct dates.

### New Timestamps Needed

| Current Date | Current Timestamp | New Date | New Timestamp | Difference |
|--------------|-------------------|----------|---------------|------------|
| Jan 06, 2026 | 1767551400000 | Jan 03, 2026 | **1767312000000 + (2 × 86400000)** = **1767484800000** | -3 days |
| Jan 07, 2026 | 1767637800000 | Jan 04, 2026 | **1767312000000 + (3 × 86400000)** = **1767571200000** | -3 days |

**Note:** 86400000 milliseconds = 1 day

### Calculation:
```
Jan 01, 2026 = 1767312000000

Jan 03, 2026 = 1767312000000 + (2 days × 86400000 ms/day)
             = 1767312000000 + 172800000
             = 1767484800000

Jan 04, 2026 = 1767312000000 + (3 days × 86400000 ms/day)
             = 1767312000000 + 259200000
             = 1767571200000
```

---

## Database Update SQL

### Option 1: Update by Record ID

If you know the record IDs (from your data: `51` and `54`):

```sql
-- Change Jan 06 to Jan 03
UPDATE attendance 
SET work_date = 1767484800000 
WHERE id = 51;

-- Change Jan 07 to Jan 04
UPDATE attendance 
SET work_date = 1767571200000 
WHERE id = 54;
```

### Option 2: Update by User and Current Date

If you want to be more specific:

```sql
-- Change Jan 06 to Jan 03 for User 8
UPDATE attendance 
SET work_date = 1767484800000 
WHERE user_id = 8 
  AND work_date = 1767551400000;

-- Change Jan 07 to Jan 04 for User 8
UPDATE attendance 
SET work_date = 1767571200000 
WHERE user_id = 8 
  AND work_date = 1767637800000;
```

### Option 3: Shift All Dates by 3 Days

If you want to shift all dates after Jan 02 by -3 days:

```sql
-- Shift dates by -3 days (subtract 259200000 ms)
UPDATE attendance 
SET work_date = work_date - 259200000
WHERE user_id = 8 
  AND work_date >= 1767484800000;  -- After Jan 02
```

**⚠️ Warning:** This will affect ALL dates, not just Jan 6 and 7!

---

## Verification

After updating, verify with:

```sql
SELECT id, user_id, work_date, 
       FROM_UNIXTIME(work_date/1000) as readable_date,
       status, overtime_hours, deduction_hours
FROM attendance 
WHERE user_id = 8 
ORDER BY work_date;
```

Expected result:
```
id  | user_id | work_date      | readable_date       | status
----|---------|----------------|---------------------|-------------
250 | 8       | 1767312000000  | 2026-01-01 00:00:00 | NOT_WORKING
3007| 8       | 1767398400000  | 2026-01-02 00:00:00 | NOT_WORKING
51  | 8       | 1767484800000  | 2026-01-03 00:00:00 | NOT_WORKING ← Changed
54  | 8       | 1767571200000  | 2026-01-04 00:00:00 | NOT_WORKING ← Changed
59  | 8       | 1767724200000  | 2026-01-08 00:00:00 | WORKING
```

---

## Alternative: Manual API Call (If Backend Supports)

If your backend has an update endpoint, you could use cURL:

```bash
# Update record 51 (Jan 6 → Jan 3)
curl -X PUT http://74.208.132.78/api/attendance/51 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_SUPERADMIN_TOKEN" \
  -d '{
    "workDate": 1767484800000
  }'

# Update record 54 (Jan 7 → Jan 4)
curl -X PUT http://74.208.132.78/api/attendance/54 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_SUPERADMIN_TOKEN" \
  -d '{
    "workDate": 1767571200000
  }'
```

---

## Timestamp Conversion Reference

Use this to calculate any date in January 2026:

| Date | Timestamp (milliseconds) |
|------|--------------------------|
| Jan 01, 2026 | 1767312000000 |
| Jan 02, 2026 | 1767398400000 |
| **Jan 03, 2026** | **1767484800000** ← Target |
| **Jan 04, 2026** | **1767571200000** ← Target |
| Jan 05, 2026 | 1767657600000 |
| Jan 06, 2026 | 1767744000000 |
| Jan 07, 2026 | 1767830400000 |
| Jan 08, 2026 | 1767916800000 |

Formula: `Jan 01 timestamp + (day_number - 1) × 86400000`

---

## Quick JavaScript Calculator

If you need to calculate timestamps:

```javascript
// Get timestamp for a specific date
const date = new Date('2026-01-03T00:00:00Z');
console.log(date.getTime()); // 1767484800000

// Convert timestamp to readable date
const timestamp = 1767484800000;
const readable = new Date(timestamp);
console.log(readable.toISOString()); // 2026-01-03T00:00:00.000Z
```

---

## Steps to Execute

1. **Backup your database first!**
   ```sql
   CREATE TABLE attendance_backup AS SELECT * FROM attendance;
   ```

2. **Run the UPDATE queries** (Option 1 or 2 above)

3. **Verify the changes** with the SELECT query

4. **Restart/Refresh** your Flutter app to see the updated dates

5. **Check the salary report** - should now show Jan 3 and Jan 4

---

## Expected Result

After the update, your attendance data will show:
```
✅ Jan 01, 2026 - Not Worked
✅ Jan 02, 2026 - Not Worked
✅ Jan 03, 2026 - Not Worked  ← Updated from Jan 6
✅ Jan 04, 2026 - Not Worked  ← Updated from Jan 7
✅ Jan 08, 2026 - Working
✅ Jan 09, 2026 - Working
...
```

---

## Important Notes

⚠️ **Data Integrity:**
- Ensure you don't create duplicate dates for the same user
- Check if Jan 03 and Jan 04 already exist before updating
- Consider the impact on salary calculations

⚠️ **Time Zone:**
- All timestamps are in UTC (as indicated by `isUtc: true` in the code)
- Make sure your database times align with UTC

⚠️ **Audit Trail:**
- Consider logging these changes if you have an audit system
- Document why dates were changed

---

**Last Updated:** February 1, 2026  
**Status:** Ready to execute database update  
**Risk Level:** Medium (affects historical data)

