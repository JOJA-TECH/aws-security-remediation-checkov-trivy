# Lista de comprobación final

Verificación de cada requisito del ejercicio “Corrección de una infraestructura
insegura — Checkov y Trivy”. `✅` cumplido, `📄` evidencia.

## Aplicación

| Requisito | Estado | Evidencia |
|-----------|--------|-----------|
| App mínima (HTTP) | ✅ | `app/src/main.py` |
| Endpoint `/` con mensaje de funcionamiento | ✅ | `main.py` |
| Endpoint `/health` | ✅ | `main.py` |
| Muestra versión/commit | ✅ | `/version`, `APP_VERSION`/`GIT_COMMIT` |
| Dockerfile | ✅ | `app/Dockerfile`, `app/Dockerfile.insecure` |
| Ejecución local con Docker | ✅ | `docker-compose.yml`, README §10 |

## Fase 1 — Insegura

| Problema intencional | Estado | Evidencia |
|----------------------|--------|-----------|
| SG con puerto admin abierto a 0.0.0.0/0 | ✅ | `terraform/insecure/security.tf` (22/80/8080) |
| Contenedor como root | ✅ | `Dockerfile.insecure`, `ecs.tf` (`privileged`) |
| Etiqueta mutable `latest` | ✅ | `variables.tf` + `ecs.tf` |
| IAM excesivamente permisiva (`*`) | ✅ | `iam.tf` (AdministratorAccess + `*/*`) |
| Secreto visible en env/config | ✅ | `ecs.tf`, `Dockerfile.insecure` |
| ECR con etiquetas mutables | ✅ | `ecr.tf` (`MUTABLE`) |
| Almacenamiento público (S3) | ✅ | `storage.tf` (`public-read`, PAB off) |
| Separación insecure/secure | ✅ | `terraform/insecure`, `terraform/secure` |

## Fase 2 — Análisis

| Requisito | Estado | Evidencia |
|-----------|--------|-----------|
| Checkov sobre Terraform | ✅ | `docs/hallazgos-iniciales.md` (42) |
| Trivy imagen + vulnerabilidades | ✅ | `security.yml`, `scripts/scan.sh` |
| Trivy fs (secretos) | ✅ | 2 secretos en `terraform/insecure/ecs.tf` |
| Comandos exactos | ✅ | README §12–13, `docs/*` |

## Fase 3 — Correcciones (≥ 4; se aplican 8)

| Corrección | Estado | Evidencia |
|------------|--------|-----------|
| 1. SGs solo tráfico necesario | ✅ | `terraform/secure/security.tf` |
| 2. Sin acceso admin abierto | ✅ | ídem (no hay puerto 22) |
| 3. Contenedor no privilegiado | ✅ | `Dockerfile`, `ecs.tf` |
| 4. Imagen por SHA/digest | ✅ | `variables.tf` validation, `deploy.yml` |
| 5. ECR inmutable | ✅ | `terraform/secure/ecr.tf` |
| 6. IAM de mínimo privilegio | ✅ | `terraform/secure/iam.tf` |
| 7. Secretos fuera del código | ✅ | `terraform/secure/secrets.tf` (SSM) |
| 8. Bloqueo por vulns críticas/altas | ✅ | `.github/workflows/security.yml` |
| Explicación por corrección | ✅ | `docs/correcciones.md` |

## GitHub Actions

| Requisito | Estado | Evidencia |
|-----------|--------|-----------|
| Workflow de seguridad en PR/push | ✅ | `security.yml` |
| `terraform fmt -check` | ✅ | `security.yml` |
| `terraform validate` | ✅ | `security.yml` |
| Checkov sobre Terraform | ✅ | `security.yml` |
| Build de imagen | ✅ | `security.yml` |
| Trivy sobre imagen | ✅ | `security.yml` |
| Trivy fs | ✅ | `security.yml` |
| Falla ante críticas/altas | ✅ | política en `security.yml` |
| Publica artefactos/logs | ✅ | `upload-artifact` de checkov/trivy |
| Deploy tras seguridad OK | ✅ | `deploy.yml` (`workflow_run`) |
| Tag con SHA + push a ECR | ✅ | `deploy.yml` |
| Terraform + actualización ECS | ✅ | `deploy.yml` |
| Espera servicio estable | ✅ | `aws ecs wait services-stable` |
| Prueba HTTP `/health` | ✅ | `deploy.yml` |
| Muestra URL | ✅ | `deploy.yml` (step summary) |
| OIDC (sin claves estáticas) | ✅ | `bootstrap/`, `deploy.yml` |
| Política IAM mínima + cómo configurarla | ✅ | `bootstrap/iam.tf`, README §8 |

## Terraform

| Requisito | Estado | Evidencia |
|-----------|--------|-----------|
| `versions.tf` | ✅ | insecure/ y secure/ |
| `providers.tf` | ✅ | insecure/ y secure/ |
| `variables.tf` | ✅ | insecure/ y secure/ |
| `outputs.tf` | ✅ | insecure/ y secure/ |
| `main.tf` | ✅ | insecure/ y secure/ |
| Archivos por dominio (red, seguridad, ECR, ECS, IAM) | ✅ | en ambas carpetas |
| Variables de región/nombre/ambiente/imagen/tags | ✅ | `variables.tf`, `locals.tf` |
| Tags Equipo/Proyecto/Ambiente/Responsable | ✅ | `locals.tf` (`common_tags`) |
| Límites de costo (Fargate pequeño, NAT único) | ✅ | `variables.tf`, README §23 |
| Comandos init/validate/plan/apply/destroy | ✅ | README §7, §14, §17, §21 |
| Advertencias de costo | ✅ | README §23 |

## Documentación y evidencias

| Requisito | Estado | Evidencia |
|-----------|--------|-----------|
| `docs/hallazgos-iniciales.md` | ✅ | — |
| `docs/correcciones.md` | ✅ | incluye excepciones |
| `docs/evidencias.md` | ✅ | — |
| README técnico completo (23 secciones) | ✅ | `README.md` |
| Estructura del repositorio | ✅ | README + repo real |
| Guion de demo ≤ 10 min | ✅ | `docs/demo-guion.md` |
| Excepciones justificadas (ID, motivo, riesgo, compensación, aprobador, fecha, comentario) | ✅ | `docs/correcciones.md` + `checkov/secure.yaml` + `trivy/secure.ignore` |

## Validación técnica ejecutada

| Comprobación | Resultado |
|--------------|-----------|
| `terraform fmt -check -recursive` (insecure, secure, bootstrap) | ✅ sin cambios |
| `terraform validate` (insecure, secure, bootstrap) | ✅ Success |
| `checkov -d terraform/secure --config-file checkov/secure.yaml` | ✅ 0 failed (158 passed) |
| `checkov -d terraform/insecure` | ✅ 42 failed (evidencia) |
| `trivy config terraform/secure --ignorefile trivy/secure.ignore` | ✅ exit 0 |
| `trivy config terraform/insecure` | ✅ 23 misconfigs |
| `trivy fs --scanners secret terraform/insecure` | ✅ 2 secretos |
| `trivy fs` (gate sobre rutas seguras) | ✅ exit 0 |
