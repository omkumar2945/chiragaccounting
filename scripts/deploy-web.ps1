[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$EnvironmentFile
)

$ErrorActionPreference = 'Stop'

function Require-Command {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "$Name is required to deploy. Install it and retry."
    }
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $PSScriptRoot 'web-deployment-settings.json'
}
if ([string]::IsNullOrWhiteSpace($EnvironmentFile)) {
    $EnvironmentFile = Join-Path $repositoryRoot '.env.release'
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Web deployment settings not found at '$ConfigPath'. Copy web-deployment-settings.example.json to web-deployment-settings.json and fill in the AWS values."
}

$deploymentSettings = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
foreach ($requiredSetting in @('BucketName')) {
    if ([string]::IsNullOrWhiteSpace($deploymentSettings.$requiredSetting)) {
        throw "The web deployment setting '$requiredSetting' is required."
    }
}

$region = if ($deploymentSettings.Region) { $deploymentSettings.Region } else { 'ap-south-1' }
$bucketName = $deploymentSettings.BucketName

Require-Command aws
Require-Command flutter

aws sts get-caller-identity --region $region *> $null
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to authenticate with AWS. Run aws configure or aws sso login and retry.'
}

Push-Location $repositoryRoot
try {
    & (Join-Path $repositoryRoot 'tool') -Target web -EnvironmentFile $EnvironmentFile
    if ($LASTEXITCODE -ne 0) {
        throw 'Flutter web release build failed.'
    }

    aws s3 sync 'build/web' "s3://$bucketName" --delete --region $region
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to upload the web build to S3 bucket '$bucketName'."
    }

    aws s3 cp 'build/web/index.html' "s3://$bucketName/index.html" --cache-control 'no-cache, no-store, must-revalidate' --content-type 'text/html' --region $region
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to update index.html in S3 bucket '$bucketName'."
    }
} finally {
    Pop-Location
}

if ($deploymentSettings.DistributionId) {
    $invalidationId = aws cloudfront create-invalidation --distribution-id $deploymentSettings.DistributionId --paths '/*' --query 'Invalidation.Id' --output text
    if ($LASTEXITCODE -ne 0) {
        throw "Web files were uploaded, but CloudFront invalidation failed for distribution '$($deploymentSettings.DistributionId)'."
    }
    Write-Host "CloudFront invalidation started: $invalidationId"
}

$webAddress = if ($deploymentSettings.WebUrl) { " at $($deploymentSettings.WebUrl)" } else { '' }
Write-Host "Web deployment complete$webAddress"