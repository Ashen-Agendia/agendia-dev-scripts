Write-Host "🚀 Iniciando DevOps Dashboard (backend y frontend)..." -ForegroundColor Cyan
Write-Host ""

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$SCRIPTS_ROOT = Split-Path -Parent (Split-Path -Parent $SCRIPT_DIR)
$ROOT_DIR = Split-Path -Parent $SCRIPTS_ROOT

$DEVOPS_DIR = Join-Path $ROOT_DIR "agendia-devops"
$BACKEND_ROOT = Join-Path $DEVOPS_DIR "backend"
$BACKEND_DIR = Join-Path $BACKEND_ROOT "Agendia.DevOps.Api"
$FRONTEND_DIR = Join-Path $DEVOPS_DIR "frontend"

$PIDS_FILE = Join-Path $SCRIPTS_ROOT ".devops-pids"
$LOGS_ROOT = Join-Path $SCRIPTS_ROOT "logs"
$LOGS_DIR = Join-Path $LOGS_ROOT "devops"

$BACKEND_PORT = 6001
$FRONTEND_PORT = 6002

$STARTED = 0
$FAILED = 0

function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Clear-Port {
    param([int]$Port)
    try {
        $connections = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique
        foreach ($processId in $connections) {
            $proc = Get-Process -Id $processId -ErrorAction SilentlyContinue
            if ($proc) {
                Write-Host "   🛑 Liberando puerto $Port (deteniendo PID: $processId)..." -ForegroundColor Yellow
                Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
                Start-Sleep -Milliseconds 500
            }
        }
        return $true
    } catch {
        return $false
    }
}

function Install-NodeJS {
    Write-Host "⚠️  Node.js no está instalado. Por favor instálalo manualmente:" -ForegroundColor Yellow
    Write-Host "   - Descarga desde: https://nodejs.org/" -ForegroundColor Yellow
    Write-Host "   - O usa winget: winget install OpenJS.NodeJS.LTS" -ForegroundColor Yellow
    return $false
}

function Install-DotNet {
    Write-Host "⚠️  .NET SDK no está instalado. Intentando instalar..." -ForegroundColor Yellow
    
    if (Test-CommandExists "winget") {
        Write-Host "   Instalando .NET SDK 8.0 con winget..." -ForegroundColor Yellow
        winget install Microsoft.DotNet.SDK.8 --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✅ .NET SDK instalado. Por favor reinicia la terminal." -ForegroundColor Green
            return $true
        }
    }
    
    Write-Host "   ❌ No se pudo instalar automáticamente. Instala manualmente:" -ForegroundColor Red
    Write-Host "      - Descarga desde: https://dotnet.microsoft.com/download" -ForegroundColor Yellow
    return $false
}

Write-Host "🔍 Verificando dependencias..." -ForegroundColor Cyan

if (-not (Test-CommandExists "node")) {
    if (-not (Install-NodeJS)) {
        exit 1
    }
    exit 1
} else {
    $nodeVersion = node --version
    $nodeMajorVersion = [int]($nodeVersion -replace 'v(\d+)\..*', '$1')
    if ($nodeMajorVersion -lt 18) {
        Write-Host "❌ Node.js versión $nodeVersion detectada, se requiere 18+" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Node.js $nodeVersion instalado" -ForegroundColor Green
}

if (-not (Test-CommandExists "npm")) {
    Write-Host "❌ npm no está instalado" -ForegroundColor Red
    exit 1
} else {
    $npmVersion = npm --version
    Write-Host "✅ npm $npmVersion instalado" -ForegroundColor Green
}

if (-not (Test-CommandExists "dotnet")) {
    if (-not (Install-DotNet)) {
        exit 1
    }
    exit 1
} else {
    $dotnetVersion = dotnet --version
    $dotnetMajorVersion = [int]($dotnetVersion.Split('.')[0])
    if ($dotnetMajorVersion -lt 8) {
        Write-Host "⚠️  .NET SDK versión $dotnetVersion detectada, se requiere 8.0+" -ForegroundColor Yellow
    } else {
        Write-Host "✅ .NET SDK $dotnetVersion instalado" -ForegroundColor Green
    }
}

Write-Host ""

if (-not (Test-Path $DEVOPS_DIR)) {
    Write-Host "❌ Directorio DevOps no encontrado: $DEVOPS_DIR" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $BACKEND_DIR)) {
    Write-Host "❌ Directorio backend no encontrado: $BACKEND_DIR" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $FRONTEND_DIR)) {
    Write-Host "❌ Directorio frontend no encontrado: $FRONTEND_DIR" -ForegroundColor Red
    exit 1
}

if (Test-Path $PIDS_FILE) {
    Write-Host "⚠️  Archivo de PIDs existente encontrado. Los procesos anteriores pueden estar corriendo." -ForegroundColor Yellow
    Write-Host "   Intentando detener procesos anteriores..." -ForegroundColor Yellow
    
    $pids = Get-Content $PIDS_FILE -ErrorAction SilentlyContinue
    foreach ($line in $pids) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $parts = $line.Split(':')
        if ($parts.Length -lt 2) { continue }
        $processId = $parts[0]
        try {
            $process = Get-Process -Id $processId -ErrorAction Stop
            Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
        } catch {
        }
    }
    
    Remove-Item $PIDS_FILE -Force -ErrorAction SilentlyContinue
    
    $ports = @($BACKEND_PORT, $FRONTEND_PORT)
    foreach ($port in $ports) {
        try {
            $connections = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique
            foreach ($processId in $connections) {
                Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
            }
        } catch {
        }
    }
    
    Start-Sleep -Seconds 1
}

if (-not (Test-Path $LOGS_ROOT)) {
    New-Item -ItemType Directory -Path $LOGS_ROOT -Force | Out-Null
}
if (-not (Test-Path $LOGS_DIR)) {
    New-Item -ItemType Directory -Path $LOGS_DIR -Force | Out-Null
}

Write-Host "📦 Iniciando backend..." -ForegroundColor Yellow

Clear-Port -Port $BACKEND_PORT | Out-Null

Push-Location $BACKEND_DIR

if (-not (Test-Path (Join-Path $BACKEND_ROOT ".env"))) {
    Write-Host "   ⚠️  .env no encontrado en $BACKEND_ROOT" -ForegroundColor Yellow
    Write-Host "   Por favor crea el archivo .env en el directorio backend" -ForegroundColor Yellow
}

$backendLog = Join-Path $LOGS_DIR "backend.log"
$backendErr = Join-Path $LOGS_DIR "backend.error.log"

if (Test-Path $backendLog) {
    Remove-Item $backendLog -Force -ErrorAction SilentlyContinue
}
if (Test-Path $backendErr) {
    Remove-Item $backendErr -Force -ErrorAction SilentlyContinue
}

dotnet restore 2>&1 | Out-Null
dotnet build 2>&1 | Out-Null

$backendProcess = Start-Process -FilePath "dotnet" -ArgumentList "run", "--urls", "http://localhost:$BACKEND_PORT" -PassThru -WindowStyle Hidden -RedirectStandardOutput $backendLog -RedirectStandardError $backendErr

if ($backendProcess -and -not $backendProcess.HasExited) {
    "$($backendProcess.Id):backend" | Add-Content -Path $PIDS_FILE
    Write-Host "   ✅ Backend iniciado (PID: $($backendProcess.Id), Puerto: $BACKEND_PORT)" -ForegroundColor Green
    $STARTED++
    Start-Sleep -Seconds 3
} else {
    Write-Host "   ❌ Error iniciando backend" -ForegroundColor Red
    $FAILED++
}

Pop-Location

Write-Host "📦 Iniciando frontend..." -ForegroundColor Yellow

Clear-Port -Port $FRONTEND_PORT | Out-Null

$DESIGN_SYSTEM_DIR = Join-Path $ROOT_DIR "agendia-design-system"

if (Test-Path $DESIGN_SYSTEM_DIR) {
    $designSystemDist = Join-Path $DESIGN_SYSTEM_DIR "dist"
    if (-not (Test-Path $designSystemDist)) {
        Write-Host "   🔨 Construyendo design-system..." -ForegroundColor Yellow
        Push-Location $DESIGN_SYSTEM_DIR
        if (Test-Path "node_modules") {
            npm run build
            if ($LASTEXITCODE -ne 0) {
                Write-Host "   ⚠️  Error construyendo design-system, continuando de todas formas..." -ForegroundColor Yellow
            } else {
                Write-Host "   ✅ Design-system construido" -ForegroundColor Green
            }
        } else {
            Write-Host "   📦 Instalando dependencias de design-system..." -ForegroundColor Yellow
            npm install
            if ($LASTEXITCODE -eq 0) {
                npm run build
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "   ✅ Design-system construido" -ForegroundColor Green
                } else {
                    Write-Host "   ⚠️  Error construyendo design-system, continuando de todas formas..." -ForegroundColor Yellow
                }
            } else {
                Write-Host "   ⚠️  Error instalando dependencias de design-system, continuando de todas formas..." -ForegroundColor Yellow
            }
        }
        Pop-Location
    }
}

Push-Location $FRONTEND_DIR

if (-not (Test-Path "node_modules")) {
    Write-Host "   📦 Instalando dependencias de frontend..." -ForegroundColor Yellow
    npm install
    if ($LASTEXITCODE -ne 0) {
        Write-Host "   ❌ Error instalando dependencias" -ForegroundColor Red
        $FAILED++
        Pop-Location
        exit 1
    }
}

if (-not (Test-Path (Join-Path $FRONTEND_DIR ".env"))) {
    Write-Host "   ⚠️  .env no encontrado en $FRONTEND_DIR" -ForegroundColor Yellow
    Write-Host "   Por favor crea el archivo .env en el directorio frontend" -ForegroundColor Yellow
}

$frontendLog = Join-Path $LOGS_DIR "frontend.log"
$frontendErr = Join-Path $LOGS_DIR "frontend.error.log"

if (Test-Path $frontendLog) {
    Remove-Item $frontendLog -Force -ErrorAction SilentlyContinue
    if (Test-Path $frontendLog) {
        Clear-Content $frontendLog -ErrorAction SilentlyContinue
    }
}
if (Test-Path $frontendErr) {
    Remove-Item $frontendErr -Force -ErrorAction SilentlyContinue
    if (Test-Path $frontendErr) {
        Clear-Content $frontendErr -ErrorAction SilentlyContinue
    }
}

$npmCmd = Get-Command npm.cmd -ErrorAction SilentlyContinue
if (-not $npmCmd) {
    $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
}
$npmPath = $npmCmd.Source

$frontendProcess = Start-Process -FilePath $npmPath -ArgumentList "run", "dev" -PassThru -WindowStyle Hidden -RedirectStandardOutput $frontendLog -RedirectStandardError $frontendErr

Start-Sleep -Seconds 4

if ($frontendProcess -and -not $frontendProcess.HasExited) {
    Write-Host "   ⏳ Esperando a que el frontend esté listo..." -ForegroundColor Yellow -NoNewline
    $frontendReady = $false
    $frontendError = $false
    $timeout = 30
    $elapsed = 0
    
    while (-not $frontendReady -and -not $frontendError -and $elapsed -lt $timeout) {
        if (Test-Path $frontendErr) {
            try {
                $errorContent = Get-Content -Path $frontendErr -Tail 5 -ErrorAction SilentlyContinue -Raw
                if ($errorContent -and ($errorContent -match "Port.*is already in use|EADDRINUSE|Error when starting")) {
                    $frontendError = $true
                    Write-Host " ❌" -ForegroundColor Red
                    Write-Host "   Error: Puerto $FRONTEND_PORT en uso" -ForegroundColor Red
                    Write-Host "   Intentando liberar el puerto..." -ForegroundColor Yellow
                    Clear-Port -Port $FRONTEND_PORT | Out-Null
                    Start-Sleep -Seconds 2
                    
                    if ($frontendProcess -and -not $frontendProcess.HasExited) {
                        Stop-Process -Id $frontendProcess.Id -Force -ErrorAction SilentlyContinue
                    }
                    
                    Remove-Item $frontendLog -Force -ErrorAction SilentlyContinue
                    Remove-Item $frontendErr -Force -ErrorAction SilentlyContinue
                    
                    Write-Host "   🔄 Reiniciando frontend..." -ForegroundColor Yellow
                    $frontendProcess = Start-Process -FilePath $npmPath -ArgumentList "run", "dev" -PassThru -WindowStyle Hidden -RedirectStandardOutput $frontendLog -RedirectStandardError $frontendErr
                    Start-Sleep -Seconds 4
                    $elapsed = 0
                    $frontendError = $false
                    continue
                }
            } catch {
            }
        }
        
        if (Test-Path $frontendLog) {
            try {
                $content = Get-Content -Path $frontendLog -Raw -ErrorAction SilentlyContinue
                if ($content) {
                    if ($content -match "Local:\s*http|ready in|Network:\s*http|VITE.*ready|localhost:$FRONTEND_PORT|VITE v\d") {
                        $frontendReady = $true
                    }
                }
            } catch {
            }
        }
        
        if ($frontendProcess.HasExited) {
            $frontendError = $true
            break
        }
        
        if (-not $frontendReady -and -not $frontendError) {
            Start-Sleep -Seconds 1
            $elapsed += 1
        }
    }
    
    if ($frontendReady -and $frontendProcess -and -not $frontendProcess.HasExited) {
        "$($frontendProcess.Id):frontend" | Add-Content -Path $PIDS_FILE
        Write-Host " ✅" -ForegroundColor Green
        Write-Host "   ✅ Frontend iniciado (PID: $($frontendProcess.Id), Puerto: $FRONTEND_PORT)" -ForegroundColor Green
        $STARTED++
    } elseif ($frontendError -or ($frontendProcess -and $frontendProcess.HasExited)) {
        Write-Host " ❌" -ForegroundColor Red
        Write-Host "   ❌ Error iniciando frontend" -ForegroundColor Red
        if (Test-Path $frontendErr) {
            $errorMsg = Get-Content -Path $frontendErr -Tail 3 -ErrorAction SilentlyContinue -Raw
            if ($errorMsg) {
                Write-Host "   Detalles: $errorMsg" -ForegroundColor Gray
            }
        }
        $FAILED++
    } else {
        Write-Host " ⚠️" -ForegroundColor Yellow
        Write-Host "   ⚠️  Frontend iniciado pero no se pudo verificar el estado" -ForegroundColor Yellow
        if ($frontendProcess -and -not $frontendProcess.HasExited) {
            "$($frontendProcess.Id):frontend" | Add-Content -Path $PIDS_FILE
            $STARTED++
        } else {
            $FAILED++
        }
    }
} else {
    Write-Host "   ❌ Error iniciando frontend" -ForegroundColor Red
    if (Test-Path $frontendErr) {
        $errorMsg = Get-Content -Path $frontendErr -Tail 3 -ErrorAction SilentlyContinue -Raw
        if ($errorMsg) {
            Write-Host "   Detalles: $errorMsg" -ForegroundColor Gray
        }
    }
    $FAILED++
}

Pop-Location

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📊 Resumen:" -ForegroundColor Cyan
Write-Host "   ✅ Iniciados: $STARTED" -ForegroundColor Green
if ($FAILED -gt 0) {
    Write-Host "   ❌ Fallidos: $FAILED" -ForegroundColor Red
}
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

if ($STARTED -gt 0) {
    Write-Host ""
    Write-Host "✅ DevOps Dashboard iniciado" -ForegroundColor Green
    Write-Host "   Backend: http://localhost:$BACKEND_PORT" -ForegroundColor Cyan
    Write-Host "   Frontend: http://localhost:$FRONTEND_PORT" -ForegroundColor Cyan
    Write-Host "   Swagger: http://localhost:$BACKEND_PORT/swagger" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "💡 Revisa los logs en logs/devops/ para ver el output de cada servicio." -ForegroundColor Gray
    Write-Host "   Usa .\stop-devops.ps1 para detener los servicios." -ForegroundColor Gray
}

