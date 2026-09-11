[CmdletBinding()]
param(
    [string]$Region = 'ap-south-1',
    [string]$Repository = 'chirag-command-center-backend',
    [string]$Cluster,
    [string]$Service,
    [string]$ExecutionRoleArn,
    [string]$TaskRoleArn,
    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $PSScriptRoot 'deployment-settings.json'
}

if (Test-Path $ConfigPath) {
    $deploymentSettings = Get-Content $ConfigPath -Raw | ConvertFrom-Json

    if (-not $PSBoundParameters.ContainsKey('Region') -and $deploymentSettings.Region) {
        $Region = $deploymentSettings.Region
    }
    if (-not $PSBoundParameters.ContainsKey('Repository') -and $deploymentSettings.Repository) {
        $Repository = $deploymentSettings.Repository
    }
    if (-not $PSBoundParameters.ContainsKey('Cluster')) {
        $Cluster = $deploymentSettings.Cluster
    }
    if (-not $PSBoundParameters.ContainsKey('Service')) {
        $Service = $deploymentSettings.Service
    }
    if (-not $PSBoundParameters.ContainsKey('ExecutionRoleArn')) {
        $ExecutionRoleArn = $deploymentSettings.ExecutionRoleArn
    }
    if (-not $PSBoundParameters.ContainsKey('TaskRoleArn')) {
        $TaskRoleArn = $deploymentSettings.TaskRoleArn
    }
} elseif (-not $PSBoundParameters.ContainsKey('Cluster')) {
    throw "Deployment settings not found at '$ConfigPath'. Copy deployment-settings.example.json to deployment-settings.json and fill in the ECS values."
}

foreach ($requiredSetting in @('Cluster', 'Service', 'ExecutionRoleArn', 'TaskRoleArn')) {
    if ([string]::IsNullOrWhiteSpace((Get-Variable -Name $requiredSetting -ValueOnly))) {
        throw "The deployment setting '$requiredSetting' is required."
    }
}

function Require-Command {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "$Name is required to deploy. Install it and retry."
    }
}

Require-Command aws
Require-Command docker

$backendDirectory = Split-Path -Parent $PSScriptRoot
$templatePath = Join-Path $PSScriptRoot 'ecs-task-definition.json'
$accountId = aws sts get-caller-identity --query Account --output text --region $Region
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to authenticate with AWS.'
}

$repositoryUri = "$accountId.dkr.ecr.$Region.amazonaws.com/$Repository"
aws ecr describe-repositories --repository-names $Repository --region $Region *> $null
if ($LASTEXITCODE -ne 0) {
    aws ecr create-repository --repository-name $Repository --region $Region *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to create ECR repository '$Repository'."
    }
}

aws ecr get-login-password --region $Region | docker login --username AWS --password-stdin "$accountId.dkr.ecr.$Region.amazonaws.com"
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to authenticate Docker with Amazon ECR.'
}

Push-Location $backendDirectory
try {
    docker build --tag "$Repository`:latest" .
    if ($LASTEXITCODE -ne 0) {
        throw 'Docker image build failed.'
    }

    docker tag "$Repository`:latest" "$repositoryUri`:latest"
    docker push "$repositoryUri`:latest"
    if ($LASTEXITCODE -ne 0) {
        throw 'Docker image push failed.'
    }
} finally {
    Pop-Location
}

$taskDefinition = (Get-Content $templatePath -Raw).
    Replace('<account-id>', $accountId).
    Replace('<region>', $Region) |
    ConvertFrom-Json
$taskDefinition.executionRoleArn = $ExecutionRoleArn
$taskDefinition.taskRoleArn = $TaskRoleArn
$taskDefinition.containerDefinitions[0].image = "$repositoryUri`:latest"

$temporaryDefinition = New-TemporaryFile
try {
    $taskDefinition | ConvertTo-Json -Depth 20 | Set-Content $temporaryDefinition -NoNewline
    $taskDefinitionArn = aws ecs register-task-definition --cli-input-json "file://$($temporaryDefinition.FullName)" --region $Region --query 'taskDefinition.taskDefinitionArn' --output text
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to register the ECS task definition. Ensure all referenced secrets and IAM roles exist.'
    }

    aws ecs update-service --cluster $Cluster --service $Service --task-definition $taskDefinitionArn --force-new-deployment --region $Region *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to update ECS service '$Service' in cluster '$Cluster'."
    }

    Write-Host "Waiting for ECS service '$Service' to become stable..."
    aws ecs wait services-stable --cluster $Cluster --services $Service --region $Region
    if ($LASTEXITCODE -ne 0) {
        throw "ECS service '$Service' did not become stable. Check the ECS service events and CloudWatch logs."
    }
} finally {
    Remove-Item $temporaryDefinition -ErrorAction SilentlyContinue
}

Write-Host "Deployment complete: $repositoryUri`:latest"