#!/bin/bash

# Quick test script for overtime/deduction feature
# Usage: ./test_overtime.sh YOUR_JWT_TOKEN

TOKEN="$1"
BASE_URL="http://74.208.132.78"

if [ -z "$TOKEN" ]; then
    echo "❌ Error: Please provide JWT token"
    echo "Usage: $0 YOUR_JWT_TOKEN"
    exit 1
fi

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  Testing Overtime/Deduction Feature                             ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Test 1: Check user salary config
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 1: User Salary Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/users/me")
DAILY_SALARY=$(echo $RESPONSE | jq -r '.dailySalary // 0')
DEDUCTION_RATE=$(echo $RESPONSE | jq -r '.deductionRatePerHour // 0')

echo "Daily Salary: Rs $DAILY_SALARY"
echo "Deduction Rate/hr: Rs $DEDUCTION_RATE"

if [ "$DAILY_SALARY" == "0" ]; then
    echo "❌ FAIL: Daily salary not configured"
else
    echo "✅ PASS: Daily salary configured"
fi
echo ""

# Test 2: Check attendance today
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 2: Attendance Today API"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ATT_RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/attendance/today")

if [ -z "$ATT_RESPONSE" ]; then
    echo "❌ FAIL: Empty response"
else
    echo "$ATT_RESPONSE" | jq '.'
    HAS_OVERTIME=$(echo $ATT_RESPONSE | jq 'has("overtimeHours")')
    if [ "$HAS_OVERTIME" == "true" ]; then
        echo "✅ PASS: Has overtimeHours field"
    else
        echo "❌ FAIL: Missing overtimeHours field"
    fi
fi
echo ""

# Test 3: Check salary breakdown
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 3: Salary Monthly Breakdown"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
YEAR=$(date +%Y)
MONTH=$(date +%-m)
SAL_RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "$BASE_URL/api/salary/me/monthly?year=$YEAR&month=$MONTH")

FIRST_DAY=$(echo $SAL_RESPONSE | jq '.dailyBreakdown[0]')
echo "First day breakdown:"
echo "$FIRST_DAY" | jq '.'

HAS_OVERTIME_FIELD=$(echo $FIRST_DAY | jq 'has("overtimeHours")')
HAS_DEDUCTION_FIELD=$(echo $FIRST_DAY | jq 'has("deductionHours")')
HAS_QUALIFIED_FIELD=$(echo $FIRST_DAY | jq 'has("qualified")')

if [ "$HAS_OVERTIME_FIELD" == "true" ] && \
   [ "$HAS_DEDUCTION_FIELD" == "true" ] && \
   [ "$HAS_QUALIFIED_FIELD" == "true" ]; then
    echo "✅ PASS: All required fields present"
else
    echo "❌ FAIL: Missing fields:"
    [ "$HAS_OVERTIME_FIELD" != "true" ] && echo "  - overtimeHours"
    [ "$HAS_DEDUCTION_FIELD" != "true" ] && echo "  - deductionHours"
    [ "$HAS_QUALIFIED_FIELD" != "true" ] && echo "  - qualified"
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$DAILY_SALARY" != "0" ] && \
   [ "$HAS_OVERTIME_FIELD" == "true" ] && \
   [ "$HAS_DEDUCTION_FIELD" == "true" ]; then
    echo "✅ ALL TESTS PASSED - Feature is working!"
else
    echo "❌ SOME TESTS FAILED - See details above"
    echo ""
    echo "Action Required:"
    [ "$DAILY_SALARY" == "0" ] && echo "  1. Run update_user_salaries.sql"
    [ "$HAS_OVERTIME_FIELD" != "true" ] && echo "  2. Fix backend SalaryReportService.java"
    [ -z "$ATT_RESPONSE" ] && echo "  3. Fix backend OSS_AttendanceController.java"
    echo "  4. Restart backend service"
fi
echo ""

