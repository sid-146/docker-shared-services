# Local Shared Cloud Platform

A self-hosted, modular **Local Private Cloud / Internal Developer Platform (IDP)** designed to power multiple AI agents, web applications, and data science projects on your local workstation with unified resource sharing and automated project isolation.

> 📖 **Comprehensive Guide:** See [HOW_TO_USE.md](file:///d:/GitHub_Clones/docker-shared-services/HOW_TO_USE.md) for detailed scenarios (daily workflow, onboarding existing apps, 1-click AI agent provisioning, custom services, and backups).
> 🤖 **For AI Coding Agents:** See [AGENTS.md](file:///d:/GitHub_Clones/docker-shared-services/AGENTS.md) for strict architectural rules, CLI commands, and integration protocols.

---

## 🌟 Built-in Shared Cloud Services

| Service           | Internal Docker Host      | Host Port (`0.0.0.0` / Wi-Fi)       | Purpose                                                                                                   |
| :---------------- | :------------------------ | :---------------------------------- | :-------------------------------------------------------------------------------------------------------- |
| **PostgreSQL 16** | `postgres:5432`           | `0.0.0.0:5432`                      | Single unified relational DB with isolated databases & users (`curio_db`, `folioman`, `litellm_db`, etc.) |
| **MinIO (S3)**    | `http://minio:9000`       | `0.0.0.0:9000` (API) / `9001` (UI)  | S3-compatible object storage with project buckets                                                         |
| **LiteLLM Proxy** | `http://litellm:4000/v1`  | `0.0.0.0:4000/v1`                   | OpenAI-compatible gateway with model routing                                                              |
| **Ollama**        | `http://ollama:11434`     | `0.0.0.0:11434`                     | Local GPU-accelerated model serving (with Wi-Fi CORS allowed)                                             |
| **Qdrant**        | `http://qdrant:6333`      | `0.0.0.0:6333` (API) / `6334` (gRPC)| Lightweight, ultra-fast vector search engine & web UI                                                   |
| **Langfuse**      | `http://langfuse:3000`    | `0.0.0.0:3001`                      | Open-source LLM observability & tracing                                                                   |
| **Prometheus**    | `curio-prometheus:9090`   | `0.0.0.0:9090`                      | Time-series metrics collection                                                                            |
| **Grafana**       | `curio-grafana:3000`      | `0.0.0.0:3002`                      | Metrics visualization dashboard                                                                           |
| **Redis**         | `redis:6379`              | `0.0.0.0:6379`                      | In-memory cache & message broker (protected mode disabled for LAN access)                                 |

---

## 🚀 Dynamic Multi-Project Management

You don't need to manually type service names or guess overlapping dependencies. The **Desired-State Project Engine** automatically calculates the union of services required by all currently active projects.

### How it works:

- **Project A** needs 4 services: `[postgres, litellm, ollama, minio]`
- **Project B** needs 4 services: `[postgres, minio, qdrant, langfuse]`
- **Total running union:** Exactly **6 services**. When Project B stops, the 2 unused services automatically stop to save RAM and GPU resources!

### CLI Commands:

```powershell
# 1. Check current status, active projects, and running containers
.\manage.ps1 status

# 2. View registered projects and their declared services
.\manage.ps1 list-projects

# 3. Activate a project (starts the union of needed services)
.\manage.ps1 start-project doc-agent

# 4. Activate another project (starts only the newly needed overlapping services)
.\manage.ps1 start-project ml-research

# 5. Deactivate a project (stops services no longer needed by any active project)
.\manage.ps1 stop-project doc-agent

# 6. Stop all shared cloud containers
.\manage.ps1 stop-all
```

_(Bash / Linux / WSL users can also run `./manage.sh <command>`)_

---

## ⚡ Effortlessly Adding New Services

Adding new services to the cloud takes one command without editing monolithic compose files:

```powershell
# Add a pre-configured service from the catalog (e.g., Redis, Milvus, Dockge)
.\manage.ps1 add-service redis
```

This command:

1. Provisions the persistent storage volume on `D:\docker-images\volumes\redis_data`.
2. Connects the service to `shared-infra-net` using Docker Compose `include:`.
3. Registers the service in `projects.json` so projects can use it immediately.

### Pre-built Service Catalog:

- `redis` — In-memory caching, message queues, and pub/sub.
- `milvus` — High-performance distributed vector database with Attu Web UI.
- `dockge` — Web UI for viewing and managing Docker stacks.
- `templates/new-service` — Boilerplate for authoring any custom service.

---

## 🛠️ Onboarding a New Project (1-Click Provisioning)

To create isolated credentials and connection strings for a new project:

```powershell
.\manage.ps1 provision-project my-new-agent
```

This automatically:

1. Creates dedicated PostgreSQL user `my_new_agent_user` and database `my_new_agent_db`.
2. Creates dedicated MinIO bucket `minio/my-new-agent`.
3. Generates a `.env.my-new-agent` file with ready-to-use connection strings.

### Connecting External Projects:

In your client project's `compose.yaml`:

```yaml
services:
    app:
        build: .
        env_file: .env
        networks:
            - default
            - shared-infra-net

networks:
    shared-infra-net:
        external: true
```

---

## 📁 Repository Structure

```
docker-shared-services/
├── compose.yaml                  # Master Compose orchestrator (profiles + include)
├── .env                          # Local environment configs
├── .env.example                  # Template configuration
├── projects.json                 # Project registry & active state tracker
├── manage.ps1 / manage.sh        # Unified cloud management CLI
│
├── configs/
│   └── litellm-config.yaml       # LiteLLM routing & Langfuse callbacks
├── scripts/
│   ├── minio/create-buckets.sh   # Automatic MinIO bucket initializer
│   └── sql/                      # PostgreSQL database bootstrap scripts
│       ├── litellm-setup.sql
│       ├── mlflow-setup.sql
│       ├── agent-doc-setup.sql
│       └── langfuse-setup.sql    # Langfuse DB & user initializer
│
├── catalog/                      # Plug-and-play service recipes
│   ├── redis/
│   ├── milvus/
│   └── dockge/
│
└── templates/                    # Client project & custom service boilerplates
    ├── client-project/
    └── new-service/
```
