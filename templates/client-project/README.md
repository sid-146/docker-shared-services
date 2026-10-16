# Connecting Client Projects to Local Shared Cloud

This project connects to the shared infrastructure running in `docker-shared-services`.

### 1. Network Configuration

Ensure your project's `compose.yaml` attaches to the external network `shared-infra-net`:

```yaml
networks:
    shared-infra-net:
        external: true
```

### 2. Service Endpoints Reference

When running inside Docker on `shared-infra-net`, use the container hostnames:

| Service                   | Internal Docker Endpoint  | Local Host / IDE Endpoint  |
| :------------------------ | :------------------------ | :------------------------- |
| **PostgreSQL**            | `postgres:5432`           | `localhost:5432`           |
| **MinIO (S3 API)**        | `http://minio:9000`       | `http://localhost:9000`    |
| **MinIO (Console)**       | -                         | `http://localhost:9001`    |
| **LiteLLM (AI Gateway)**  | `http://litellm:4000/v1`  | `http://localhost:4000/v1` |
| **Qdrant (Vector DB)**    | `http://qdrant:6333`      | `localhost:6333`           |
| **Langfuse (Tracing/UI)** | `http://langfuse:3000`    | `http://localhost:3001`    |

### 3. Provisioning Your Project

In `docker-shared-services`, run:

```powershell
.\manage.ps1 provision-project -Name "my-project"
```

Copy the generated `.env.my-project` file into this directory as `.env`.
