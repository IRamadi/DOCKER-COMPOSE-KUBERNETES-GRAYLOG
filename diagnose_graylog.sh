#!/bin/bash

echo "=========================================="
echo "Graylog Diagnostic Script"
echo "=========================================="
echo ""

# 1. Check disk space
echo "1. DISK SPACE CHECK:"
echo "-------------------"
df -h | grep -E "Filesystem|/$|/var/lib/docker"
echo ""

# 2. Check Docker volume sizes
echo "2. DOCKER VOLUME SIZES:"
echo "----------------------"
docker system df -v | grep -E "VOLUME NAME|graylog|mongodb|opensearch"
echo ""

# 3. Check specific volume sizes
echo "3. SPECIFIC VOLUME SIZES:"
echo "------------------------"
for vol in graylog-mongodb_data graylog-opensearch_data graylog-graylog_data; do
    echo "Checking volume: $vol"
    docker volume inspect $vol 2>/dev/null | grep -E "Mountpoint|Name" || echo "Volume not found: $vol"
done
echo ""

# 4. Check container status
echo "4. CONTAINER STATUS:"
echo "-------------------"
docker ps --filter "name=graylog" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# 5. Check OpenSearch health
echo "5. OPENSEARCH HEALTH:"
echo "--------------------"
curl -s http://localhost:9200/_cluster/health?pretty 2>/dev/null || echo "Cannot connect to OpenSearch"
echo ""

# 6. Check OpenSearch disk usage
echo "6. OPENSEARCH DISK USAGE:"
echo "------------------------"
curl -s http://localhost:9200/_cat/allocation?v 2>/dev/null || echo "Cannot connect to OpenSearch"
echo ""

# 7. Check OpenSearch indices
echo "7. OPENSEARCH INDICES:"
echo "---------------------"
curl -s http://localhost:9200/_cat/indices?v 2>/dev/null | head -20 || echo "Cannot connect to OpenSearch"
echo ""

# 8. Check Graylog container logs (last 50 lines)
echo "8. GRAYLOG SERVER LOGS (last 50 lines):"
echo "---------------------------------------"
docker logs --tail 50 graylog-server 2>&1 | tail -50
echo ""

# 9. Check OpenSearch container logs (last 30 lines)
echo "9. OPENSEARCH LOGS (last 30 lines):"
echo "-----------------------------------"
docker logs --tail 30 graylog-opensearch 2>&1 | tail -30
echo ""

# 10. Check MongoDB container logs (last 30 lines)
echo "10. MONGODB LOGS (last 30 lines):"
echo "--------------------------------"
docker logs --tail 30 graylog-mongodb 2>&1 | tail -30
echo ""

# 11. Check if Graylog is receiving data
echo "11. GRAYLOG INPUT STATUS:"
echo "------------------------"
echo "Check Graylog web UI at http://localhost:9000 -> System -> Inputs"
echo ""

# 12. Check for disk space issues in containers
echo "12. CONTAINER DISK USAGE:"
echo "------------------------"
docker exec graylog-opensearch df -h /usr/share/opensearch/data 2>/dev/null || echo "Cannot check OpenSearch disk usage"
docker exec graylog-server df -h /usr/share/graylog/data 2>/dev/null || echo "Cannot check Graylog disk usage"
echo ""

echo "=========================================="
echo "Diagnostic Complete"
echo "=========================================="

