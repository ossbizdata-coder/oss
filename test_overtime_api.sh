#!/bin/bash

# Test script to verify overtime/deduction data flow

echo "=== TESTING BACKEND API RESPONSES ==="

# Replace with your actual token
TOKEN="YOUR_JWT_TOKEN_HERE"
BASE_URL="http://74.208.132.78"

echo ""
echo "1. Testing GET /api/attendance/today"
echo "Should return: overtimeHours, deductionHours, overtimeReason, deductionReason"
curl -s -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/api/attendance/today" | jq '.'

echo ""
echo ""
echo "2. Testing GET /api/salary/me/monthly?year=2026&month=1"
echo "Should return dailyBreakdown with overtime/deduction fields"
curl -s -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/api/salary/me/monthly?year=2026&month=1" | jq '.dailyBreakdown[0]'

echo ""
echo ""
echo "3. Sample PUT /api/attendance/{id}/adjustments request:"
echo "curl -X PUT -H 'Authorization: Bearer TOKEN' -H 'Content-Type: application/json' \\"
echo "  -d '{\"overtimeHours\":2.5,\"deductionHours\":0,\"overtimeReason\":\"Extra work\",\"deductionReason\":null}' \\"
echo "  $BASE_URL/api/attendance/ID/adjustments"

echo ""
echo ""
echo "=== EXPECTED RESPONSE FORMATS ==="
echo ""
echo "GET /api/attendance/today should include:"
cat <<EOF
{
  "id": 123,
  "status": "COMPLETED",
  "checkInTime": "2026-01-18T08:00:00",
  "checkOutTime": "2026-01-18T17:00:00",
  "totalMinutes": 540,
  "overtimeHours": 2.0,
  "deductionHours": 0.0,
  "overtimeReason": "Client meeting extended",
  "deductionReason": null
}
EOF

echo ""
echo ""
echo "GET /api/salary/me/monthly dailyBreakdown should include:"
cat <<EOF
{
  "date": "2026-01-18",
  "hours": 9.0,
  "salary": 1750.0,
  "overtimeHours": 2.0,
  "deductionHours": 0.0,
  "overtimeReason": "Client meeting extended",
  "deductionReason": null,
  "qualified": true
}
EOF

echo ""

