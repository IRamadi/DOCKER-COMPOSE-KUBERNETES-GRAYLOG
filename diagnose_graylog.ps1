# Graylog Diagnostic Script for Windows PowerShell

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Graylog Diagnostic Script" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check disk space
Write-Host "1. DISK SPACE CHECK:" -ForegroundColor Yellow
Write-Host "-------------------" -ForegroundColor Yellow
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 } | Format-Table Name, @{Label="Used(GB)";Expression={[math]::Round($_.Used/1GB,2)}}, @{Label="Free(GB)";Expression={[math]::Round($_.Free/1GB,2)}}, @{Label="Total(GB)";Expression={[math]::Round(($_.Used+$_.Free)/1GB,2)}}
Write-Host ""

# 2. Check Docker volume sizes
Write-Host "2. DOCKER VOLUME SIZES:" -ForegroundColor Yellow
Write-Host "----------------------" -ForegroundColor Yellow
docker system df -v
Write-Host ""

# 3. Check specific volume sizes
Write-Host "3. SPECIFIC VOLUME SIZES:" -ForegroundColor Yellow
Write-Host "------------------------" -ForegroundColor Yellow
$volumes = @("graylog-mongodb_data", "graylog-opensearch_data", "graylog-graylog_data")
foreach ($vol in $volumes) {
    Write-Host "Checking volume: $vol"
    docker volume inspect $vol 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Volume not found: $vol" -ForegroundColor Red
    }
}
Write-Host ""

# 4. Check container status
Write-Host "4. CONTAINER STATUS:" -ForegroundColor Yellow
Write-Host "-------------------" -ForegroundColor Yellow
docker ps --filter "name=graylog" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
Write-Host ""

# 5. Check OpenSearch health
Write-Host "5. OPENSEARCH HEALTH:" -ForegroundColor Yellow
Write-Host "--------------------" -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://localhost:9200/_cluster/health?pretty" -Method Get -TimeoutSec 5
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Cannot connect to OpenSearch: $_" -ForegroundColor Red
}
Write-Host ""

# 6. Check OpenSearch disk usage
Write-Host "6. OPENSEARCH DISK USAGE:" -ForegroundColor Yellow
Write-Host "------------------------" -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://localhost:9200/_cat/allocation?v" -Method Get -TimeoutSec 5
    Write-Host $response
} catch {
    Write-Host "Cannot connect to OpenSearch: $_" -ForegroundColor Red
}
Write-Host ""

# 7. Check OpenSearch indices
Write-Host "7. OPENSEARCH INDICES:" -ForegroundColor Yellow
Write-Host "---------------------" -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://localhost:9200/_cat/indices?v" -Method Get -TimeoutSec 5
    Write-Host $response
} catch {
    Write-Host "Cannot connect to OpenSearch: $_" -ForegroundColor Red
}
Write-Host ""

# 8. Check Graylog container logs (last 50 lines)
Write-Host "8. GRAYLOG SERVER LOGS (last 50 lines):" -ForegroundColor Yellow
Write-Host "---------------------------------------" -ForegroundColor Yellow
docker logs --tail 50 graylog-server 2>&1
Write-Host ""

# 9. Check OpenSearch container logs (last 30 lines)
Write-Host "9. OPENSEARCH LOGS (last 30 lines):" -ForegroundColor Yellow
Write-Host "-----------------------------------" -ForegroundColor Yellow
docker logs --tail 30 graylog-opensearch 2>&1
Write-Host ""

# 10. Check MongoDB container logs (last 30 lines)
Write-Host "10. MONGODB LOGS (last 30 lines):" -ForegroundColor Yellow
Write-Host "--------------------------------" -ForegroundColor Yellow
docker logs --tail 30 graylog-mongodb 2>&1
Write-Host ""

# 11. Check container disk usage
Write-Host "11. CONTAINER DISK USAGE:" -ForegroundColor Yellow
Write-Host "------------------------" -ForegroundColor Yellow
Write-Host "OpenSearch data directory:"
docker exec graylog-opensearch df -h /usr/share/opensearch/data 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Cannot check OpenSearch disk usage" -ForegroundColor Red
}
Write-Host ""
Write-Host "Graylog data directory:"
docker exec graylog-server df -h /usr/share/graylog/data 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Cannot check Graylog disk usage" -ForegroundColor Red
}
Write-Host ""

# 12. Check for errors in logs
Write-Host "12. ERROR SUMMARY:" -ForegroundColor Yellow
Write-Host "-----------------" -ForegroundColor Yellow
Write-Host "Recent errors in Graylog logs:"
docker logs --tail 100 graylog-server 2>&1 | Select-String -Pattern "error|ERROR|exception|Exception|failed|Failed" | Select-Object -Last 10
Write-Host ""

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Diagnostic Complete" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Green
Write-Host "1. Check Graylog web UI at http://localhost:9000 -> System -> Inputs" -ForegroundColor Green
Write-Host "2. Check System -> Nodes for any node issues" -ForegroundColor Green
Write-Host "3. Check System -> Indices for index rotation issues" -ForegroundColor Green

