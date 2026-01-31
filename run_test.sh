#!/bin/bash
# ============================================
# Quick Test Script - Run Transformation Diagnostics
# ============================================

echo "=========================================="
echo "TRANSFORMATION DIAGNOSTIC TEST"
echo "=========================================="
echo ""

# Check if snowsql is available
if ! command -v snowsql &> /dev/null; then
    echo "❌ snowsql command not found"
    echo ""
    echo "Please run the SQL queries manually in your SQL client:"
    echo "  File: TEST_TRANSFORMATION_MANUAL.sql"
    echo ""
    echo "Or install snowsql: https://docs.snowflake.com/en/user-guide/snowsql-install-config.html"
    exit 1
fi

# Check if connection is configured
echo "📋 Checking Snowflake connection..."
echo ""

# Prompt for connection name
read -p "Enter your Snowflake connection name (or press Enter for default): " CONNECTION_NAME

if [ -z "$CONNECTION_NAME" ]; then
    CONNECTION_NAME="default"
fi

echo ""
echo "🔍 Running diagnostics..."
echo ""

# Run the test script
snowsql -c "$CONNECTION_NAME" -f TEST_TRANSFORMATION_MANUAL.sql -o output_format=psql -o friendly=false -o timing=false

echo ""
echo "=========================================="
echo "TEST COMPLETE"
echo "=========================================="
echo ""
echo "Review the output above to see:"
echo "  1. Source data count"
echo "  2. Field mapping status"
echo "  3. Transformation result"
echo "  4. Final diagnostic summary"
echo ""
