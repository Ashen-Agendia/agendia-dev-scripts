# Script PowerShell para compilar/instalar dependencias de todos los microservicios

Write-Host "📦 Instalando dependencias de todos los microservicios..." -ForegroundColor Cyan
Write-Host "" 

$SCRIPT_DIR  = Split-Path -Parent $MyInvocation.MyCommand.Path
$SCRIPTS_ROOT = Split-Path -Parent $SCRIPT_DIR
$ROOT_DIR    = Split-Path -Parent $SCRIPTS_ROOT

$MS_DIRS = @(
  "agendia-template-ms",
  "agendia-ms-agenda",
  "agendia-ms-clients",
  "agendia-ms-notifications",
  "agendia-ms-organization",
  "agendia-ms-platform",
  "agendia-ms-sales"
)

$INSTALLED = 0
$SKIPPED   = 0
$FAILED    = 0

# Localizar sbt si está instalado
$sbtPath = (Get-Command sbt.bat -ErrorAction SilentlyContinue)?.Source
if (-not $sbtPath) {
  $sbtPath = (Get-Command sbt -ErrorAction SilentlyContinue)?.Source
}

if (-not $sbtPath) {
  Write-Host "❌ No se encontró 'sbt' en el PATH." -ForegroundColor Red
  Write-Host ""
  Write-Host "Por favor instala sbt primero:" -ForegroundColor Yellow
  Write-Host "  - En Linux/Mac: ./install-system-deps.sh" -ForegroundColor Yellow
  Write-Host "  - En Windows: https://www.scala-sbt.org/download.html" -ForegroundColor Yellow
  Write-Host ""
  exit 1
}

foreach ($dirName in $MS_DIRS) {
  $dirPath   = Join-Path $ROOT_DIR $dirName
  $buildFile = Join-Path $dirPath "build.sbt"

  if ((Test-Path $dirPath) -and (Test-Path $buildFile)) {
    Write-Host "" 
    Write-Host "📦 Ejecutando 'sbt compile' en $dirName..." -ForegroundColor Yellow

    Push-Location $dirPath

    try {
      & $sbtPath compile
      if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ $dirName compilado / dependencias descargadas correctamente" -ForegroundColor Green
        $INSTALLED++
      } else {
        Write-Host "❌ Error ejecutando 'sbt compile' en $dirName (exit code $LASTEXITCODE)" -ForegroundColor Red
        $FAILED++
      }
    } catch {
      Write-Host "❌ Excepción ejecutando 'sbt compile' en ${dirName}: $_" -ForegroundColor Red
      $FAILED++
    }

    Pop-Location
  } else {
    Write-Host "⏭️  Saltando $dirName (no existe o no tiene build.sbt)" -ForegroundColor Gray
    $SKIPPED++
  }
}

Write-Host "" 
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📊 Resumen:" -ForegroundColor Cyan
Write-Host "   ✅ Procesados (compile OK): $INSTALLED" -ForegroundColor Green
Write-Host "   ⏭️  Saltados: $SKIPPED" -ForegroundColor Gray
Write-Host "   ❌ Fallidos: $FAILED" -ForegroundColor Red
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

if ($FAILED -eq 0) {
  Write-Host "🎉 Instalación/compilación completada sin errores!" -ForegroundColor Green
  exit 0
} else {
  Write-Host "⚠️  Algunas compilaciones fallaron. Revisa la salida anterior." -ForegroundColor Yellow
  exit 1
}
