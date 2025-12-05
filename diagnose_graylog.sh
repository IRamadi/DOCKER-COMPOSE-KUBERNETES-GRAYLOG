#!/bin/bash

# Check if timeout command exists, if not use a workaround
if ! command -v timeout &> /dev/null; then
    # Define a simple timeout function if timeout doesn't exist
    timeout() {
        local duration=$1
        shift
        (
            "$@" &
            local pid=$!
            sleep $duration
            kill $pid 2>/dev/null
        ) &
        wait $! 2>/dev/null
    }
fi

echo "=========================================="
echo "Graylog Diagnostic Script"
echo "=========================================="
echo ""

# 1. Skip disk space check (often hangs in Docker environments)
echo "1. DISK SPACE CHECK:"
echo "-------------------"
echo "⚠️  Skipped to prevent hanging (run 'df -h' manually if needed)"
echo ""

# 2. Check Docker volume sizes (simplified to prevent hanging)
echo "2. DOCKER VOLUME SIZES:"
echo "----------------------"
(timeout 10 docker system df 2>/dev/null || docker system df 2>/dev/null) | head -20 || echo "Could not retrieve Docker volume information"
echo ""

# 3. Check specific volume sizes
echo "3. SPECIFIC VOLUME SIZES:"
echo "------------------------"
# List all volumes and filter for Graylog-related ones
echo "Graylog-related volumes:"
timeout 10 docker volume ls 2>/dev/null | grep -E "mongodb|opensearch|graylog" | head -10 || echo "Could not list volumes"
echo ""

# 4. Check container status
echo "4. CONTAINER STATUS:"
echo "-------------------"
docker ps --filter "name=graylog" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# 5. Check OpenSearch health
echo "5. OPENSEARCH HEALTH:"
echo "--------------------"
curl -s --max-time 5 --connect-timeout 3 http://localhost:9200/_cluster/health?pretty 2>/dev/null || echo "Cannot connect to OpenSearch (timeout or connection refused)"
echo ""

# 6. Check OpenSearch disk usage
echo "6. OPENSEARCH DISK USAGE:"
echo "------------------------"
curl -s --max-time 5 --connect-timeout 3 http://localhost:9200/_cat/allocation?v 2>/dev/null || echo "Cannot connect to OpenSearch (timeout or connection refused)"
echo ""

# 7. Check OpenSearch indices (and check for read-only status - MOST COMMON ISSUE)
echo "7. OPENSEARCH INDICES:"
echo "---------------------"
INDICES=$(curl -s --max-time 5 --connect-timeout 3 http://localhost:9200/_cat/indices?v 2>/dev/null)
if [ $? -eq 0 ] && [ ! -z "$INDICES" ]; then
    echo "$INDICES" | head -20
    echo ""
    # Check for read-only indices
    READONLY=$(echo "$INDICES" | grep -i "read_only" | wc -l)
    if [ "$READONLY" -gt 0 ]; then
        echo "❌ WARNING: Found $READONLY indices in read-only mode!"
        echo "This is likely why logs stopped coming in!"
        echo "Read-only indices:"
        echo "$INDICES" | grep -i "read_only" | head -10
    fi
else
    echo "Cannot connect to OpenSearch (timeout or connection refused)"
fi
echo ""

# 8. Check Graylog container logs (last 50 lines)
echo "8. GRAYLOG SERVER LOGS (last 50 lines):"
echo "---------------------------------------"
timeout 15 docker logs --tail 50 graylog-server 2>&1 | tail -50 || echo "Could not retrieve Graylog logs"
echo ""

# 9. Check OpenSearch container logs (last 30 lines)
echo "9. OPENSEARCH LOGS (last 30 lines):"
echo "-----------------------------------"
timeout 15 docker logs --tail 30 graylog-opensearch 2>&1 | tail -30 || echo "Could not retrieve OpenSearch logs"
echo ""

# 10. Check MongoDB container logs (last 30 lines)
echo "10. MONGODB LOGS (last 30 lines):"
echo "--------------------------------"
timeout 15 docker logs --tail 30 graylog-mongodb 2>&1 | tail -30 || echo "Could not retrieve MongoDB logs"
echo ""

# 11. Check if Graylog is receiving data
echo "11. GRAYLOG INPUT STATUS:"
echo "------------------------"
echo "Check Graylog web UI at http://localhost:9000 -> System -> Inputs"
echo ""

# 12. Check for disk space issues in containers
echo "12. CONTAINER DISK USAGE:"
echo "------------------------"
timeout 10 docker exec graylog-opensearch df -h /usr/share/opensearch/data 2>/dev/null || echo "Cannot check OpenSearch disk usage (container may be unresponsive)"
timeout 10 docker exec graylog-server df -h /usr/share/graylog/data 2>/dev/null || echo "Cannot check Graylog disk usage (container may be unresponsive)"
echo ""

echo "=========================================="
echo "Diagnostic Complete"
echo "=========================================="
echo ""
echo "🔍 If you see read-only indices above, that's likely the problem!"
echo "   Solution: Free up disk space and remove read-only setting"
echo "   Use: ./fix_readonly_indices.sh to fix read-only indices"
echo ""
echo "📋 Other things to check:"
echo "   - Graylog UI: http://localhost:9000 -> System -> Inputs"
echo "   - System -> Indices for index rotation issues"
echo "   - Check disk space manually: df -h"

