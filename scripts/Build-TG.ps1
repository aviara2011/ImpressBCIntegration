param(
    [string]$CompilerPath = 'C:\Users\aviara\.vscode\extensions\ms-dynamics-smb.al-18.0.2732683\bin\alc.dll',
    [string]$DotnetPath = '',
    [switch]$IncludeTests
)
$ErrorActionPreference = 'Stop'
$tgRoot = Split-Path -Parent $PSScriptRoot
if (-not $DotnetPath) {
    $DotnetPath = Join-Path ([IO.Path]::GetTempPath()) 'ImpressBCIntegration-build-tools\tg-complete\dotnet\dotnet.exe'
    if (-not (Test-Path -LiteralPath $DotnetPath)) { $DotnetPath = 'dotnet' }
}
$tgManifest = Get-Content -LiteralPath (Join-Path $tgRoot 'app.json') -Raw | ConvertFrom-Json
$tgBuild = Join-Path ([IO.Path]::GetTempPath()) ('ImpressTG-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tgBuild | Out-Null
Copy-Item -LiteralPath (Join-Path $tgRoot 'app.json') -Destination $tgBuild
foreach ($tgFile in Get-ChildItem -LiteralPath (Join-Path $tgRoot '.vscode') -Recurse -File) {
    if ($tgFile.Extension -notin '.al', '.rdlc') { continue }
    $tgRelative = [IO.Path]::GetRelativePath($tgRoot, $tgFile.FullName)
    $tgDestination = Join-Path $tgBuild $tgRelative
    New-Item -ItemType Directory -Path (Split-Path -Parent $tgDestination) -Force | Out-Null
    Copy-Item -LiteralPath $tgFile.FullName -Destination $tgDestination
}
$tgCache = Join-Path $tgRoot '.alpackages'
$tgOutput = Join-Path $tgRoot ('Techstyle_Impress BC Integration_' + $tgManifest.version + '.app')
& $DotnetPath $CompilerPath "/project:$tgBuild" "/packagecachepath:$tgCache" "/out:$tgOutput"
if ($LASTEXITCODE -ne 0) { throw 'Production compilation failed.' }
Write-Output "Production package: $tgOutput"
if ($IncludeTests) {
    $tgTestVersion = '1.0.0.23'
    Copy-Item -LiteralPath $tgOutput -Destination $tgCache -Force
    $tgTests = Join-Path ([IO.Path]::GetTempPath()) ('ImpressTGTests-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tgTests | Out-Null
    $tgTestManifest = [ordered]@{
        id = '4a6acc39-8756-40e2-9a11-2fed344f21a3'
        name = 'Impress T/G Tests'
        publisher = 'Techstyle'
        version = $tgTestVersion
        application = $tgManifest.application
        platform = $tgManifest.platform
        runtime = $tgManifest.runtime
        dependencies = @(@{ id = $tgManifest.id; name = $tgManifest.name; publisher = $tgManifest.publisher; version = $tgManifest.version })
        idRanges = @(@{ from = 80095; to = 80099 })
        preprocessorSymbols = @('TG_TESTS')
        features = @('NoImplicitWith')
    }
    $tgTestManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $tgTests 'app.json') -Encoding utf8
    Copy-Item -Path (Join-Path $tgRoot 'tests\*.al') -Destination $tgTests
    $tgTestOutput = Join-Path $tgRoot ('Techstyle_Impress TG Tests_' + $tgTestVersion + '.app')
    & $DotnetPath $CompilerPath "/project:$tgTests" "/packagecachepath:$tgCache" "/out:$tgTestOutput"
    if ($LASTEXITCODE -ne 0) { throw 'Test compilation failed.' }
    Write-Output "Test package (sandbox only): $tgTestOutput"
}
