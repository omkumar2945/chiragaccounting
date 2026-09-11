[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('android-apk', 'android-aab', 'ios', 'web')]
    [string]$Target,
    [string]$EnvironmentFile = '.env.release',
    [string]$BuildName,
    [int]$BuildNumber
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $EnvironmentFile)) {
    throw "Release configuration '$EnvironmentFile' was not found. Copy .env.release.example to .env.release and set its values."
}

$configuration = @{}
foreach ($line in Get-Content -LiteralPath $EnvironmentFile) {
    $trimmed = $line.Trim()
    if (-not $trimmed -and -not $trimmed.StartsWith('#')) { continue }
    $parts = $trimmed -split '=', 2
    if ($parts.Count -eq 2) {
        $configuration[$parts[0].Trim()] = $parts[1].Trim()
    }
}

$required = @(
    'API_BASE_URL',
    'FIREBASE_API_KEY',
    'FIREBASE_APP_ID',
    'FIREBASE_MESSAGING_SENDER_ID',
    'FIREBASE_PROJECT_ID'
)
$missing = $required | Where-Object { [string]::IsNullOrWhiteSpace($configuration[$_]) }
if ($missing) {
    throw "Missing required release values: $($missing -join ', ')"
}

$dartDefines = $configuration.GetEnumerator() |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_.Value) } |
    ForEach-Object { "--dart-define=$($_.Key)=$($_.Value)" }
$buildOptions = @('--release') + $dartDefines
if ($BuildName) { $buildOptions += "--build-name=$BuildName" }
if ($PSBoundParameters.ContainsKey('BuildNumber')) { $buildOptions += "--build-number=$BuildNumber" }

switch ($Target) {
    'android-apk' { flutter build apk @buildOptions }
    'android-aab' { flutter build appbundle @buildOptions }
    'ios' {
        if (-not $IsMacOS) { throw 'iOS builds require macOS with Xcode installed.' }
        flutter build ipa @buildOptions
    }
    'web' { flutter build web @buildOptions }
}

if ($LASTEXITCODE -ne 0) {
    throw "Flutter $Target release build failed."
}