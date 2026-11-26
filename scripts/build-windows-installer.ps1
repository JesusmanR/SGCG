$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$appDirectory = Join-Path $projectRoot 'app'
$scriptPath = Join-Path $projectRoot 'installer\control_gastos.iss'
$releaseDirectory = Join-Path $appDirectory 'build\windows\x64\runner\Release'
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

New-Item -ItemType Directory -Path $installerOutput -Force | Out-Null
& $compilerPath $scriptPath "-O$installerOutput"
if ($LASTEXITCODE -ne 0) { throw 'Falló la creación del instalador.' }

Get-ChildItem -LiteralPath $installerOutput -Filter '*.exe' |
    Select-Object FullName, Length
