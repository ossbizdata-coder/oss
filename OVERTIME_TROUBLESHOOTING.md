# 🔍 OVERTIME/DEDUCTION NOT SHOWING - TROUBLESHOOTING GUIDE

## ✅ What I've Fixed in Flutter (Just Now):

### 1. **Attendance Screen** (`attendence.dart`)
- ✅ Added overtime/deduction input fields (green/red sections)
- ✅ Added "Today's Adjustments" header with refresh button
- ✅ Fixed: Now **loads existing values** when screen opens
- ✅ Fixed: After saving, **reloads data** instead of clearing fields
- ✅ Added debug logging to see what backend returns

### 2. **Salary Screen** (`my_salary.dart`)
- ✅ Already has code to display overtime/deduction badges
- ✅ Added debug logging to show daily breakdown data

### 3. **Diagnostic Screen** (NEW - `diagnostic_screen.dart`)
- ✅ Created new screen showing RAW API responses
- ✅ Access via Menu → "🔧 API Diagnostic" (SUPERADMIN only)
- ✅ Shows exactly what backend is returning

---

## 🎯 HOW TO TROUBLESHOOT:

### Step 1: Open Diagnostic Screen
1. Login as SUPERADMIN
2. Go to Menu
3. Click "🔧 API Diagnostic"
4. You'll see TWO API responses displayed

### Step 2: Check Attendance API Response
Look at `GET /api/attendance/today` response.

**✅ Should include these fields:**
```json
{
  "id": 79,
  "status": "COMPLETED",
  "totalMinutes": 600,
  "overtimeHours": 2.0,           ← Check this
  "deductionHours": 0.0,          ← Check this
  "overtimeReason": "Client meeting extended",  ← Check this
  "deductionReason": null         ← Check this
}
```

**❌ If missing:** Backend attendance endpoint not returning these fields

### Step 3: Check Salary API Response
Look at `GET /api/salary/me/monthly` response.

**✅ dailyBreakdown should include:**
```json
{
  "dailyBreakdown": [
    {
      "date": "2026-01-02",
      "hours": 10.0,
      "salary": 1750.0,
      "overtimeHours": 2.0,         ← Check this
      "deductionHours": 0.0,        ← Check this
      "overtimeReason": "Client meeting extended",  ← Check this
      "deductionReason": null,      ← Check this
      "qualified": true             ← Check this
    }
  ]
}
```

**❌ If missing:** Backend salary service not populating DTO fields

---

## 🐛 COMMON ISSUES & FIXES:

### Issue 1: Fields are `null` in responses
**Cause:** Backend not returning the fields  
**Fix:** Check backend code - see `BACKEND_IMPLEMENTATION_VERIFIED.md`

### Issue 2: Fields exist but values are 0/null in database
**Cause:** No data saved yet  
**Fix:** Use attendance screen to enter overtime/deduction and save

### Issue 3: Can't save adjustments - "No attendance record found"
**Cause:** User hasn't checked in today  
**Fix:** Check in first, then add adjustments

### Issue 4: Saved successfully but fields don't update
**Cause:** Fixed in latest code - refresh should work now  
**Fix:** Click refresh button (🔄) next to "Today's Adjustments"

---

## 📱 FLUTTER APP STATUS:

### Attendance Screen:
```
✅ Input fields present (green/red boxes)
✅ Loads existing values on screen open
✅ Refresh button to reload latest values
✅ Saves to backend via PUT /api/attendance/{id}/adjustments
✅ Shows success message after save
✅ Debug logging enabled
```

### Salary Screen:
```
✅ Code to display overtime/deduction badges
✅ Reads overtimeHours, deductionHours from API
✅ Shows green badge if overtime > 0
✅ Shows red badge if deduction > 0
✅ Debug logging enabled
```

### What You Should See:
**On Attendance Page:**
- Input boxes pre-filled with saved values
- Can edit and save new values
- Refresh button updates display

**On Salary Page (if data exists):**
- Each day shows: "Base: Rs X/day"
- If overtime: Green badge "Overtime: 2.0 hrs (reason)"
- If deduction: Red badge "Deduct: 1.5 hrs (reason)"

---

## 🔧 TESTING STEPS:

### Test 1: Check Database
```bash
sqlite3 /path/to/database.db

SELECT id, overtime_hours, deduction_hours, overtime_reason, deduction_reason
FROM attendance 
WHERE user_id = 1 
  AND work_date >= '2026-01-01'
ORDER BY work_date DESC
LIMIT 10;
```

Expected: Should see your data from the dump (rows 79, 81, 83, 85, 88, 90)

### Test 2: Test Backend API Directly
```bash
# Get today's attendance
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://74.208.132.78/api/attendance/today

# Get salary
curl -H "Authorization: Bearer YOUR_TOKEN" \
  "http://74.208.132.78/api/salary/me/monthly?year=2026&month=1"
```

Check if responses include overtime/deduction fields.

### Test 3: Test in Flutter App
1. Open app, login
2. Go to Attendance screen
3. Check console output for: `DEBUG Attendance today data: {...}`
4. Go to Salary screen  
5. Check console output for: `DEBUG Daily item 0: {...}`

### Test 4: Save New Adjustment
1. Go to Attendance screen
2. Enter overtime: 2.5
3. Enter reason: "Testing"
4. Click Submit
5. Should see: "Adjustments saved successfully ✓"
6. Fields should reload with saved values
7. Go to Salary screen - should show green badge

---

## 📊 BACKEND VERIFICATION CHECKLIST:

Has the backend been updated with these?

### Entity Fields:
- ☐ `User.java` has `dailySalary` and `deductionRatePerHour`
- ☐ `Attendance.java` has all 4 overtime/deduction fields
- ☐ Database migration run successfully

### Service Layer:
- ☐ `SalaryReportService.calculateMyMonthlySalary()` populates overtime fields in DTO
- ☐ `SalaryReportService.getUserMonthlySalary()` populates overtime fields in DTO
- ☐ Salary calculation includes overtime/deduction adjustments

### Controller Layer:
- ☐ `OSS_AttendanceController.updateAttendanceAdjustments()` endpoint exists
- ☐ Endpoint accessible at `PUT /api/attendance/{id}/adjustments`
- ☐ Returns success response

### DTO:
- ☐ `OSS_DailySalaryDto` has all 5 extra fields (just fixed!)

### Backend Restart:
- ☐ Backend service restarted after code changes
- ☐ No startup errors in logs

---

## 🎯 NEXT ACTION:

**Run the diagnostic screen first!**

1. Login to app as SUPERADMIN
2. Menu → "🔧 API Diagnostic"
3. Screenshot the responses
4. Check if backend is returning the fields

If fields are missing → Backend issue  
If fields are present → Check console logs for parsing errors

**Share the diagnostic screen output and I'll tell you exactly what's wrong!**

---

Files created/updated:
- ✅ `lib/screens/attendence.dart` - Fixed loading/saving
- ✅ `lib/screens/my_salary.dart` - Added debug logging
- ✅ `lib/screens/diagnostic_screen.dart` - NEW diagnostic tool
- ✅ `lib/main.dart` - Added diagnostic route
- ✅ `lib/screens/menu.dart` - Added diagnostic menu item

