# Fix OpenSearch Read-Only Indices
# This script checks and fixes indices that are in read-only mode due to disk space issues

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "OpenSearch Read-Only Indices Fix" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check OpenSearch health
Write-Host "1. Checking OpenSearch cluster health..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "http://localhost:9200/_cluster/health?pretty" -Method Get -TimeoutSec 5
    Write-Host "Cluster Status: $($health.status)" -ForegroundColor $(if ($health.status -eq "green") { "Green" } else { "Yellow" })
    Write-Host "Active Shards: $($health.active_shards)" -ForegroundColor Green
    Write-Host "Relocating Shards: $($health.relocating_shards)" -ForegroundColor Yellow
    Write-Host "Initializing Shards: $($health.initializing_shards)" -ForegroundColor Yellow
    Write-Host "Unassigned Shards: $($health.unassigned_shards)" -ForegroundColor $(if ($health.unassigned_shards -gt 0) { "Red" } else { "Green" })
} catch {
    Write-Host "ERROR: Cannot connect to OpenSearch at http://localhost:9200" -ForegroundColor Red
    Write-Host "Make sure OpenSearch container is running: docker ps | findstr opensearch" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# Check disk usage
Write-Host "2. Checking disk usage per index..." -ForegroundColor Yellow
try {
    $allocation = Invoke-RestMethod -Uri "http://localhost:9200/_cat/allocation?v" -Method Get -TimeoutSec 5
    Write-Host $allocation
} catch {
    Write-Host "Could not retrieve disk allocation info" -ForegroundColor Yellow
}
Write-Host ""

# Check indices status
Write-Host "3. Checking indices status..." -ForegroundColor Yellow
try {
    $indicesRaw = Invoke-RestMethod -Uri "http://localhost:9200/_cat/indices?v&h=index,status,pri.store.size,health" -Method Get -TimeoutSec 5
    $indices = $indicesRaw -split "`n" | Where-Object { $_ -match "graylog" } | ForEach-Object {
        $parts = $_ -split "\s+"
        [PSCustomObject]@{
            Index = $parts[0]
            Status = $parts[1]
            Size = $parts[2]
            Health = $parts[3]
        }
    }
    
    $readOnlyIndices = $indices | Where-Object { $_.Status -like "*read_only*" }
    
    if ($readOnlyIndices) {
        Write-Host "WARNING: Found $($readOnlyIndices.Count) indices in read-only mode!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Read-only indices:" -ForegroundColor Yellow
        $readOnlyIndices | Format-Table -AutoSize
        
        Write-Host ""
        Write-Host "4. Attempting to remove read-only setting..." -ForegroundColor Yellow
        
        foreach ($idx in $readOnlyIndices) {
            try {
                $body = @{
                    index = @{
                        blocks = @{
                            read_only_allow_delete = "false"
                        }
                    }
                } | ConvertTo-Json -Depth 10
                
                $response = Invoke-RestMethod -Uri "http://localhost:9200/$($idx.Index)/_settings" -Method Put -Body $body -ContentType "application/json" -TimeoutSec 10
                Write-Host "✓ Removed read-only from: $($idx.Index)" -ForegroundColor Green
            } catch {
                Write-Host "✗ Failed to remove read-only from: $($idx.Index)" -ForegroundColor Red
                Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        Write-Host ""
        Write-Host "5. Verifying fix..." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        
        $verifyRaw = Invoke-RestMethod -Uri "http://localhost:9200/_cat/indices?v&h=index,status" -Method Get -TimeoutSec 5
        $verify = $verifyRaw -split "`n" | Where-Object { $_ -match "graylog" } | ForEach-Object {
            $parts = $_ -split "\s+"
            [PSCustomObject]@{
                Index = $parts[0]
                Status = $parts[1]
            }
        }
        
        $stillReadOnly = $verify | Where-Object { $_.Status -like "*read_only*" }
        if ($stillReadOnly) {
            Write-Host "WARNING: Some indices are still in read-only mode. You may need to free up disk space first." -ForegroundColor Red
        } else {
            Write-Host "SUCCESS: All indices are now writable!" -ForegroundColor Green
        }
    } else {
        Write-Host "✓ No indices are in read-only mode" -ForegroundColor Green
    }
} catch {
    Write-Host "ERROR: Could not check indices status: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Check disk space on host
Write-Host "6. Checking host disk space..." -ForegroundColor Yellow
$drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 }
foreach ($drive in $drives) {
    $usedPercent = ($drive.Used / ($drive.Used + $drive.Free)) * 100
    $color = if ($usedPercent -gt 90) { "Red" } elseif ($usedPercent -gt 80) { "Yellow" } else { "Green" }
    Write-Host "Drive $($drive.Name): $([math]::Round($usedPercent, 1))% used ($([math]::Round($drive.Used/1GB, 2)) GB / $([math]::Round(($drive.Used+$drive.Free)/1GB, 2)) GB)" -ForegroundColor $color
}
Write-Host ""

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Check Graylog UI: http://localhost:9000 -> System -> Inputs" -ForegroundColor Green
Write-Host "2. Verify logs are flowing again" -ForegroundColor Green
Write-Host "3. Configure index retention to prevent this in the future:" -ForegroundColor Green
Write-Host "   Graylog UI -> System -> Indices -> Edit Index Set -> Set retention policy" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan

