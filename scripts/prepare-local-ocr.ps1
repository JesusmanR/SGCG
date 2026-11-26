$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$ocrDirectory = Join-Path $projectRoot '.tools\tesseract'
$tessdataDirectory = Join-Path $ocrDirectory 'tessdata'
$licensesDirectory = Join-Path $ocrDirectory 'licenses'

$tesseractCommand = Get-Command tesseract.exe -ErrorAction SilentlyContinue
$installCandidates = @(
    (Join-Path $env:ProgramFiles 'Tesseract-OCR'),
    $(if ($tesseractCommand) { Split-Path -Parent $tesseractCommand.Source })
)
$installDirectory = $installCandidates |
    Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $_ 'tesseract.exe')) } |
    Select-Object -First 1

if (-not $installDirectory) {
    throw 'Instala Tesseract OCR 5 para Windows y vuelve a ejecutar este script.'
}

$versionOutput = & (Join-Path $installDirectory 'tesseract.exe') --version 2>&1 | Select-Object -First 1
if ($versionOutput -notmatch '^tesseract 5\.') {
    throw "Se requiere Tesseract 5. Versión detectada: $versionOutput"
}

New-Item -ItemType Directory -Path $ocrDirectory, $tessdataDirectory, $licensesDirectory -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $installDirectory 'tesseract.exe') -Destination $ocrDirectory -Force
Get-ChildItem -LiteralPath $installDirectory -Filter '*.dll' -File |
    Copy-Item -Destination $ocrDirectory -Force

$englishModel = Join-Path $installDirectory 'tessdata\eng.traineddata'
$orientationModel = Join-Path $installDirectory 'tessdata\osd.traineddata'
foreach ($optionalModel in @($englishModel, $orientationModel)) {
    if (Test-Path -LiteralPath $optionalModel) {
        Copy-Item -LiteralPath $optionalModel -Destination $tessdataDirectory -Force
    }
}

$spanishModelUrl = 'https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/4.1.0/spa.traineddata'
Invoke-WebRequest -Uri $spanishModelUrl -OutFile (Join-Path $tessdataDirectory 'spa.traineddata')

$licensePath = Join-Path $installDirectory 'doc\LICENSE'
$authorsPath = Join-Path $installDirectory 'doc\AUTHORS'
if (Test-Path -LiteralPath $licensePath) {
    Copy-Item -LiteralPath $licensePath -Destination (Join-Path $licensesDirectory 'Tesseract-LICENSE.txt') -Force
}
if (Test-Path -LiteralPath $authorsPath) {
    Copy-Item -LiteralPath $authorsPath -Destination (Join-Path $licensesDirectory 'Tesseract-AUTHORS.txt') -Force
}

if (-not (Test-Path -LiteralPath (Join-Path $licensesDirectory 'Tesseract-LICENSE.txt'))) {
    throw 'No se encontró la licencia de Tesseract en la instalación.'
}

Write-Host "OCR local preparado desde $installDirectory"
Write-Host "Modelo español guardado en $(Join-Path $tessdataDirectory 'spa.traineddata')"
