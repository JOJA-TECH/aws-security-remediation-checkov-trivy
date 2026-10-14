# Remediación in-place — cómo se simula y se aplica la corrección

Este documento explica **cómo se simula la corrección** de la infraestructura
insegura y **qué commit corrige cada hallazgo**. La idea: en lugar de escribir
una carpeta "segura" desde cero, se parte del stack inseguro y se corrige
**en sitio**, un commit por familia de hallazgos, demostrando el antes/después
con los escáneres.

## 1. Cómo se simula la corrección (flujo reproducido)

```bash
# 0) (ya hecho) El stack original vulnerable queda congelado como evidencia
#    "antes": terraform/baseline/  (commit 15b6e85)

# 1) Despliegue de la versión insegura y captura de evidencia
cd terraform/insecure
terraform init && terraform apply          # crea recursos inseguros
curl http://<public-ip>:8080/health        # app publicada con tag "latest"
#   -> docs/evidencias/insegura-desplegada-2026-10-14.md

# 2) Escaneo "antes"
checkov -d ../baseline --framework terraform          # 42 failed
trivy config ../baseline                              # 23 misconfigs
trivy fs --scanners secret ../baseline                # 2 secretos
#   -> docs/hallazgos-iniciales.md

# 3) Corrección in-place, un commit por familia de hallazgos (ver §2)

# 4) Escaneo "después" (debe quedar en 0 con las excepciones justificadas)
checkov -d . --framework terraform --config-file ../checkov/remediated.yaml
trivy config --ignorefile ../trivy/remediated.ignore --severity CRITICAL,HIGH --exit-code 1 .

# 5) Redepliegue de la versión corregida y verificación
terraform apply -var "image_uri=<digest>"
#   -> docs/evidencias/... (endpoint /health, ECS 1/1, SG mínimo, etc.)

# 6) Destrucción
terraform destroy -var "image_uri=<digest>"
```

## 2. Tabla hallazgo → corrección → commit

| # | Familia de hallazgos | Corrección aplicada | Commit |
|---|----------------------|---------------------|--------|
| C1 | **Grupos de seguridad**: 22 abierto al mundo (CKV_AWS_24, AWS-0107), 80 abierto (CKV_AWS_260), reglas sin descripción (CKV_AWS_23, AWS-0124), egress sin restringir (CKV_AWS_382, AWS-0104) | Se eliminan 22 y 80; queda solo el puerto de app (8080); descripciones en SG y reglas; egress limitado a HTTPS (443) y DNS interno (53); SG por defecto cerrado | `f1b625f` |
| C2 | **Logs y red**: sin Container Insights (CKV_AWS_65, AWS-0034), log group sin KMS (CKV_AWS_158, AWS-0017) ni retención (CKV_AWS_66, CKV_AWS_338), sin Flow Logs (CKV2_AWS_11, AWS-0178), subredes con IP pública (CKV_AWS_130, AWS-0164) | Clave KMS gestionada (rotación); Container Insights; retención 365 días + KMS en el log group; VPC Flow Logs cifrados; subredes sin auto-asignación de IP | `9675497` |
| C3 | **IAM y secretos**: `AdministratorAccess` (CKV_AWS_274), política `Action:*`/`Resource:*` (CKV_AWS_1, CKV_AWS_355/62/63, CKV_AWS_286-290, CKV2_AWS_40), secretos en variables de entorno (Trivy secret) | Rol de ejecución de mínimo privilegio (ECR/logs/SSM/KMS por ARN); rol de tarea sin permisos; secretos `DB_PASSWORD`/`API_TOKEN` generados y guardados como SSM `SecureString` (KMS) e inyectados por `secrets` | `54f0232` |
| C4 | **ECR y almacenamiento**: etiquetas mutables (CKV_AWS_51, AWS-0031), sin escaneo (CKV_AWS_163, AWS-0030), sin KMS (CKV_AWS_136, AWS-0033), política pública (CKV_AWS_32, AWS-0032); S3 público (CKV_AWS_20, CKV_AWS_53-56, CKV_AWS_70, AWS-0086/0092/0093), sin cifrado (CKV_AWS_19/145, AWS-0132), sin versionado (CKV_AWS_21, AWS-0090), sin lifecycle/notificaciones (CKV2_AWS_61/62) | ECR `IMMUTABLE` + `scan_on_push` + KMS + lifecycle; se elimina la política pública; S3 con Block Public Access total, cifrado KMS por defecto, versionado, lifecycle y notificaciones | `3238f89`, `66997f5` |
| C5 | **Contenedor**: root (CKV_AWS_22, DS-0002), FS escribible (CKV_AWS_336), imagen mutable `latest` (DS-0001, supply chain) | `user=10001:10001`, `readonlyRootFilesystem=true`, `privileged=false`; imagen por digest/SHA con validación que rechaza `latest`; healthcheck; circuit breaker con rollback | `d9cd6d8` |
| C6 | **CI**: sin compuerta sobre el stack remediado | `checkov/remediated.yaml` + `trivy/remediated.ignore`; `scan.sh`/`security.yml` escanean baseline (informativo), remediado (gate) y secure (gate) | `40d4558` |

## 3. Resultado de los escáneres

| Escáner | Antes (`terraform/baseline`) | Después (`terraform/insecure`) |
|---------|------------------------------|-------------------------------|
| Checkov | **42 failed** / 43 passed | **0 failed** / 124 passed |
| Trivy config | **23** misconfigs (varios HIGH/CRITICAL) | **0** (CRITICAL/HIGH) |
| Trivy secret | **2** (AWS key + GitHub PAT) | **0** |
| Trivy image | **3689** vulns (16 CRITICAL / 313 HIGH) + PAT | **0** (exit 0, base por digest) |

## 4. Excepciones aceptadas (stack remediado)

Se documentan de forma explícita en `checkov/remediated.yaml` y
`trivy/remediated.ignore`; **no** se usa `soft-fail` global:

| ID | Motivo | Riesgo | Control compensatorio |
|----|--------|--------|-----------------------|
| `CKV_AWS_333` | El stack remediado mantiene la arquitectura original (app publicada por IP pública, sin ALB) | IP pública del task expuesta | Ingress limitado al único puerto de app; resto cerrado. El rediseño sin IP pública está en `terraform/secure` |
| `CKV_AWS_144` | Sin replicación cross-region | Pérdida de la región | Region única académica; versionado + KMS |
| `CKV_AWS_18` | Bucket sin access logging propio | Menor trazabilidad de acceso al bucket | Bucket privado, cifrado y versionado; requeriría bucket de logs adicional |
| `AWS-0104` | Egress 443 a `0.0.0.0/0` | Salida amplia | Necesario para ECR/SSM/KMS/Logs; limitado a 443, DNS restringido al CIDR de la VPC |

Cada fila incluye aprobador (`arquitectura-uc`) y fecha de revisión
(`2026-06-30`) en los archivos de configuración.
