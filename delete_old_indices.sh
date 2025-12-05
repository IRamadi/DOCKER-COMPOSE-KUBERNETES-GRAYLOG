#!/bin/bash

# Script to manually delete old Graylog indices
# This will delete indices beyond the configured max number

echo "=========================================="
echo "Graylog Old Indices Deletion Script"
echo "=========================================="
echo ""

# Check OpenSearch connection
echo "1. Checking OpenSearch connection..."
HEALTH=$(curl -s --max-time 5 --connect-timeout 3 http://localhost:9200/_cluster/health 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$HEALTH" ]; then
    echo "❌ ERROR: Cannot connect to OpenSearch"
    exit 1
fi
echo "   ✓ Connected"
echo ""

# Get all graylog indices sorted by creation date (oldest first)
echo "2. Listing Graylog indices (oldest first)..."
INDICES=$(curl -s --max-time 5 --connect-timeout 3 "http://localhost:9200/_cat/indices/graylog_*?v&h=index,creation.date.string,store.size&s=creation.date.string:asc" 2>/dev/null)

if [ -z "$INDICES" ]; then
    echo "   ❌ Could not retrieve indices"
    exit 1
fi

echo "$INDICES" | tail -n +2  # Skip header
echo ""

# Count indices
TOTAL_INDICES=$(echo "$INDICES" | tail -n +2 | wc -l)
echo "   Total graylog indices: $TOTAL_INDICES"
echo ""

# Ask how many to keep
read -p "3. How many indices do you want to keep? (currently have $TOTAL_INDICES): " KEEP_COUNT

if ! [[ "$KEEP_COUNT" =~ ^[0-9]+$ ]] || [ "$KEEP_COUNT" -ge "$TOTAL_INDICES" ]; then
    echo "   Invalid number. Aborting."
    exit 1
fi

# Calculate how many to delete
DELETE_COUNT=$((TOTAL_INDICES - KEEP_COUNT))
echo ""
echo "   Will delete $DELETE_COUNT oldest indices"
echo ""

# Get list of indices to delete (oldest ones)
INDICES_TO_DELETE=$(echo "$INDICES" | tail -n +2 | head -n $DELETE_COUNT | awk '{print $1}')

echo "4. Indices to be deleted:"
echo "$INDICES_TO_DELETE" | while read idx; do
    if [ ! -z "$idx" ]; then
        SIZE=$(echo "$INDICES" | grep "^$idx" | awk '{print $3}')
        echo "   - $idx ($SIZE)"
    fi
done
echo ""

# Confirm deletion
read -p "5. Are you sure you want to delete these indices? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "   Aborted."
    exit 0
fi

echo ""
echo "6. Deleting indices..."
SUCCESS=0
FAILED=0

echo "$INDICES_TO_DELETE" | while read idx; do
    if [ -z "$idx" ]; then
        continue
    fi
    
    echo -n "   Deleting $idx... "
    
    RESPONSE=$(curl -s --max-time 10 --connect-timeout 5 -X DELETE "http://localhost:9200/$idx" 2>/dev/null)
    
    if echo "$RESPONSE" | grep -q '"acknowledged":true'; then
        echo "✓ Deleted"
        SUCCESS=$((SUCCESS + 1))
    else
        echo "✗ Failed"
        echo "     Error: $RESPONSE" | head -3
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "7. Verifying deletion..."
sleep 2

NEW_INDICES=$(curl -s --max-time 5 --connect-timeout 3 "http://localhost:9200/_cat/indices/graylog_*?v&h=index" 2>/dev/null | tail -n +2 | wc -l)
echo "   Remaining indices: $NEW_INDICES"

# Check disk usage
echo ""
echo "8. Checking disk usage..."
DISK_USAGE=$(curl -s --max-time 5 --connect-timeout 3 http://localhost:9200/_cat/allocation?v 2>/dev/null | grep -v "shards" | awk '{print $6}' | head -1)
if [ ! -z "$DISK_USAGE" ]; then
    echo "   Current disk usage: ${DISK_USAGE}%"
fi

echo ""
echo "=========================================="
echo "Deletion Complete"
echo "=========================================="
echo ""
echo "📋 Next Steps:"
echo "1. Wait a few minutes for Graylog to update its index list"
echo "2. Check Graylog UI: http://localhost:9000 -> System -> Indices"
echo "3. Monitor disk usage to ensure it stays below 85%"

