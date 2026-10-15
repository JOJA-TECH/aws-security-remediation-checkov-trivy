# Guion de demostración (máximo 10 minutos)

Preparación previa (fuera del tiempo): `bootstrap` aplicado, repositorio con
`AWS_ROLE_ARN`/variables configuradas, herramientas instaladas, imagen base
pre-descargada.

| Tiempo | Bloques | Acción | Evidencia a mostrar |
|--------|---------|--------|---------------------|
| 0:00–1:00 | Intro | Enunciar objetivo y mostrar el diagrama Mermaid del README. | `README.md` §3–4 |
| 1:00–3:00 | Insegura + Checkov | Mostrar 2–3 anti-patrones en `terraform/baseline` (SG 22 abierto, IAM `*/*`, ECR `MUTABLE`, S3 `public-read`). Ejecutar `checkov -d terraform/baseline --framework terraform`. | 42 FAILED; `docs/hallazgos-iniciales.md` |
| 3:00–4:00 | Trivy config + secret | `trivy config terraform/baseline` y `trivy fs --scanners secret terraform/baseline`. | 23 misconfigs; 2 secretos (AWS key + GitHub PAT) |
| 4:00–5:00 | Trivy imagen insegura | `docker build -f app/Dockerfile.insecure -t insecure-demo:ci ./app` + `trivy image --severity CRITICAL,HIGH insecure-demo:ci`. | CVEs OS + DS-0002/DS-0001 |
| 5:00–6:30 | Remediación in-place + escáneres | Mostrar los commits de corrección sobre `terraform/insecure` y ejecutar `checkov -d terraform/insecure --config-file checkov/remediated.yaml` y `trivy config terraform/insecure --ignorefile trivy-ignore/remediated.ignore`. | Checkov `Failed: 0`; Trivy exit 0; `docs/remediacion.md` |
| 6:30–7:00 | Rediseño de referencia | Mostrar `terraform/secure` (subredes privadas + ALB + KMS + SSM) y su gate limpio. | Checkov `Failed: 0`; `docs/correcciones.md` |
| 7:00–8:00 | Pipeline bloqueado | Abrir un PR que cambie `image_tag_mutability = "MUTABLE"` (o use `:latest`). | `Security` en rojo; `Deploy` no se ejecuta |
| 8:00–9:00 | Pipeline exitoso + ECR | Revertir, merge a `main`. Mostrar `Security` verde y `Deploy` verde. `aws ecr describe-repositories ... imageTagMutability`. | `IMMUTABLE`; imagen con tag = SHA |
| 9:00–9:30 | ECS + endpoint | `aws ecs describe-services ... --query 'services[0].{status,running,desired}'` y `scripts/verify.sh <health_url>`. | `ACTIVE`, 1/1; JSON `"status":"healthy"` |
| 9:30–10:00 | Destruir + cierre | `terraform destroy` en `terraform/secure` y `bootstrap`. | Salida de destroy; consola sin recursos |

## Puntos de mensaje clave

- Se corrigen **8 controles** (más de los 4 exigidos) con evidencia por escáner.
- Las excepciones son **explícitas y específicas** (`checkov/secure.yaml`,
  `trivy-ignore/secure.ignore`), nunca `soft-fail` global.
- Autenticación **OIDC**: sin claves AWS almacenadas.
- Despliegue por **digest inmutable** con circuit breaker y prueba `/health`.

## Comandos de la demo (copiar/pegar)

```bash
# Insegura (baseline congelado)
checkov -d terraform/baseline --framework terraform
trivy config terraform/baseline
trivy fs --scanners secret terraform/baseline
docker build -f app/Dockerfile.insecure -t insecure-demo:ci ./app
trivy image --severity CRITICAL,HIGH insecure-demo:ci

# Remediada in-place
checkov -d terraform/insecure --framework terraform --config-file checkov/remediated.yaml
trivy config --ignorefile trivy-ignore/remediated.ignore --severity CRITICAL,HIGH --exit-code 1 terraform/insecure

# Rediseño de referencia
checkov -d terraform/secure --framework terraform --config-file checkov/secure.yaml
trivy config --ignorefile trivy-ignore/secure.ignore --severity CRITICAL,HIGH --exit-code 1 terraform/secure
docker build -t secure-demo:ci ./app
trivy image --severity CRITICAL,HIGH --ignore-unfixed --exit-code 1 secure-demo:ci

# Operación
scripts/deploy.sh dev
scripts/verify.sh "$(cd terraform/secure && terraform output -raw health_url)"
cd terraform/secure && terraform destroy -var "image_uri=<digest>"
```
