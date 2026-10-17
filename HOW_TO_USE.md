# Local Shared Cloud: Complete User & Scenario Guide

A modular, local **Private Cloud / Internal Developer Platform (IDP)** designed to run shared infrastructure for multiple projects on your local workstation. It provides centralized services (databases, AI gateways, vector databases, S3 storage, caches, and monitoring) without duplicating containers or wasting host resources.

---

## Table of Contents

1. [Core Architectural Concepts](#1-core-architectural-concepts)
2. [CLI Reference (`manage.ps1` / `manage.sh`)](#2-cli-reference)
3. [Service Endpoints & Port Map](#3-service-endpoints--port-map)
4. [Scenario 1: Daily Development & Dynamic Service Overlaps](#scenario-1-daily-development--dynamic-service-overlaps)
5. [Scenario 2: Onboarding an Existing Project (e.g., Curio, Folioman)](#scenario-2-onboarding-an-existing-project)
6. [Scenario 3: Creating a Brand New AI Agent Project (1-Click Provisioning)](#scenario-3-creating-a-brand-new-ai-agent-project)
7. [Scenario 4: Adding a Service from the Pre-built Catalog (e.g., Redis, Milvus)](#scenario-4-adding-a-service-from-the-pre-built-catalog)
8. [Scenario 5: Authoring a Brand New Custom Service](#scenario-5-authoring-a-brand-new-custom-service)
9. [Scenario 6: Connecting from Host (IDE, Python venv, DBeaver) vs Docker](#scenario-6-connecting-from-host-vs-docker)
10. [Scenario 7: Database Management, Backups & Restores](#scenario-7-database-management-backups--restores)
11. [Troubleshooting & FAQs](#11-troubleshooting--faqs)

---

## 1. Core Architectural Concepts

### 1.1 The Problem It Solves

Running 3 or 4 separate projects usually means:

- Multiple PostgreSQL containers running simultaneously, fighting for host ports (`5432`, `5433`, `5434`).
- Duplicate Redis, Ollama, or MinIO instances hogging gigabytes of RAM and GPU memory.
- Cumbersome scripts to start and stop services manually.

### 1.2 The Shared Cloud Solution

1. **Single Unified PostgreSQL Instance (`postgres-main`):**
   One PostgreSQL 16 container serves all projects. Each project gets its own isolated database (e.g., `curio_db`, `folioman`, `litellm_db`) and dedicated user credentials.
2. **Desired-State Engine (Dynamic Union of Services):**
   You declare what services each project requires in `projects.json`. When you start projects, the platform computes the **mathematical union** of required services and starts only what is needed. When you stop a project, idle services that no other active project needs are automatically shut down.
3. **Shared Bridge Network (`shared-infra-net`):**
   A persistent Docker bridge network connects all shared services and project containers. Containers address each other by service name (`postgres:5432`, `minio:9000`, `litellm:4000`).
4. **Predictable Bind Mounts:**
   All persistent data lives under `D:\docker-images\volumes\<service_data>`, making backups and inspection trivial.

---

## 2. CLI Reference

All orchestration is handled through `manage.ps1` (PowerShell on Windows) or `manage.sh` (Bash / WSL / macOS / Linux).

| Command           | Syntax                                  | Description                                                                   |
| :---------------- | :-------------------------------------- | :---------------------------------------------------------------------------- |
| **Status**        | `.\manage.ps1 status`                   | Shows active projects, required services union, and running container health. |
| **List Projects** | `.\manage.ps1 list-projects`            | Lists all registered projects, their assigned services, and active status.    |
| **Start Project** | `.\manage.ps1 start-project <name>`     | Activates a project and reconciles containers (starts newly needed services). |
| **Stop Project**  | `.\manage.ps1 stop-project <name>`      | Deactivates a project and stops services no longer required by any project.   |
| **Stop All**      | `.\manage.ps1 stop-all`                 | Immediately deactivates all projects and stops all shared containers.         |
| **Sync**          | `.\manage.ps1 sync`                     | Re-evaluates active projects in `projects.json` and enforces container state. |
| **Provision**     | `.\manage.ps1 provision-project <name>` | Automatically creates PostgreSQL DB/user, MinIO bucket, and `.env.<name>`.    |
| **Add Service**   | `.\manage.ps1 add-service <name>`       | Enables a plug-and-play service from `catalog/` into the master stack.        |

> **Linux / WSL / Git Bash:** Replace `.\manage.ps1 <cmd>` with `./manage.sh <cmd>`.

---

## 3. Service Endpoints & Port Map

| Service                | Internal Docker Host (within `shared-infra-net`) | Host Port (`0.0.0.0`)    | Web UI / Dashboard / Wi-Fi Access                |
| :--------------------- | :----------------------------------------------- | :----------------------- | :----------------------------------------------- |
| **PostgreSQL 16**      | `postgres:5432`                                  | `0.0.0.0:5432`           | Connect via `localhost:5432` or `<WIFI_IP>:5432` |
| **LiteLLM Proxy**      | `http://litellm:4000/v1`                         | `0.0.0.0:4000`           | `http://<WIFI_IP>:4000/v1`                       |
| **Ollama (LLMs)**      | `http://ollama:11434`                            | `0.0.0.0:11434`          | `http://<WIFI_IP>:11434` (CORS enabled)          |
| **MinIO (S3 API)**     | `http://minio:9000`                              | `0.0.0.0:9000`           | `http://<WIFI_IP>:9000`                          |
| **MinIO Console**      | `http://minio:9001`                              | `0.0.0.0:9001`           | `http://<WIFI_IP>:9001` (Web console)            |
| **Qdrant (Vector DB)** | `http://qdrant:6333`                             | `0.0.0.0:6333` / `6334`  | `http://<WIFI_IP>:6333` (REST & Web Dashboard)   |
| **Langfuse**           | `http://langfuse:3000`                           | `0.0.0.0:3001`           | `http://<WIFI_IP>:3001`                          |
| **Prometheus**         | `http://curio-prometheus:9090`                   | `0.0.0.0:9090`           | `http://<WIFI_IP>:9090`                          |
| **Grafana**            | `http://curio-grafana:3000`                      | `0.0.0.0:3002`           | `http://<WIFI_IP>:3002`                          |
| **Redis** _(Catalog)_  | `redis:6379`                                     | `0.0.0.0:6379`           | `<WIFI_IP>:6379`                                 |
| **Milvus** _(Catalog)_ | `milvus-standalone:19530`                        | `0.0.0.0:19530` / `9091` | Distributed vector database                      |
| **Attu** _(Catalog)_   | `http://attu:3000`                               | `0.0.0.0:3000`           | `http://<WIFI_IP>:3000`                          |

> **Note on Wi-Fi / LAN Access (`0.0.0.0`):**
> All services explicitly bind to `0.0.0.0`, exposing them to your local Wi-Fi / LAN network. You can reach any service from another laptop, phone, or tablet on the same Wi-Fi network using your host machine's Wi-Fi IP (e.g. `http://192.168.1.5:3002` for Grafana).

---

## Scenario 1: Daily Development & Dynamic Service Overlaps

### The Scenario

You are developing two projects:

1. `curio` (Web app with analytics) requires: `postgres`, `prometheus`, `grafana`
2. `folioman` (Portfolio valuation app) requires: `postgres`
3. `doc-agent` (AI agent) requires: `postgres`, `litellm`, `ollama`, `minio`

### Step 1: Start Working on Curio

```powershell
.\manage.ps1 start-project curio
```

**Output:**

```text
Activated project 'curio'.
Active Services Union (3): postgres, prometheus, grafana
Reconciling Docker containers...
Started: postgres-main, curio-prometheus, curio-grafana
```

### Step 2: Switch or Concurrently Work on Folioman

```powershell
.\manage.ps1 start-project folioman
```

**Output:**

```text
Activated project 'folioman'.
Active Services Union (3): postgres, prometheus, grafana
Reconciling Docker containers...
```

_Note:_ Because `folioman` only needs `postgres` and `postgres` is already running for `curio`, **no new containers are spawned**. Zero wasted RAM.

### Step 3: Spin Up the AI Doc Agent

```powershell
.\manage.ps1 start-project doc-agent
```

**Output:**

```text
Active Services Union (6): postgres, prometheus, grafana, litellm, ollama, minio
Reconciling Docker containers...
Started: litellm-main, ollama-main, minio-main
```

The system intelligently starts only the 3 new services needed (`litellm`, `ollama`, `minio`), keeping the existing 3 untouched.

### Step 4: Stop the AI Doc Agent

```powershell
.\manage.ps1 stop-project doc-agent
```

**Output:**

```text
Deactivated project 'doc-agent'.
Active Services Union (3): postgres, prometheus, grafana
Stopping idle service no longer needed: litellm
Stopping idle service no longer needed: ollama
Stopping idle service no longer needed: minio
```

The GPU and memory used by `ollama`, `litellm`, and `minio` are immediately freed, while `curio` and `folioman` continue running seamlessly.

---

## Scenario 2: Onboarding an Existing Project

Suppose you have an existing project repository (e.g., `D:\GitHub_Clones\my-web-app`) that currently has its own `postgres` container in its `docker-compose.yml`.

### Step 1: Backup Any Existing Database Data

If your existing project has data you need to preserve:

```powershell
# Export data from your project's current postgres container
docker exec my-project-db pg_dump -U myuser -d mydb -Fc -f /tmp/backup.dump
docker cp my-project-db:/tmp/backup.dump D:\docker-images\volumes\backups\my-project.dump
```

### Step 2: Create Database & User in Shared Postgres

Create a setup script `scripts/sql/my-project-setup.sql` in `docker-shared-services`:

```sql
CREATE DATABASE my_app_db;
CREATE USER my_app_user WITH PASSWORD 'my_secure_password';
GRANT ALL PRIVILEGES ON DATABASE my_app_db TO my_app_user;
\c my_app_db
GRANT ALL ON SCHEMA public TO my_app_user;
```

Execute it on `postgres-main`:

```powershell
Get-Content scripts\sql\my-project-setup.sql | docker exec -i postgres-main psql -U admin -d postgres
```

If restoring existing data:

```powershell
docker exec -i postgres-main pg_restore -U my_app_user -d my_app_db --no-owner --role=my_app_user < D:\docker-images\volumes\backups\my-project.dump
```

### Step 3: Update the Project's Compose File

In `D:\GitHub_Clones\my-web-app\docker-compose.shared.yml`:

1. Remove the local `postgres:` service definition.
2. Update the backend/app container's `DATABASE_URL` environment variable:
    ```yaml
    DATABASE_URL: postgresql://my_app_user:my_secure_password@postgres:5432/my_app_db
    ```
3. Attach the app container to `shared-infra-net`:

    ```yaml
    services:
        app:
            build: .
            ports:
                - "8000:8000"
            environment:
                - DATABASE_URL=postgresql://my_app_user:my_secure_password@postgres:5432/my_app_db
            networks:
                - default
                - shared-infra-net

    networks:
        shared-infra-net:
            name: shared-infra-net
            external: true
    ```

### Step 4: Register the Project in Shared Cloud

In `docker-shared-services/projects.json`, add:

```json
{
    "projects": {
        "my-web-app": ["postgres"]
    }
}
```

Or simply run:

```powershell
.\manage.ps1 start-project my-web-app
```

(It will prompt you for required services if not already registered).

### Step 5: Start Your Project

```powershell
# 1. Ensure shared cloud has started postgres
cd D:\GitHub_Clones\docker-shared-services
.\manage.ps1 start-project my-web-app

# 2. Launch your project app
cd D:\GitHub_Clones\my-web-app
docker compose -f docker-compose.shared.yml up -d
```

---

## Scenario 3: Creating a Brand New AI Agent Project

If you are bootstrapping a new Python, LangChain, LlamaIndex, or AutoGen agent project from scratch:

### Step 1: Run 1-Click Provisioning

```powershell
cd D:\GitHub_Clones\docker-shared-services
.\manage.ps1 provision-project legal-agent
```

### What This Automates:

1. Creates database `legal_agent_db` and user `legal_agent_user` on `postgres-main`.
2. Creates an S3 storage bucket `legal-agent` in MinIO.
3. Generates a tailored `.env.legal-agent` file containing:
    ```bash
    DATABASE_URL=postgresql://legal_agent_user:generated_pass@postgres:5432/legal_agent_db
    S3_ENDPOINT=http://minio:9000
    S3_BUCKET=legal-agent
    OPENAI_BASE_URL=http://litellm:4000/v1
    OPENAI_API_KEY=some_random_master_key
    QDRANT_URL=http://qdrant:6333
    LANGFUSE_HOST=http://langfuse:3000
    ```

### Step 2: Initialize Your Agent Codebase

Copy the `.env.legal-agent` to your new agent directory as `.env`:

```powershell
mkdir D:\GitHub_Clones\legal-agent
Copy-Item .env.legal-agent D:\GitHub_Clones\legal-agent\.env
```

### Step 3: Register and Run

In `docker-shared-services`:

```powershell
.\manage.ps1 start-project legal-agent
# Enter required services: postgres,litellm,ollama,minio,qdrant,langfuse
```

Your code can now:

- Query local Ollama models or external OpenAI models transparently via LiteLLM (`OPENAI_BASE_URL`).
- Store document embeddings into Qdrant vector DB (`QDRANT_URL`).
- Store uploaded PDFs into MinIO S3 (`S3_ENDPOINT`).
- Automatically trace all LLM prompts, latency, and cost in the Langfuse dashboard at `http://localhost:3001`.

---

## Scenario 4: Adding a Service from the Pre-built Catalog

The Shared Cloud includes pre-configured recipes in `catalog/` (such as Redis, Milvus vector database, Dockge web UI).

### Example: Adding Redis

```powershell
cd D:\GitHub_Clones\docker-shared-services
.\manage.ps1 add-service redis
```

### What Happens:

1. Verifies/creates storage folder `D:\docker-images\volumes\redis_data`.
2. Adds `- catalog/redis/compose.yaml` to the `include:` block in `compose.yaml`.
3. Adds `redis` to `available_services` in `projects.json`.

### Using Redis in a Project:

In `projects.json`, add `"redis"` to your project's list:

```json
"curio": [
  "postgres",
  "prometheus",
  "grafana",
  "redis"
]
```

Run `.\manage.ps1 sync`, and Redis is instantly launched on `redis:6379` (internal) and `localhost:6379` (host)!

---

## Scenario 5: Authoring a Brand New Custom Service

If you need a service that is not in the catalog (e.g., Meilisearch, RabbitMQ, Neo4j):

### Step 1: Copy the Template

```powershell
Copy-Item -Recurse templates\new-service catalog\rabbitmq
```

### Step 2: Edit `catalog\rabbitmq\compose.yaml`

```yaml
services:
    rabbitmq:
        image: rabbitmq:3-management-alpine
        container_name: rabbitmq-main
        restart: unless-stopped
        profiles: ["rabbitmq", "all"]
        environment:
            RABBITMQ_DEFAULT_USER: rabbitmq
            RABBITMQ_DEFAULT_PASS: rabbitmq_secret
        ports:
            - "5672:5672"
            - "15672:15672"
        volumes:
            - rabbitmq_data:/var/lib/rabbitmq
        networks:
            shared-infra-net:
                aliases:
                    - rabbitmq

volumes:
    rabbitmq_data:
        driver: local
        driver_opts:
            type: none
            o: bind
            device: ${VOLUMES_ROOT:-D:/docker-images/volumes}/rabbitmq_data
```

### Step 3: Register in `compose.yaml`

Under `include:` in `compose.yaml`, add:

```yaml
include:
    - catalog/redis/compose.yaml
    - catalog/curio/compose.yaml
    - catalog/rabbitmq/compose.yaml
```

### Step 4: Add to `projects.json`

Add `"rabbitmq"` under `available_services` and assign it to any project.

---

## Scenario 6: Connecting from Host vs Docker

Developers frequently ask: _"Why does `postgres:5432` fail when I run tests from my VS Code terminal?"_

Understand the two network contexts:

```
[Local Host Machine (Windows)]
  ├── Python virtualenv (uv / poetry / pip)  --> Connects to localhost:5432
  ├── Database GUI (DBeaver / DataGrip)      --> Connects to localhost:5432
  └── Browser (Chrome)                       --> Connects to http://localhost:3002
                                                        │
                      [Docker Bridge Network: shared-infra-net]
                                                        │
  ├── App Container (curio-backend)         --> Connects to postgres:5432
  ├── Worker Container (folioman-scheduler) --> Connects to postgres:5432
  └── LiteLLM Proxy                         --> Connects to postgres:5432
```

### Connection String Rules:

- **Running inside a container on `shared-infra-net`:**
  Use the service name:
  `postgresql://curio:curio@postgres:5432/curio_db`
- **Running directly on Windows / Host (e.g., `uv run pytest`, IDE debugger):**
  Use `localhost` or `127.0.0.1`:
  `postgresql://curio:curio@localhost:5432/curio_db`
- **Connecting from another machine / device over the Wi-Fi network:**
  Use your host machine's Wi-Fi IPv4 address (e.g., `192.168.1.5`):
  `postgresql://curio:curio@192.168.1.5:5432/curio_db`
  `http://192.168.1.5:3002` (Grafana)
  `http://192.168.1.5:11434` (Ollama)

> [!TIP]
> **Windows Firewall Configuration for Wi-Fi Access:**
> If other devices on the Wi-Fi network cannot connect to your ports, Windows Defender Firewall might be blocking incoming traffic because your Wi-Fi network category is set to `Public`.
> In an elevated PowerShell prompt, set the network profile to `Private`:
>
> ```powershell
> Get-NetConnectionProfile
> Set-NetConnectionProfile -Name "<Your_WiFi_Network_Name>" -NetworkCategory Private
> ```

---

## Scenario 7: Database Management, Backups & Restores

All project databases run in `postgres-main`. Here are standard operational commands:

### Listing All Databases & Users

```powershell
docker exec postgres-main psql -U admin -d postgres -c "\l"
docker exec postgres-main psql -U admin -d postgres -c "\du"
```

### Backing Up a Single Project Database

To create an atomic, compressed backup of `folioman` or `curio_db`:

```powershell
# Create backups directory if missing
New-Item -ItemType Directory -Force "D:\docker-images\volumes\backups"

# Dump folioman database
docker exec postgres-main pg_dump -U folioman -d folioman -F p > D:\docker-images\volumes\backups\folioman.sql

# Dump curio database
docker exec postgres-main pg_dump -U curio -d curio_db -F p > D:\docker-images\volumes\backups\curio_db.sql
```

### Restoring a Database

```powershell
Get-Content D:\docker-images\volumes\backups\curio_db.sql | docker exec -i postgres-main psql -U curio -d curio_db
```

---

## 11. Troubleshooting & FAQs

### Q: `FATAL: role "postgres" does not exist`

**Fix:** The superuser for `postgres-main` is `admin` (defined in `.env`), not `postgres`. Always specify `-U admin` when executing administrative psql commands:

```powershell
docker exec -it postgres-main psql -U admin -d postgres
```

### Q: Port 5432 is already in use

**Fix:** Check if a local PostgreSQL service is running on Windows:

```powershell
Get-Process -Name "*postgres*"
Get-NetTCPConnection -LocalPort 5432
```

If a Windows service has port 5432, stop it using Windows Services (`services.msc` -> Stop "postgresql-x64-XX").

### Q: Container cannot resolve `postgres` hostname

**Fix:** Ensure your client project compose file has:

1. `networks: [default, shared-infra-net]` on the service.
2. `networks: shared-infra-net: external: true` at the bottom of the compose file.
3. Test connectivity using:
    ```powershell
    docker run --rm --network shared-infra-net alpine ping -c 2 postgres
    ```

### Q: How do I cleanly restart or reset a service?

```powershell
docker compose restart postgres
# Or view logs in real time:
docker logs -f postgres-main
```
