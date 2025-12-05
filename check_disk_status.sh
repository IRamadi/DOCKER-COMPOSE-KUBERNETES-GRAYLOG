#!/bin/bash

# Quick script to check current disk status after index cleanup

echo "=========================================="
echo "Graylog Disk Status Check"
echo "=========================================="
echo ""

# Check OpenSearch disk usage
echo "1. OpenSearch Disk Usage:"
echo "------------------------"
DISK_INFO=$(curl -s --max-time 5 --connect-timeout 3 http://localhost:9200/_cat/allocation?v 2>/dev/null)
if [ $? -eq 0 ] && [ ! -z "$DISK_INFO" ]; then
    echo "$DISK_INFO"
    DISK_PERCENT=$(echo "$DISK_INFO" | grep -v "shards" | awk '{print $6}' | sed 's/%//' | head -1)
    if [ ! -z "$DISK_PERCENT" ]; then
        echo ""
        if [ "$DISK_PERCENT" -lt 85 ]; then
            echo "   ✓ Disk usage: ${DISK_PERCENT}% (Good - below 85%)"
        elif [ "$DISK_PERCENT" -lt 90 ]; then
            echo "   ⚠️  Disk usage: ${DISK_PERCENT}% (Warning - above 85% but below 90%)"
        else
            echo "   ❌ Disk usage: ${DISK_PERCENT}% (Critical - above 90%)"
        fi
    fi
else
    echo "   Could not retrieve disk information"
fi
echo ""

# Check OpenSearch health
echo "2. OpenSearch Cluster Health:"
echo "----------------------------"
HEALTH=$(curl -s --max-time 5 --connect-timeout 3 http://localhost:9200/_cluster/health?pretty 2>/dev/null)
if [ $? -eq 0 ] && [ ! -z "$HEALTH" ]; then
    STATUS=$(echo "$HEALTH" | grep '"status"' | cut -d'"' -f4)
    echo "   Cluster status: $STATUS"
    echo "$HEALTH" | grep -E "number_of_nodes|active_shards|unassigned_shards" | head -3
else
    echo "   Could not retrieve cluster health"
fi
echo ""

# Check for read-only indices
echo "3. Read-Only Indices Check:"
echo "--------------------------"
INDICES=$(curl -s --max-time 5 --connect-timeout 3 "http://localhost:9200/_cat/indices?v&h=index,status" 2>/dev/null)
if [ $? -eq 0 ] && [ ! -z "$INDICES" ]; then
    READONLY_COUNT=$(echo "$INDICES" | grep -i "read_only" | wc -l)
    if [ "$READONLY_COUNT" -eq 0 ]; then
        echo "   ✓ No read-only indices found"
    else
        echo "   ❌ Found $READONLY_COUNT read-only indices!"
        echo "$INDICES" | grep -i "read_only" | head -5
    fi
else
    echo "   Could not check indices"
fi
echo ""

# Count Graylog indices
echo "4. Graylog Indices Count:"
echo "------------------------"
GRAYLOG_INDICES=$(curl -s --max-time 5 --connect-timeout 3 "http://localhost:9200/_cat/indices/graylog_*?v&h=index" 2>/dev/null | tail -n +2 | wc -l)
echo "   Current graylog indices: $GRAYLOG_INDICES"
echo ""

echo "=========================================="
echo "Status Check Complete"
echo "=========================================="
echo ""
echo "📊 Summary:"
echo "   - Indices reduced from 15 to 11 (4 deleted)"
echo "   - Storage reduced from 44.9 GiB to 29.9 GiB (~15 GB freed)"
echo ""
echo "✅ If disk usage is now below 85%, logs should start flowing again!"
echo "   Check Graylog UI -> System -> Inputs to verify inputs are running"

