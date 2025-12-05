#!/bin/bash

# Quick diagnostic script that won't hang
# This version skips potentially slow operations

echo "=========================================="
echo "Graylog Quick Diagnostic Script"
echo "=========================================="
echo ""

# 1. Check disk space (fast)
echo "1. DISK SPACE CHECK:"
echo "-------------------"
df -h | head -5
echo ""

# 2. Check container status (fast)
echo "2. CONTAINER STATUS:"
echo "-------------------"
docker ps --filter "name=graylog" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Docker not responding"
echo ""

# 3. Quick OpenSearch health check (with timeout)
echo "3. OPENSEARCH HEALTH (quick check):"
echo "-----------------------------------"
HEALTH=$(curl -s --max-time 3 --connect-timeout 2 http://localhost:9200/_cluster/health 2>/dev/null)
if [ $? -eq 0 ] && [ ! -z "$HEALTH" ]; then
    echo "$HEALTH" | grep -o '"status":"[^"]*"' | head -1
    echo "$HEALTH" | grep -o '"number_of_data_nodes":[0-9]*' | head -1
else
    echo "⚠️  Cannot connect to OpenSearch (may be down or unresponsive)"
fi
echo ""

# 4. Check for read-only indices (most common issue)
echo "4. CHECKING FOR READ-ONLY INDICES:"
echo "----------------------------------"
INDICES=$(curl -s --max-time 3 --connect-timeout 2 "http://localhost:9200/_cat/indices?v&h=index,status" 2>/dev/null)
if [ $? -eq 0 ] && [ ! -z "$INDICES" ]; then
    READONLY=$(echo "$INDICES" | grep -i "read_only" | wc -l)
    if [ "$READONLY" -gt 0 ]; then
        echo "⚠️  WARNING: Found $READONLY indices in read-only mode!"
        echo "$INDICES" | grep -i "read_only" | head -5
        echo ""
        echo "This is likely the cause of logs not coming in!"
        echo "Run: ./fix_readonly_indices.ps1 (or fix_readonly_indices.sh) to fix"
    else
        echo "✓ No read-only indices found"
    fi
else
    echo "⚠️  Could not check indices (OpenSearch may be down)"
fi
echo ""

# 5. Check recent errors in Graylog logs
echo "5. RECENT ERRORS IN GRAYLOG LOGS:"
echo "---------------------------------"
docker logs --tail 20 graylog-server 2>&1 | grep -i "error\|exception\|failed\|read-only\|readonly" | tail -5 || echo "No recent errors found or container not accessible"
echo ""

# 6. Check recent errors in OpenSearch logs
echo "6. RECENT ERRORS IN OPENSEARCH LOGS:"
echo "------------------------------------"
docker logs --tail 20 graylog-opensearch 2>&1 | grep -i "error\|exception\|failed\|disk\|space\|watermark" | tail -5 || echo "No recent errors found or container not accessible"
echo ""

echo "=========================================="
echo "Quick Diagnostic Complete"
echo "=========================================="
echo ""
echo "If you see read-only indices above, that's likely the problem!"
echo "Next steps:"
echo "1. Check disk space: df -h"
echo "2. If disk is full, free up space or delete old indices"
echo "3. Run fix script: ./fix_readonly_indices.sh (or .ps1 on Windows)"
echo "4. Check Graylog UI: http://localhost:9000 -> System -> Inputs"

