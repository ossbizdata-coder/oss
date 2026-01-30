# Backend Changes Required for NOT_WORKING Status

## Problem
Currently, when a user clicks "NO" (not working today), the frontend calls `POST /api/attendance/check-out`, which sets the status to `COMPLETED` instead of `NOT_WORKING`. This makes it appear as if the user worked on that day in the reports.

## Required Backend Changes

### Option 1: Add New Endpoint (RECOMMENDED)

Add a new endpoint to explicitly mark a day as NOT_WORKING:

**Endpoint:** `POST /api/attendance/not-working`

**Java Controller Method:**
```java
@PostMapping("/not-working")
public ResponseEntity<Attendance> markNotWorking() {
    User currentUser = getCurrentAuthenticatedUser();
    LocalDate today = LocalDate.now();
    
    // Check if attendance record exists for today
    Optional<Attendance> existingAttendance = attendanceRepository
        .findByUserAndWorkDate(currentUser, today);
    
    Attendance attendance;
    
    if (existingAttendance.isPresent()) {
        // Update existing record
        attendance = existingAttendance.get();
        attendance.setStatus(AttendanceStatus.NOT_WORKING);
        attendance.setCheckInTime(null);
        attendance.setCheckOutTime(null);
        attendance.setTotalMinutes(null);
        attendance.setOvertimeHours(0.0);
        attendance.setDeductionHours(0.0);
        attendance.setOvertimeReason(null);
        attendance.setDeductionReason(null);
    } else {
        // Create new record with NOT_WORKING status
        attendance = new Attendance();
        attendance.setUser(currentUser);
        attendance.setWorkDate(today);
        attendance.setStatus(AttendanceStatus.NOT_WORKING);
        attendance.setCheckInTime(null);
        attendance.setCheckOutTime(null);
        attendance.setTotalMinutes(null);
        attendance.setOvertimeHours(0.0);
        attendance.setDeductionHours(0.0);
        attendance.setManualCheckout(false);
    }
    
    Attendance saved = attendanceRepository.save(attendance);
    return ResponseEntity.ok(saved);
}
```

### Option 2: Modify Existing Check-Out Endpoint

Modify the `POST /api/attendance/check-out` endpoint to accept an optional parameter:

**Endpoint:** `POST /api/attendance/check-out?notWorking=true`

```java
@PostMapping("/check-out")
public ResponseEntity<Attendance> checkOut(@RequestParam(required = false) Boolean notWorking) {
    User currentUser = getCurrentAuthenticatedUser();
    LocalDate today = LocalDate.now();
    
    Optional<Attendance> attendanceOpt = attendanceRepository
        .findByUserAndWorkDate(currentUser, today);
    
    if (attendanceOpt.isEmpty()) {
        // If notWorking is true, create a NOT_WORKING record
        if (Boolean.TRUE.equals(notWorking)) {
            Attendance attendance = new Attendance();
            attendance.setUser(currentUser);
            attendance.setWorkDate(today);
            attendance.setStatus(AttendanceStatus.NOT_WORKING);
            attendance.setOvertimeHours(0.0);
            attendance.setDeductionHours(0.0);
            attendance.setManualCheckout(false);
            return ResponseEntity.ok(attendanceRepository.save(attendance));
        }
        return ResponseEntity.badRequest().build();
    }
    
    Attendance attendance = attendanceOpt.get();
    
    // If notWorking flag is set, just mark as NOT_WORKING
    if (Boolean.TRUE.equals(notWorking)) {
        attendance.setStatus(AttendanceStatus.NOT_WORKING);
        attendance.setCheckInTime(null);
        attendance.setCheckOutTime(null);
        attendance.setTotalMinutes(null);
        attendance.setOvertimeHours(0.0);
        attendance.setDeductionHours(0.0);
        attendance.setOvertimeReason(null);
        attendance.setDeductionReason(null);
    } else {
        // Normal check-out logic
        attendance.setCheckOutTime(LocalDateTime.now());
        attendance.setStatus(AttendanceStatus.COMPLETED);
        // ... calculate total minutes, etc.
    }
    
    return ResponseEntity.ok(attendanceRepository.save(attendance));
}
```

### Option 3: Add Status Update Endpoint

Add a general endpoint to update attendance status:

**Endpoint:** `PUT /api/attendance/{id}/status`

```java
@PutMapping("/{id}/status")
public ResponseEntity<Attendance> updateStatus(
    @PathVariable Long id,
    @RequestBody Map<String, String> request
) {
    User currentUser = getCurrentAuthenticatedUser();
    
    Optional<Attendance> attendanceOpt = attendanceRepository.findById(id);
    if (attendanceOpt.isEmpty()) {
        return ResponseEntity.notFound().build();
    }
    
    Attendance attendance = attendanceOpt.get();
    
    // Verify user owns this record (security check)
    if (!attendance.getUser().getId().equals(currentUser.getId())) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
    }
    
    String newStatus = request.get("status");
    if (newStatus == null) {
        return ResponseEntity.badRequest().build();
    }
    
    try {
        AttendanceStatus status = AttendanceStatus.valueOf(newStatus);
        attendance.setStatus(status);
        
        // If changing to NOT_WORKING, clear work-related fields
        if (status == AttendanceStatus.NOT_WORKING) {
            attendance.setCheckInTime(null);
            attendance.setCheckOutTime(null);
            attendance.setTotalMinutes(null);
            attendance.setOvertimeHours(0.0);
            attendance.setDeductionHours(0.0);
            attendance.setOvertimeReason(null);
            attendance.setDeductionReason(null);
        }
        
        return ResponseEntity.ok(attendanceRepository.save(attendance));
    } catch (IllegalArgumentException e) {
        return ResponseEntity.badRequest().build();
    }
}
```

## Recommended Solution

**Use Option 1** - Add a dedicated `POST /api/attendance/not-working` endpoint. This is:
- Clear and explicit in intent
- Easier to understand and maintain
- RESTful design
- Prevents confusion with check-out functionality

## Additional Backend Fixes

### Fix Date Issue
The debug logs show records are being created for wrong dates:
```
DEBUG TEMP FIX: Using record from 2026-01-29 (should be today but backend needs fix)
```

Check your backend timezone configuration:
```java
// In application.properties or application.yml
spring.jpa.properties.hibernate.jdbc.time_zone=UTC

// Or in entity
@Column(name = "work_date")
@JsonFormat(pattern = "yyyy-MM-dd")
private LocalDate workDate;
```

### Allow DELETE Operations
Currently DELETE returns 403:
```
DEBUG Delete response: 403
```

Update the DELETE endpoint to allow users to delete their own attendance records:
```java
@DeleteMapping("/{id}")
public ResponseEntity<Void> deleteAttendance(@PathVariable Long id) {
    User currentUser = getCurrentAuthenticatedUser();
    
    Optional<Attendance> attendanceOpt = attendanceRepository.findById(id);
    if (attendanceOpt.isEmpty()) {
        return ResponseEntity.notFound().build();
    }
    
    Attendance attendance = attendanceOpt.get();
    
    // Only allow deleting own records (or admin can delete any)
    if (!attendance.getUser().getId().equals(currentUser.getId()) 
        && !currentUser.getRole().equals("ADMIN")) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
    }
    
    attendanceRepository.delete(attendance);
    return ResponseEntity.noContent().build();
}
```

## Testing After Backend Changes

After implementing the backend changes, test:
1. Click YES → Should create CHECKED_IN or WORKING status
2. Click NO → Should create NOT_WORKING status
3. Switch from NO to YES → Should update to WORKING
4. Switch from YES to NO → Should update to NOT_WORKING
5. Reports should show NOT_WORKING days as "Not Worked"

