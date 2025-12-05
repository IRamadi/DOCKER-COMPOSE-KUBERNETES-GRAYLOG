# Graylog Log Ingestion Stopped - Quick Diagnostic Guide

## Immediate Checks (Run these first)

### 1. Check Disk Space
```powershell
# Check overall disk space
Get-PSDrive -PSProvider FileSystem

# Check Docker volume sizes
docker system df -v

# Check specific volume locations
docker volume inspect graylog-opensearch_data
docker volume inspect graylog-graylog_data
docker volume inspect graylog-mongodb_data
```

### 2. Check OpenSearch Health
```powershell
# Check cluster health
Invoke-RestMethod -Uri "http://localhost:9200/_cluster/health?pretty"

# Check disk usage per index
Invoke-RestMethod -Uri "http://localhost:9200/_cat/allocation?v"

# List all indices and their sizes
Invoke-RestMethod -Uri "http://localhost:9200/_cat/indices?v&s=store.size:desc"
```

### 3. Check OpenSearch for Read-Only Mode
```powershell
# Check if indices are in read-only mode (common when disk is >90% full)
Invoke-RestMethod -Uri "http://localhost:9200/_cat/indices?v&h=index,status,pri.store.size"
```

**If you see `read_only_allow_delete` in the status, that's your problem!**

### 4. Check Graylog Container Logs
```powershell
# Check for errors in Graylog logs
docker logs --tail 100 graylog-server | Select-String -Pattern "error|ERROR|exception|Exception|failed|Failed|read-only|readonly"

# Check recent logs
docker logs --tail 50 graylog-server
```

### 5. Check OpenSearch Container Logs
```powershell
# Check for disk space errors
docker logs --tail 100 graylog-opensearch | Select-String -Pattern "disk|space|read-only|readonly|watermark"
```

### 6. Check Graylog Inputs (via Web UI)
1. Open http://localhost:9000
2. Go to **System → Inputs**
3. Check if your AWS Kinesis input is **Running** (green)
4. If it's stopped, check the error message

### 7. Check AWS Kinesis Stream Status
```powershell
# If you have AWS CLI configured
aws kinesis describe-stream --stream-name LOGS-TEST --region eu-west-1
```

## Common Issues and Solutions

### Issue 1: OpenSearch Indices in Read-Only Mode (Most Common)

**Symptoms:**
- OpenSearch health shows `yellow` or `red`
- Indices have `read_only_allow_delete` status
- Disk usage >90%

**Solution:**
```powershell
# 1. Check current disk usage
$health = Invoke-RestMethod -Uri "http://localhost:9200/_cluster/health?pretty"
Write-Host "Disk Watermark Status: $($health.status)"

# 2. If disk is full, you need to either:
#    a) Free up disk space
#    b) Delete old indices
#    c) Increase disk space

# 3. Temporarily disable read-only mode (if disk space is now available)
# Get all indices in read-only mode
$indices = Invoke-RestMethod -Uri "http://localhost:9200/_cat/indices?v&h=index,status" | ConvertFrom-Csv
$readOnlyIndices = $indices | Where-Object { $_.status -like "*read_only*" }

# Remove read-only setting for each index
foreach ($idx in $readOnlyIndices) {
    $body = @{
        index = @{
            blocks = @{
                read_only_allow_delete = "false"
            }
        }
    } | ConvertTo-Json
    
    Invoke-RestMethod -Uri "http://localhost:9200/$($idx.index)/_settings" -Method Put -Body $body -ContentType "application/json"
    Write-Host "Removed read-only from: $($idx.index)"
}
```

### Issue 2: Disk Space Full

**Solution:**
```powershell
# 1. Check which volumes are using space
docker system df -v

# 2. Clean up old Docker resources (be careful!)
docker system prune -a --volumes

# 3. Delete old Graylog indices (if you have retention configured)
# Go to Graylog UI → System → Indices → Delete old indices
```

### Issue 3: Graylog Input Stopped

**Solution:**
1. Go to Graylog UI → System → Inputs
2. Find your AWS Kinesis input
3. Click "Start" if it's stopped
4. Check error messages in the input details

### Issue 4: OpenSearch Out of Memory

**Solution:**
```powershell
# Check OpenSearch container memory
docker stats graylog-opensearch --no-stream

# If memory is high, you may need to increase it in docker-compose.yml
# Change: OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m
# To: OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx1g
```

## Prevention: Add Index Retention Policy

To prevent this in the future, configure index retention in Graylog:

1. Go to **System → Indices**
2. Click on your index set
3. Configure:
   - **Retention Strategy**: Delete
   - **Max Number of Indices**: 10-20 (depending on your disk space)
   - **Max Size per Index**: 10GB (adjust based on available space)

## Prevention: Add Disk Space Monitoring

Add this to your docker-compose.yml to monitor disk usage:

```yaml
# Add healthcheck to opensearch
opensearch:
  # ... existing config ...
  healthcheck:
    test: ["CMD-SHELL", "curl -f http://localhost:9200/_cluster/health || exit 1"]
    interval: 30s
    timeout: 10s
    retries: 3
```

