<#
.SYNOPSIS
    Local Shared Cloud Manager: Multi-Project Desired-State Orchestrator & Extensibility CLI.

.DESCRIPTION
    Manages shared Docker infrastructure, dynamic service unions across active projects,
    catalog service additions, and project credential provisioning.
#>

param(
    [Parameter(Position=0)]
    [ValidateSet("start-project", "stop-project", "register-project", "list-projects", "status", "sync", "stop-all", "add-service", "provision-project", "help")]
    [string]$Command = "status",

    [Parameter(Position=1)]
    [string]$Name,

    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$ExtraArgs
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RegistryPath = Join-Path $ScriptDir "projects.json"
$EnvPath = Join-Path $ScriptDir ".env"
$ComposePath = Join-Path $ScriptDir "compose.yaml"

function Get-Registry {
    if (-not (Test-Path $RegistryPath)) {
        @{
            available_services = @("postgres", "litellm", "ollama", "minio", "qdrant", "langfuse")
            projects = @{}
            active_projects = @()
        } | ConvertTo-Json -Depth 10 | Set-Content $RegistryPath
    }
    return Get-Content $RegistryPath -Raw | ConvertFrom-Json
}

function Save-Registry($registry) {
    $registry | ConvertTo-Json -Depth 10 | Set-Content $RegistryPath
}

function Get-UnionOfActiveServices($registry) {
    $services = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($proj in $registry.active_projects) {
        $projName = [string]$proj
        if ($registry.projects.$projName) {
            foreach ($svc in $registry.projects.$projName) {
                [void]$services.Add($svc)
            }
        }
    }
    return @($services)
}

function Reconcile-Containers($requiredServices) {
    if ($requiredServices.Count -eq 0) {
        Write-Host "`n[Orchestrator] No projects are active. Stopping all shared services..." -ForegroundColor Yellow
        docker compose stop
        return
    }

    $profiles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($svc in $requiredServices) {
        [void]$profiles.Add($svc)
    }

    $profileArgs = @()
    foreach ($p in $profiles) {
        $profileArgs += "--profile"
        $profileArgs += $p
    }

    Write-Host "`n[Orchestrator] Active Services Union ($($profiles.Count)): " -ForegroundColor Cyan -NoNewline
    Write-Host ($profiles -join ", ") -ForegroundColor Green

    Write-Host "[Orchestrator] Reconciling Docker containers to match active projects..." -ForegroundColor Cyan
    & docker compose @profileArgs up -d --remove-orphans

    # Check for idle services that can be stopped
    $allKnown = @("postgres", "litellm", "ollama", "minio", "milvus-standalone", "milvus-etcd", "attu", "langfuse", "redis", "qdrant", "dockge", "prometheus", "grafana")
    $runningServices = @(docker compose ps --services --filter "status=running")
    foreach ($svc in $allKnown) {
        $baseName = $svc -replace "-etcd|-standalone|-db|-postgres", ""
        if (-not $profiles.Contains($baseName) -and -not $profiles.Contains($svc)) {
            if ($runningServices -contains $svc) {
                Write-Host "[Orchestrator] Stopping idle service no longer needed: $svc" -ForegroundColor Yellow
                docker compose stop $svc
            }
        }
    }
}

switch ($Command) {
    "start-project" {
        if (-not $Name) {
            Write-Error "Please specify the project name. Example: .\manage.ps1 start-project doc-agent"
        }
        $reg = Get-Registry
        if (-not $reg.projects.$Name) {
            Write-Host "Project '$Name' is not registered yet." -ForegroundColor Yellow
            $svcs = Read-Host "Enter required services as comma-separated list (e.g. postgres,litellm,minio)"
            $list = @($svcs.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            $reg.projects | Add-Member -MemberType NoteProperty -Name $Name -Value $list -Force
        }

        $active = @($reg.active_projects | ForEach-Object { [string]$_ })
        if (-not ($active -contains $Name)) {
            $reg.active_projects = @($active + $Name)
            Save-Registry $reg
        }

        Write-Host "Activated project '$Name'." -ForegroundColor Green
        Write-Host "Currently Active Projects: $($reg.active_projects -join ', ')" -ForegroundColor Cyan

        $union = Get-UnionOfActiveServices $reg
        Reconcile-Containers $union
    }

    "stop-project" {
        if (-not $Name) {
            Write-Error "Please specify the project name to stop. Example: .\manage.ps1 stop-project doc-agent"
        }
        $reg = Get-Registry
        $active = @($reg.active_projects | ForEach-Object { [string]$_ })
        if ($active -contains $Name) {
            $reg.active_projects = @($active | Where-Object { $_ -ne $Name })
            Save-Registry $reg
            Write-Host "Deactivated project '$Name'." -ForegroundColor Yellow
        } else {
            Write-Host "Project '$Name' is not currently active." -ForegroundColor Gray
        }

        $union = Get-UnionOfActiveServices $reg
        Reconcile-Containers $union
    }

    "stop-all" {
        $reg = Get-Registry
        $reg.active_projects = @()
        Save-Registry $reg
        Write-Host "Deactivated all projects and stopping all shared services..." -ForegroundColor Yellow
        docker compose stop
        Write-Host "All shared services stopped." -ForegroundColor Green
    }

    "sync" {
        $reg = Get-Registry
        $union = Get-UnionOfActiveServices $reg
        Reconcile-Containers $union
    }

    "register-project" {
        if (-not $Name) {
            Write-Error "Please specify project name. Example: .\manage.ps1 register-project -Name my-app -ExtraArgs 'postgres,minio'"
        }
        $reg = Get-Registry
        $services = if ($ExtraArgs) {
            @($ExtraArgs -join ',' -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        } else {
            $inputSvcs = Read-Host "Enter required services as comma-separated list"
            @($inputSvcs.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        }

        $reg.projects | Add-Member -MemberType NoteProperty -Name $Name -Value $services -Force
        Save-Registry $reg
        Write-Host "Successfully registered project '$Name' with services: $($services -join ', ')" -ForegroundColor Green
    }

    "list-projects" {
        $reg = Get-Registry
        Write-Host "`n=== REGISTERED PROJECTS ===" -ForegroundColor Cyan
        foreach ($prop in $reg.projects.PSObject.Properties) {
            $pName = $prop.Name
            $pSvcs = $prop.Value -join ", "
            $isActive = $reg.active_projects -contains $pName
            $badge = if ($isActive) { "[ACTIVE]" } else { "[INACTIVE]" }
            $color = if ($isActive) { "Green" } else { "Gray" }
            Write-Host "  * $pName $badge" -ForegroundColor $color
            Write-Host "    Required Services: $pSvcs" -ForegroundColor DarkGray
        }
        Write-Host "`nActive Projects: $($reg.active_projects -join ', ')" -ForegroundColor Yellow
    }

    "status" {
        $reg = Get-Registry
        Write-Host "`n=== SHARED CLOUD STATUS ===" -ForegroundColor Cyan
        Write-Host "Active Projects: " -NoNewline
        if ($reg.active_projects.Count -eq 0) {
            Write-Host "None (Idle)" -ForegroundColor Gray
        } else {
            Write-Host ($reg.active_projects -join ", ") -ForegroundColor Green
        }

        $union = Get-UnionOfActiveServices $reg
        Write-Host "Required Services Union ($($union.Count)): " -NoNewline
        if ($union.Count -eq 0) {
            Write-Host "None" -ForegroundColor Gray
        } else {
            Write-Host ($union -join ", ") -ForegroundColor Yellow
        }

        Write-Host "`n=== CONTAINER HEALTH ===" -ForegroundColor Cyan
        docker compose ps
    }

    "add-service" {
        if (-not $Name) {
            Write-Error "Please specify the service name to add. Example: .\manage.ps1 add-service redis"
        }
        $catalogPath = Join-Path $ScriptDir "catalog\$Name\compose.yaml"
        $targetCompose = Join-Path $ScriptDir "compose.yaml"

        if (-not (Test-Path $catalogPath)) {
            Write-Host "Service '$Name' not found in catalog. Looking for boilerplate template..." -ForegroundColor Yellow
            $catalogPath = Join-Path $ScriptDir "templates\new-service\compose.yaml"
        }

        # Create host storage directory if required
        $volDir = "D:\docker-images\volumes\${Name}_data"
        if (-not (Test-Path $volDir)) {
            New-Item -ItemType Directory -Path $volDir -Force | Out-Null
            Write-Host "Created storage volume directory at: $volDir" -ForegroundColor Green
        }

        # Update include section in compose.yaml
        $composeContent = Get-Content $targetCompose -Raw
        $relPath = "catalog/$Name/compose.yaml"
        if ($composeContent -match [regex]::Escape($relPath)) {
            Write-Host "Service '$Name' is already included in compose.yaml." -ForegroundColor Yellow
        } else {
            if ($composeContent -match "include:\s*\[\]") {
                $composeContent = $composeContent -replace "include:\s*\[\]", "include:`n  - $relPath"
            } elseif ($composeContent -match "include:") {
                $composeContent = $composeContent -replace "include:", "include:`n  - $relPath"
            } else {
                $composeContent = "include:`n  - $relPath`n`n" + $composeContent
            }
            $composeContent | Set-Content $targetCompose
            Write-Host "Added '$relPath' to include block in compose.yaml." -ForegroundColor Green
        }

        # Update available services in projects.json
        $reg = Get-Registry
        $avail = @($reg.available_services | ForEach-Object { [string]$_ })
        if (-not ($avail -contains $Name)) {
            $reg.available_services = @($avail + $Name)
            Save-Registry $reg
        }

        Write-Host "`n[Success] Service '$Name' is now enabled and available in your Local Cloud!" -ForegroundColor Green
        Write-Host "To link it to a project, run:" -ForegroundColor Cyan
        Write-Host "  .\manage.ps1 register-project -Name <project-name> -ExtraArgs 'postgres,minio,$Name'" -ForegroundColor Gray
    }

    "provision-project" {
        if (-not $Name) {
            Write-Error "Please specify project name. Example: .\manage.ps1 provision-project my-app"
        }
        $safeName = $Name.ToLower() -replace "[^a-z0-9_]", "_"
        $safeHyphen = $Name.ToLower() -replace "[^a-z0-9-]", "-"
        $dbUser = "${safeName}_user"
        $dbPass = [System.Guid]::NewGuid().ToString("N").Substring(0, 16)
        $dbName = "${safeName}_db"
        $bucketName = $safeHyphen

        Write-Host "`n[Provisioner] Provisioning resources for project '$Name'..." -ForegroundColor Cyan

        # 1. PostgreSQL Database & User
        Write-Host "  * Creating PostgreSQL Database '$dbName' and User '$dbUser'..." -ForegroundColor Cyan
        $sql = @"
DO `$`$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$dbUser') THEN
    CREATE USER $dbUser WITH PASSWORD '$dbPass';
  END IF;
END
`$`$;
SELECT 'CREATE DATABASE $dbName OWNER $dbUser'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$dbName')\gexec
GRANT ALL PRIVILEGES ON DATABASE $dbName TO $dbUser;
"@
        try {
            $sql | docker exec -i postgres-main psql -U admin -d postgres 2>$null
            Write-Host "    [OK] PostgreSQL database and user created successfully." -ForegroundColor Green
        } catch {
            Write-Host "    [!] Note: Postgres container may not be running yet. Start it with .\manage.ps1 start-project $Name" -ForegroundColor Yellow
        }

        # 2. MinIO Bucket
        Write-Host "  * Creating MinIO Bucket '$bucketName'..." -ForegroundColor Cyan
        try {
            docker exec -i minio-create-bucket-main mc mb -p minio/$bucketName 2>$null
            Write-Host "    [OK] MinIO bucket created successfully." -ForegroundColor Green
        } catch {
            Write-Host "    [!] Note: MinIO container may not be running yet." -ForegroundColor Yellow
        }

        # 3. Generate client .env file
        $outEnvFile = Join-Path $ScriptDir ".env.$safeHyphen"
        $envTemplate = @"
# Auto-generated Cloud Credentials for Project: $Name
# Generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

# --- PostgreSQL Connection ---
DATABASE_URL=postgresql://${dbUser}:${dbPass}@postgres:5432/${dbName}
DATABASE_HOST=postgres
DATABASE_PORT=5432
DATABASE_USER=${dbUser}
DATABASE_PASSWORD=${dbPass}
DATABASE_NAME=${dbName}

# --- MinIO (S3-compatible Object Storage) ---
S3_ENDPOINT_URL=http://minio:9000
S3_BUCKET=${bucketName}
AWS_ACCESS_KEY_ID=minioadmin
AWS_SECRET_ACCESS_KEY=minioadminpass
AWS_REGION=us-east-1

# --- LiteLLM (OpenAI-compatible AI Gateway) ---
OPENAI_BASE_URL=http://litellm:4000/v1
OPENAI_API_KEY=some_random_master_key

# --- Qdrant Vector Database ---
QDRANT_URL=http://qdrant:6333
QDRANT_HOST=qdrant
QDRANT_PORT=6333

# --- Langfuse LLM Observability ---
LANGFUSE_HOST=http://langfuse:3000
"@
        $envTemplate | Set-Content $outEnvFile
        Write-Host "`n[Provisioner] Generated client environment file: $outEnvFile" -ForegroundColor Green
        Write-Host "Copy this file into your client project folder as '.env' and attach your project compose to 'shared-infra-net'!" -ForegroundColor Yellow
    }

    default {
        Write-Host @"
Local Shared Cloud Management CLI

Commands:
  .\manage.ps1 start-project <name>         Activate project & start the union of all active services
  .\manage.ps1 stop-project <name>          Deactivate project & stop any services no longer needed
  .\manage.ps1 stop-all                     Deactivate all projects and stop all containers
  .\manage.ps1 status                       Show active projects, calculated service union, and container status
  .\manage.ps1 list-projects                List all registered projects and dependencies
  .\manage.ps1 register-project -Name <n>   Register a new project with its service list
  .\manage.ps1 provision-project -Name <n>  Auto-generate isolated DB, MinIO bucket, and client .env
  .\manage.ps1 add-service <name>           Add a pre-configured service from catalog (e.g. redis, milvus)
  .\manage.ps1 sync                         Reconcile running containers with currently active projects
"@
    }
}
