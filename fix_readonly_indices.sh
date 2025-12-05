#!/bin/bash

# Fix OpenSearch Read-Only Indices
# This script removes read-only blocks from indices when disk space is available

echo "=========================================="
echo "OpenSearch Read-Only Indices Fix"
echo "=========================================="
echo ""

# Check OpenSearch health first
echo "1. Checking OpenSearch connection..."
HEALTH=$(curl -s --max-time 5 --connect-timeout 3 http://localhost:9200/_cluster/health 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$HEALTH" ]; then
    echo "❌ ERROR: Cannot connect to OpenSearch at http://localhost:9200"
    echo "   Make sure OpenSearch container is running: docker ps | grep opensearch"
    exit 1
fi

STATUS=$(echo "$HEALTH" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
echo "   Cluster status: $STATUS"
echo ""

# Check disk usage
echo "2. Checking disk usage..."
DISK_USAGE=$(curl -s --max-time 5 --connect-timeout 3 http://localhost:9200/_cat/allocation?v 2>/dev/null | grep -v "shards" | awk '{print $6}' | sed 's/%//' | head -1)
if [ ! -z "$DISK_USAGE" ]; then
    echo "   Current disk usage: ${DISK_USAGE}%"
    if [ "$DISK_USAGE" -gt 90 ]; then
        echo "   ⚠️  WARNING: Disk usage is above 90%!"
        echo "   You should free up space before removing read-only blocks"
        echo ""
        read -p "   Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "   Aborted. Please free up disk space first."
            exit 1
        fi
    fi
fi
echo ""

# Get all indices with read-only status
echo "3. Finding read-only indices..."
INDICES=$(curl -s --max-time 5 --connect-timeout 3 "http://localhost:9200/_cat/indices?v&h=index,status" 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$INDICES" ]; then
    echo "   ❌ Could not retrieve indices list"
    exit 1
fi

READONLY_INDICES=$(echo "$INDICES" | grep -i "read_only" | awk '{print $1}')
READONLY_COUNT=$(echo "$READONLY_INDICES" | grep -v "^$" | wc -l)

if [ "$READONLY_COUNT" -eq 0 ]; then
    echo "   ✓ No read-only indices found!"
    exit 0
fi

echo "   Found $READONLY_COUNT read-only indices:"
echo "$READONLY_INDICES" | while read idx; do
    [ ! -z "$idx" ] && echo "     - $idx"
done
echo ""

# Remove read-only blocks
echo "4. Removing read-only blocks..."
SUCCESS=0
FAILED=0

echo "$READONLY_INDICES" | while read idx; do
    if [ -z "$idx" ]; then
        continue
    fi
    
    echo -n "   Fixing $idx... "
    
    # Remove read-only block
    RESPONSE=$(curl -s --max-time 10 --connect-timeout 5 -X PUT "http://localhost:9200/$idx/_settings" \
        -H 'Content-Type: application/json' \
        -d '{
            "index": {
                "blocks": {
                    "read_only_allow_delete": "false"
                }
            }
        }' 2>/dev/null)
    
    if echo "$RESPONSE" | grep -q '"acknowledged":true'; then
        echo "✓ Success"
        SUCCESS=$((SUCCESS + 1))
    else
        echo "✗ Failed"
        echo "     Error: $RESPONSE" | head -3
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "5. Verifying fix..."
sleep 2

VERIFY=$(curl -s --max-time 5 --connect-timeout 3 "http://localhost:9200/_cat/indices?v&h=index,status" 2>/dev/null)
STILL_READONLY=$(echo "$VERIFY" | grep -i "read_only" | wc -l)

if [ "$STILL_READONLY" -eq 0 ]; then
    echo "   ✓ All indices are now writable!"
else
    echo "   ⚠️  Warning: $STILL_READONLY indices are still in read-only mode"
    echo "   This may be because disk space is still too low"
fi
echo ""

echo "=========================================="
echo "Fix Complete"
echo "=========================================="
echo ""
echo "📋 Next Steps:"
echo "1. Free up disk space by deleting old indices:"
echo "   - Go to Graylog UI: http://localhost:9000 -> System -> Indices"
echo "   - Delete old indices (keep only recent ones)"
echo ""
echo "2. Configure index retention to prevent this:"
echo "   - Graylog UI -> System -> Indices -> Edit Index Set"
echo "   - Set 'Max Number of Indices' to 10-15"
echo "   - Set 'Max Size per Index' to 5-10GB"
echo ""
echo "3. Monitor disk usage:"
echo "   - Run: curl -s http://localhost:9200/_cat/allocation?v"
echo "   - Keep disk usage below 85%"

