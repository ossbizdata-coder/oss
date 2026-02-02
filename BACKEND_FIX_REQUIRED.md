# Backend Fix Required - Attendance Update APIs

## 🔴 CRITICAL ISSUE

Super admin cannot change staff attendance records because:
1. **Missing ID field**: `/api/attendance/all` returns records WITHOUT `id` field
2. **Missing API endpoints**: Backend doesn't have the required update endpoints

---

## Current Error

When super admin tries to change attendance:

```
📤 API Request - Update Status:
   - URL: http://74.208.132.78/api/attendance/update-status
   - Method: PUT
   - Body: {"userId":1,"workDate":"2026-01-30","status":"NOT_WORKING"}

📥 API Response - Update Status:
   - Status Code: 403 FORBIDDEN
   - Response Body: (empty)
```

**The endpoint `/api/attendance/update-status` doesn't exist or returns 403 Forbidden**

---

## SOLUTION 1: Implement New Endpoints (Quick Fix)

### Endpoint 1: Update Attendance Status

```
PUT /api/attendance/update-status
```

**Request Headers:**
```
Content-Type: application/json
Authorization: Bearer {superadmin_token}
```

**Request Body:**
```json
{
  "userId": 1,
  "workDate": "2026-01-30",
  "status": "NOT_WORKING"
}
```

**Status values:**
- `"WORKING"` - User worked that day
- `"NOT_WORKING"` - User did not work that day

**Success Response (200):**
```json
{
  "message": "Status updated successfully"
}
```

**Error Responses:**
- **401**: Invalid/missing token
- **403**: User is not SUPERADMIN
- **404**: No attendance record found for that user/date
- **400**: Invalid status value

---

### Endpoint 2: Update Attendance Adjustments

```
PUT /api/attendance/update-adjustments
```

**Request Headers:**
```
Content-Type: application/json
Authorization: Bearer {superadmin_token}
```

**Request Body:**
```json
{
  "userId": 1,
  "workDate": "2026-01-30",
  "overtimeHours": 2.0,
  "deductionHours": 0.5,
  "overtimeReason": "Extra project work",
  "deductionReason": "Late arrival"
}
```

**Success Response (200):**
```json
{
  "message": "Adjustments updated successfully"
}
```

---

## SOLUTION 2: Fix Existing API (Better Long-term)

### Problem: `/api/attendance/all` Missing ID Field

**Current Response (BROKEN):**
```json
[
  {
    "userId": 1,
    "workDate": "2026-01-30",
    "status": "WORKING",
    "overtimeHours": 0,
    "deductionHours": 0
    // ❌ NO "id" FIELD!
  }
]
```

**Required Response (FIXED):**
```json
[
  {
    "id": 123,  // ← ADD THIS!
    "userId": 1,
    "workDate": "2026-01-30",
    "status": "WORKING",
    "overtimeHours": 0,
    "deductionHours": 0
  }
]
```

If you add the `id` field, then implement these endpoints:

```
PUT /api/attendance/{id}/status
PUT /api/attendance/{id}/adjustments
```

---

## Backend Implementation Guide

### Option A: Spring Boot Example (New Endpoints)

```java
@RestController
@RequestMapping("/api/attendance")
public class AttendanceController {
    
    @PutMapping("/update-status")
    @PreAuthorize("hasRole('SUPERADMIN')")
    public ResponseEntity<?> updateStatus(@RequestBody StatusUpdateRequest request) {
        // Find attendance by userId and workDate
        Attendance attendance = attendanceRepo.findByUserIdAndWorkDate(
            request.getUserId(), 
            request.getWorkDate()
        );
        
        if (attendance == null) {
            return ResponseEntity.status(404)
                .body(Map.of("error", "Attendance record not found"));
        }
        
        // Update status
        attendance.setStatus(request.getStatus());
        attendanceRepo.save(attendance);
        
        return ResponseEntity.ok(Map.of("message", "Status updated successfully"));
    }
    
    @PutMapping("/update-adjustments")
    @PreAuthorize("hasRole('SUPERADMIN')")
    public ResponseEntity<?> updateAdjustments(@RequestBody AdjustmentUpdateRequest request) {
        // Find attendance by userId and workDate
        Attendance attendance = attendanceRepo.findByUserIdAndWorkDate(
            request.getUserId(), 
            request.getWorkDate()
        );
        
        if (attendance == null) {
            return ResponseEntity.status(404)
                .body(Map.of("error", "Attendance record not found"));
        }
        
        // Update adjustments
        attendance.setOvertimeHours(request.getOvertimeHours());
        attendance.setDeductionHours(request.getDeductionHours());
        attendance.setOvertimeReason(request.getOvertimeReason());
        attendance.setDeductionReason(request.getDeductionReason());
        attendanceRepo.save(attendance);
        
        return ResponseEntity.ok(Map.of("message", "Adjustments updated successfully"));
    }
}

// Request DTOs
class StatusUpdateRequest {
    private Integer userId;
    private LocalDate workDate;
    private String status;
    // getters/setters
}

class AdjustmentUpdateRequest {
    private Integer userId;
    private LocalDate workDate;
    private Double overtimeHours;
    private Double deductionHours;
    private String overtimeReason;
    private String deductionReason;
    // getters/setters
}
```

### Add to Repository:

```java
public interface AttendanceRepository extends JpaRepository<Attendance, Long> {
    Optional<Attendance> findByUserIdAndWorkDate(Integer userId, LocalDate workDate);
}
```

### Option B: SQL-based Implementation

```sql
-- Update status
UPDATE attendance 
SET status = ? 
WHERE user_id = ? AND work_date = ?;

-- Update adjustments
UPDATE attendance 
SET overtime_hours = ?,
    deduction_hours = ?,
    overtime_reason = ?,
    deduction_reason = ?
WHERE user_id = ? AND work_date = ?;
```

---

## Security Requirements

### ✅ Must Check:
1. User is authenticated (valid JWT token)
2. User has `SUPERADMIN` role
3. Attendance record exists before updating

### ❌ Return 403 Forbidden if:
- User is not SUPERADMIN
- Token is invalid/expired

### ❌ Return 404 Not Found if:
- No attendance record exists for that userId + workDate

---

## Testing

### Using cURL:

```bash
# Get your SUPERADMIN token first
TOKEN="eyJhbGciOiJIUzI1NiJ9..."

# Test update status
curl -X PUT http://74.208.132.78/api/attendance/update-status \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "userId": 1,
    "workDate": "2026-01-30",
    "status": "NOT_WORKING"
  }'

# Test update adjustments
curl -X PUT http://74.208.132.78/api/attendance/update-adjustments \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "userId": 1,
    "workDate": "2026-01-30",
    "overtimeHours": 2.0,
    "deductionHours": 0.0,
    "overtimeReason": "Test",
    "deductionReason": ""
  }'
```

Expected response: `200 OK` with success message

---

## Summary

### What Backend Needs to Do:

✅ **Step 1:** Add repository method to find attendance by userId + workDate
```java
Optional<Attendance> findByUserIdAndWorkDate(Integer userId, LocalDate workDate);
```

✅ **Step 2:** Create endpoint `PUT /api/attendance/update-status`
- Accept: userId, workDate, status
- Validate: SUPERADMIN only
- Update: status field

✅ **Step 3:** Create endpoint `PUT /api/attendance/update-adjustments`
- Accept: userId, workDate, overtimeHours, deductionHours, reasons
- Validate: SUPERADMIN only  
- Update: overtime/deduction fields

✅ **Step 4:** Return proper status codes:
- 200: Success
- 400: Invalid input
- 403: Not authorized
- 404: Record not found

---

## Alternative (If You Prefer ID-based Approach)

If you want to keep using ID-based endpoints:

1. **Fix `/api/attendance/all`** to include `id` field in response
2. **Create endpoints:**
   - `PUT /api/attendance/{id}/status`
   - `PUT /api/attendance/{id}/adjustments`

Then I'll update the frontend to use those instead.

---

## Current Status

- ✅ Frontend is ready with composite key approach
- ✅ Comprehensive logging added
- ⏳ **WAITING FOR BACKEND** to implement the endpoints
- ❌ 403 Forbidden error indicates endpoints don't exist or no SUPERADMIN check

---

**Priority:** 🔴 **CRITICAL** - Blocks all super admin attendance management  
**Impact:** Super admins cannot modify staff attendance records  
**Effort:** ~1-2 hours backend development  

---

**Contact:** Frontend Developer  
**Date:** January 31, 2026

