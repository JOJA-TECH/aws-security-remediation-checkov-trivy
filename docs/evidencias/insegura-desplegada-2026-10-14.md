# Evidencia — despliegue de la versión INSEGURA

Fecha: 2026-10-14 · Cuenta `948218213402` · Región `us-east-1` · Cluster `insecure-demo-dev`

Despliegue controlado de la infraestructura insegura (23 recursos) con el
objetivo de demostrar, en vivo, los problemas antes de corregirlos.

## Aplicación publicada (insegura)

```
$ curl http://184.195.170.37:8080/health
{"app":"insecure-infra-demo","message":"ok","version":"latest","commit":"unknown","status":"healthy"}

$ curl http://184.195.170.37:8080/
{"app":"insecure-infra-demo","message":"La aplicacion esta funcionando correctamente","version":"latest","commit":"unknown"}
```

La tarea Fargate obtiene **IP pública directa** (subred pública, `assign_public_ip=true`)
y el SG expone la app al mundo. `image_tag = latest`.

## Hallazgos observados en vivo (antes de corregir)

| # | Problema intencional | Evidencia CLI |
|---|----------------------|---------------|
| 1 | Puerto administrativo SSH (22) abierto a `0.0.0.0/0` | SG `sg-07dff00a40a292d95`: ingress 22, 80 y 8080 desde `0.0.0.0/0` |
| 2 | Contenedor como **root**, FS raíz escribible | task def: `user=null`, `readonlyRootFilesystem=false` |
| 3 | Etiquetas **mutables** (`latest`) | ECR `imageTagMutability=MUTABLE`, `scanOnPush=false` |
| 4 | Almacenamiento **público** | S3 `insecure-demo-dev-artifacts`: ACL `AllUsers`, `PolicyStatus.IsPublic=true` |
| 5 | Permisos **amplios** | rol de tarea con `AdministratorAccess` + inline `Action:* Resource:*` |
| 6 | **Secretos visibles** en el entorno del contenedor | task def environment: `DB_PASSWORD`, `API_TOKEN`, `AWS_*` en texto claro |
| 7 | Sin cifrado gestionado | ECR `AES256`, log group sin KMS ni retención |
| 8 | Sin **VPC Flow Logs** | `describe-flow-logs` → `[]` |
| 9 | Sin ALB / sin escaneo de imagen | — |

## Resultados de seguridad (fase insegura)

- Checkov (`terraform/insecure`): **42 failed / 43 passed**.
- Trivy config (`terraform/insecure`): múltiples HIGH (S3 público, SG abiertos, IAM, ECR).
- Trivy fs secretos: **2** secretos (AWS key + GitHub PAT) en `ecs.tf`.
- Trivy imagen insegura (`Dockerfile.insecure`, base `python:latest`, root): **3689 vulnerabilidades** (16 CRITICAL / 313 HIGH) + PAT incrustado.

Estos resultados justifican las correcciones aplicadas en los commits siguientes.
