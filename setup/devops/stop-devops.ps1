Write-Host "🛑 Deteniendo DevOps Dashboard..." -ForegroundColor Yellow
Write-Host ""

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$SCRIPTS_ROOT = Split-Path -Parent (Split-Path -Parent $SCRIPT_DIR)
$PIDS_FILE = Join-Path $SCRIPTS_ROOT ".devops-pids"

$STOPPED = 0
$NOT_FOUND = 0

if (-not (Test-Path $PIDS_FILE)) {
    Write-Host "⚠️  No se encontró archivo de PIDs (.devops-pids)" -ForegroundColor Yellow
    Write-Host "   Intentando detener procesos en los puertos comunes (6001, 6002)..." -ForegroundColor Yellow
    Write-Host ""
    
    $ports = @(6001, 6002)
    
    foreach ($port in $ports) {
        try {
            $connections = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique
            
            foreach ($processId in $connections) {
                $proc = Get-Process -Id $processId -ErrorAction SilentlyContinue
                if ($proc) {
                    Write-Host "   🛑 Deteniendo proceso en puerto $port (PID: $processId)..." -ForegroundColor Yellow
                    Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
                    if ($?) {
                        Write-Host "      ✅ Proceso detenido" -ForegroundColor Green
                        $STOPPED++
                    }
                }
            }
        } catch {
        }
    }
    
    if ($STOPPED -eq 0) {
        Write-Host "   ℹ️  No se encontraron procesos corriendo en los puertos comunes" -ForegroundColor Gray
    }
} else {
    Write-Host "📋 Leyendo PIDs desde $PIDS_FILE..." -ForegroundColor Cyan
    Write-Host ""
    
    $pids = Get-Content $PIDS_FILE
    
    foreach ($line in $pids) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        
        $parts = $line.Split(':')
        if ($parts.Length -lt 2) { continue }
        
        $processId = $parts[0]
        $service = $parts[1]
        
        try {
            $process = Get-Process -Id $processId -ErrorAction Stop
            Write-Host "   🛑 Deteniendo $service (PID: $processId)..." -ForegroundColor Yellow
            Stop-Process -Id $processId -Force
            Write-Host "      ✅ $service detenido" -ForegroundColor Green
            $STOPPED++
        } catch {
            Write-Host "   ⚠️  $service (PID: $processId) ya no está corriendo" -ForegroundColor Gray
            $NOT_FOUND++
        }
    }
    
    Remove-Item $PIDS_FILE -Force
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📊 Resumen:" -ForegroundColor Cyan
Write-Host "   🛑 Detenidos: $STOPPED" -ForegroundColor Green
if ($NOT_FOUND -gt 0) {
    Write-Host "   ⚠️  No encontrados: $NOT_FOUND" -ForegroundColor Yellow
}
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

if ($STOPPED -gt 0) {
    Write-Host "✅ DevOps Dashboard detenido" -ForegroundColor Green
} else {
    Write-Host "ℹ️  No se encontraron procesos para detener" -ForegroundColor Gray
}

