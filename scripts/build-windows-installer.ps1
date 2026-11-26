$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$appDirectory = Join-Path $projectRoot 'app'
$scriptPath = Join-Path $projectRoot 'installer\control_gastos.iss'
$releaseDirectory = Join-Path $appDirectory 'build\windows\x64\runner\Release'
$ocrSourceDirectory = Join-Path $projectRoot '.tools\tesseract'
$ocrReleaseDirectory = Join-Path $releaseDirectory 'ocr'
$installerOutput = Join-Path $projectRoot 'dist\installer'

$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if ($null -eq $flutter) {
    $bundledFlutter = Join-Path $projectRoot '.tools\flutter\bin\flutter.bat'
    if (Test-Path -LiteralPath $bundledFlutter) {
        $flutterPath = $bundledFlutter
    } else {
        throw 'No se encontró Flutter. Instala Flutter o coloca el SDK en .tools\flutter.'
    }
} else {
    $flutterPath = $flutter.Source
}

$compiler = Get-Command ISCC.exe -ErrorAction SilentlyContinue
if ($null -eq $compiler) {
    $compilerCandidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 7\ISCC.exe'),
        (Join-Path $env:ProgramFiles 'Inno Setup 7\ISCC.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 7\ISCC.exe')
    )
    $compilerPath = $compilerCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
} else {
    $compilerPath = $compiler.Source
}
if ([string]::IsNullOrWhiteSpace($compilerPath)) {
    throw 'No se encontró Inno Setup 7. Instálalo y vuelve a ejecutar este script.'
}

Push-Location $appDirectory
try {
    & $flutterPath build windows --release
    if ($LASTEXITCODE -ne 0) { throw 'Falló la compilación de Windows.' }
} finally {
    Pop-Location
}

if (-not (Test-Path -LiteralPath (Join-Path $releaseDirectory 'control_gastos.exe'))) {
    throw 'No se encontró la compilación Windows en la carpeta Release.'
}

$tesseractExecutable = Join-Path $ocrSourceDirectory 'tesseract.exe'
$spanishModel = Join-Path $ocrSourceDirectory 'tessdata\spa.traineddata'
if (-not (Test-Path -LiteralPath $tesseractExecutable) -or
    -not (Test-Path -LiteralPath $spanishModel)) {
    throw 'No se encontró Tesseract con el modelo de español en .tools\tesseract.'
}

New-Item -ItemType Directory -Path $ocrReleaseDirectory -Force | Out-Null
Copy-Item -LiteralPath $tesseractExecutable -Destination $ocrReleaseDirectory -Force
Get-ChildItem -LiteralPath $ocrSourceDirectory -Filter '*.dll' -File |
    Copy-Item -Destination $ocrReleaseDirectory -Force
$releaseTessdata = Join-Path $ocrReleaseDirectory 'tessdata'
New-Item -ItemType Directory -Path $releaseTessdata -Force | Out-Null
Copy-Item -LiteralPath $spanishModel -Destination $releaseTessdata -Force
foreach ($optionalModel in @('eng.traineddata', 'osd.traineddata')) {
    $modelPath = Join-Path $ocrSourceDirectory "tessdata\$optionalModel"
    if (Test-Path -LiteralPath $modelPath) {
        Copy-Item -LiteralPath $modelPath -Destination $releaseTessdata -Force
    }
}
$licenseSourceDirectory = Join-Path $ocrSourceDirectory 'licenses'
if (-not (Test-Path -LiteralPath (Join-Path $licenseSourceDirectory 'Tesseract-LICENSE.txt'))) {
    throw 'Falta la licencia de Tesseract en .tools\tesseract\licenses.'
}
$releaseLicenseDirectory = Join-Path $ocrReleaseDirectory 'licenses'
New-Item -ItemType Directory -Path $releaseLicenseDirectory -Force | Out-Null
Copy-Item -Path (Join-Path $licenseSourceDirectory '*') -Destination $releaseLicenseDirectory -Force

New-Item -ItemType Directory -Path $installerOutput -Force | Out-Null
& $compilerPath $scriptPath "-O$installerOutput"
if ($LASTEXITCODE -ne 0) { throw 'Falló la creación del instalador.' }

Get-ChildItem -LiteralPath $installerOutput -Filter '*.exe' |
    Select-Object FullName, Length
