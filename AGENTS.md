# AGENTS.md — Instructions for AI Coding Agents

> **Audience:** Any AI coding assistant (Antigravity, Claude Code, Cursor, Copilot, Windsurf, Aider) working in this repository or integrating external projects with this Local Shared Cloud.

---

## 1. System Overview & Core Architecture

This repository (`docker-shared-services`) is a self-hosted **Local Private Cloud / Internal Developer Platform (IDP)**. It provides centralized shared infrastructure (PostgreSQL, MinIO, LiteLLM, Ollama, Milvus, Prometheus, Grafana, Redis) for multiple client projects (e.g., `curio`, `folioman`, `doc-agent`, and future projects) running on this machine.

### Key Architectural Pillars:
1. **Single Unified PostgreSQL Instance (`postgres-main`):**
   - **DO NOT** create separate PostgreSQL containers for client projects.
   - A single PostgreSQL 16 container runs on port `5432`.
   - Each project has its own isolated database (e.g. `curio_db`, `folioman`, `litellm_db`) and dedicated credentials.
   - The PostgreSQL superuser is **`admin`** (password: `admin`), **NOT** `postgres`.
2. **Desired-State Engine (`manage.ps1` / `manage.sh`):**
   - Projects declare their dependencies in `projects.json`.
   - The orchestrator calculates the mathematical **union** of services required by all currently active projects.
   - Starting a project starts only newly needed services.
   - Stopping a project stops only services that no other active project needs.
3. **Shared Bridge Network (`shared-infra-net`):**
   - All shared infrastructure containers and external client project containers connect to `shared-infra-net`.
   - Internal communication uses Docker service names: `postgres:5432`, `http://minio:9000`, `http://litellm:4000/v1`, `http://curio-prometheus:9090`.
4. **Persistent Bind Mounts:**
   - Host storage path: `D:\docker-images\volumes\<service_data>` (configured via `${VOLUMES_ROOT}`).
   - Do NOT use ephemeral volumes or ad-hoc local bind mounts for persistent service data.

---

## 2. Non-Negotiable Directives for Coding Agents

Follow these critical safety and architectural rules at all times:

1. **NEVER create duplicate database containers.**
   If an external project has a `postgres:` service in its `docker-compose.yml`, remove it and connect the app to `postgres:5432` on `shared-infra-net`.
2. **NEVER run destructive data commands without backup.**
   Never run `DROP DATABASE`, `TRUNCATE`, or `docker volume rm` without first creating a verified SQL dump in `D:\docker-images\volumes\backups\`.
3. **NEVER use `docker compose down` or `docker stop` arbitrarily.**
   Other projects may depend on shared containers (e.g., `postgres-main`). Always use the orchestrator:
   `.\manage.ps1 stop-project <name>` or `.\manage.ps1 stop-all`.
4. **Superuser username is `admin`.**
   Running `psql -U postgres` will fail with `FATAL: role "postgres" does not exist`. Always use `-U admin` for administrative queries.
5. **Preserve `profiles` and `include` structure.**
   All services in `compose.yaml` and `catalog/*/compose.yaml` must define `profiles: ["<service-name>", "all"]` and attach to `shared-infra-net`.

---

## 3. Orchestrator CLI Quick Reference

Agents should use `manage.ps1` (or `manage.sh` in Bash) to inspect and manipulate state:

```powershell
# Check running status, active projects, and container health
powershell -ExecutionPolicy Bypass -File .\manage.ps1 status

# List all registered projects and their dependencies
powershell -ExecutionPolicy Bypass -File .\manage.ps1 list-projects

# Activate a project (starts newly required overlapping services)
powershell -ExecutionPolicy Bypass -File .\manage.ps1 start-project <project-name>

# Deactivate a project (stops idle services not needed by other projects)
powershell -ExecutionPolicy Bypass -File .\manage.ps1 stop-project <project-name>

# Start a specific standalone service (e.g. postgres, redis, ollama)
powershell -ExecutionPolicy Bypass -File .\manage.ps1 start-service <service-name>

# Safely stop a specific service (blocks if active projects depend on it; pass -Force to override)
powershell -ExecutionPolicy Bypass -File .\manage.ps1 stop-service <service-name>

# Restart a specific service
powershell -ExecutionPolicy Bypass -File .\manage.ps1 restart-service <service-name>

# Follow logs for a service or all services
powershell -ExecutionPolicy Bypass -File .\manage.ps1 logs <service-name>

# Enforce desired state according to projects.json
powershell -ExecutionPolicy Bypass -File .\manage.ps1 sync

# 1-Click Provisioning for a new project (Postgres DB/user, MinIO bucket, .env file)
powershell -ExecutionPolicy Bypass -File .\manage.ps1 provision-project <project-name>

# Enable a plug-and-play service from the catalog (e.g. redis, qdrant, dockge)
powershell -ExecutionPolicy Bypass -File .\manage.ps1 add-service <service-name>

# Stop all shared cloud containers
powershell -ExecutionPolicy Bypass -File .\manage.ps1 stop-all
```

*(On Linux / WSL / Bash, use `./manage.sh <command>`)*.

---

## 4. Endpoints & Connection Reference for Client Projects

When configuring environment variables in client projects, use this exact map:

| Service | Inside Docker (`shared-infra-net`) | Outside Docker (Host / IDE / venv) | Standard Environment Variable |
| :--- | :--- | :--- | :--- |
| **PostgreSQL** | `postgres:5432` | `localhost:5432` | `DATABASE_URL=postgresql://<user>:<pass>@<host>:5432/<dbname>` |
| **MinIO (S3 API)** | `http://minio:9000` | `http://localhost:9000` | `S3_ENDPOINT=http://<host>:9000`<br/>`AWS_ENDPOINT_URL=http://<host>:9000` |
| **MinIO Console** | `http://minio:9001` | `http://localhost:9001` | Web UI |
| **LiteLLM Gateway** | `http://litellm:4000/v1` | `http://localhost:4000/v1` | `OPENAI_BASE_URL=http://<host>:4000/v1`<br/>`OPENAI_API_KEY=some_random_master_key` |
| **Ollama** | `http://ollama:11434` | `http://localhost:11434` | `OLLAMA_BASE_URL=http://<host>:11434` |
| **Milvus Vector DB**| `milvus-standalone:19530` | `localhost:19530` | `MILVUS_URI=http://<host>:19530` |
| **Attu (Milvus UI)**| `http://attu:3000` | `http://localhost:3000` | Web UI |
| **Langfuse** | `http://langfuse:3000` | `http://localhost:3001` | `LANGFUSE_HOST=http://<host>:3001` |
| **Prometheus** | `http://curio-prometheus:9090` | `http://localhost:9090` | Metrics scraper endpoint |
| **Grafana** | `http://curio-grafana:3000` | `http://localhost:3002` | Metrics dashboard |
| **Redis** | `redis:6379` | `localhost:6379` | `REDIS_URL=redis://<host>:6379/0` |

---

## 5. How to Connect an External Client Project

When asked to configure or adapt an external project repository to use this shared cloud, follow this standard pattern:

### 1. In the client project's `docker-compose.yml`:
```yaml
services:
  app:
    build: .
    restart: unless-stopped
    ports:
      - "8000:8000"
    environment:
      # Use service hostname inside Docker network:
      - DATABASE_URL=postgresql://<project_user>:<project_pass>@postgres:5432/<project_db>
      - OPENAI_BASE_URL=http://litellm:4000/v1
      - S3_ENDPOINT=http://minio:9000
    networks:
      - default
      - shared-infra-net

networks:
  shared-infra-net:
    name: shared-infra-net
    external: true
```

### 2. For local host execution (e.g. running unit tests with `pytest` / `uv run` on the host machine):
Use `localhost`:
```bash
DATABASE_URL=postgresql://<project_user>:<project_pass>@localhost:5432/<project_db>
OPENAI_BASE_URL=http://localhost:4000/v1
S3_ENDPOINT=http://localhost:9000
```

### 3. Register the project in `docker-shared-services/projects.json`:
```json
{
  "projects": {
    "my-client-app": [
      "postgres",
      "redis"
    ]
  }
}
```

---

## 6. Database Operations Protocol for Agents

### 1. Creating a New Project Database & User
Always create an idempotent SQL script under `scripts/sql/<project>-setup.sql`:
```sql
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '<project_user>') THEN
        CREATE USER <project_user> WITH PASSWORD '<project_password>';
    END IF;
END
$$;

SELECT 'CREATE DATABASE <project_db> OWNER <project_user>'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '<project_db>')\gexec

GRANT ALL PRIVILEGES ON DATABASE <project_db> TO <project_user>;
\c <project_db>
GRANT ALL ON SCHEMA public TO <project_user>;
```
Execute it on `postgres-main`:
```powershell
Get-Content scripts\sql\<project>-setup.sql | docker exec -i postgres-main psql -U admin -d postgres
```

### 2. Inspecting Databases & Tables
```powershell
# List databases:
docker exec postgres-main psql -U admin -d postgres -c "\l"

# Check tables in a specific project database:
docker exec postgres-main psql -U <project_user> -d <project_db> -c "\dt"
```

### 3. Backing Up Before Migrations
```powershell
docker exec postgres-main pg_dump -U <project_user> -d <project_db> -F p > D:\docker-images\volumes\backups\<project_db>_backup.sql
```

---

## 7. Adding New Infrastructure Services to the Cloud

To add a new shared service (e.g., Elasticsearch, Neo4j, RabbitMQ):

1. **Create Catalog Directory:** `catalog/<service-name>/compose.yaml`
2. **Standard Service Template:**
   ```yaml
   services:
     <service-name>:
       image: <image>:<tag>
       container_name: <service-name>-main
       restart: unless-stopped
       profiles: ["<service-name>", "all"]
       ports:
         - "<HOST_PORT>:<CONTAINER_PORT>"
       volumes:
         - <service-name>_data:/data
       networks:
         shared-infra-net:
           aliases:
             - <service-name>

   volumes:
     <service-name>_data:
       driver: local
       driver_opts:
         type: none
         o: bind
         device: ${VOLUMES_ROOT:-D:/docker-images/volumes}/<service-name>_data
   ```
3. **Register in `compose.yaml`:**
   Add `- catalog/<service-name>/compose.yaml` under `include:`.
4. **Register in `projects.json`:**
   Add `<service-name>` to `available_services`.
5. **Run Sync:**
   `powershell -ExecutionPolicy Bypass -File .\manage.ps1 sync`

---

## 8. Agent Troubleshooting Checklist

| Symptom | Cause | Solution |
| :--- | :--- | :--- |
| `FATAL: role "postgres" does not exist` | Ran `psql -U postgres` | Use administrative user `-U admin`. |
| `network shared-infra-net not found` | Network not created yet | Run `powershell -ExecutionPolicy Bypass -File .\manage.ps1 status` or `docker network create shared-infra-net`. |
| `could not translate host name "postgres"` | Client container not attached to `shared-infra-net` | Add `networks: [default, shared-infra-net]` to the client service in its compose file. |
| `port 5432 already allocated` | Stale container or local Windows PostgreSQL service | Check `Get-NetTCPConnection -LocalPort 5432` or stop rogue containers. |
| `database system is starting up / recovery` | Postgres replaying WAL after restart | Wait 5–10 seconds for recovery checkpoint to complete. Check `docker logs postgres-main`. |
| Missing dependency when running project | Service not declared in `projects.json` | Add service to project list in `projects.json` and run `.\manage.ps1 sync`. |

---

## 9. File & Directory Layout

```
d:\GitHub_Clones\docker-shared-services/
├── compose.yaml                  # Master Compose file (orchestrates profiles & includes)
├── AGENTS.md                     # This file (Instructions for AI coding agents)
├── HOW_TO_USE.md                 # User guide with detailed scenario walkthroughs
├── readme.md                     # High-level overview and architecture
├── projects.json                 # Desired-state registry (active projects & declared services)
├── manage.ps1 / manage.sh        # Dynamic orchestrator CLI
├── .env                          # Local credentials & configuration
├── .env.example                  # Template configuration
│
├── catalog/                      # Modular service definitions (one folder per service)
│   ├── redis/compose.yaml
│   ├── qdrant/compose.yaml
│   ├── dockge/compose.yaml
│   └── curio/compose.yaml        # Curio Prometheus + Grafana stack
│
├── configs/                      # Service configuration files
│   ├── litellm-config.yaml
│   └── monitoring/               # Prometheus & Grafana configs
│
├── scripts/                      # Bootstrap and provisioning scripts
│   ├── sql/                      # Project database bootstrap SQL scripts
│   └── milvus/                   # MinIO bucket initialization scripts
│
└── templates/                    # Starter templates for new projects & services
    ├── client-project/           # Template for connecting an external repo
    └── new-service/              # Template for authoring a catalog service
```
