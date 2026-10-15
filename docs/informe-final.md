# Informe final — Corrección de una infraestructura insegura (Checkov y Trivy)

- **Asignatura:** Infraestructura / DevSecOps
- **Equipo:** `JOJA-TECH` — Responsable: `arquitectura-uc`
- **Repositorio:** https://github.com/JOJA-TECH/aws-security-remediation-checkov-trivy
- **Fecha:** 2026-10-14
- **Cuenta AWS:** `948218213402` — Región `us-east-1`

---

## 1. Objetivo

Partir de una infraestructura **deliberadamente insegura** en AWS (Terraform +
ECS Fargate), desplegarla, detectar sus fallos con **Checkov** y **Trivy**,
**corregirla** de forma trazable (un commit por familia de hallazgos),
**comprobar** que las herramientas quedan en verde, **redesplegarla** y dejar
evidencia de todo el ciclo.

## 2. Qué se construyó

| Carpeta | Propósito |
|---------|-----------|
| `terraform/baseline/` | Stack **vulnerable congelado** (evidencia del "antes"). |
| `terraform/insecure/` | El mismo stack **remediado in-place** por commits (evidencia del "después"). |
| `terraform/secure/` | Rediseño de **referencia productiva** (subredes privadas + ALB + KMS + SSM). |
| `app/` | Aplicación Python mínima (`/` y `/health`), Dockerfile endurecido y `Dockerfile.insecure`. |
| `checkov/`, `trivy-ignore/` | Configuraciones de excepciones justificadas. |
| `scripts/` | `deploy.sh`, `verify.sh`, `scan.sh`. |
| `.github/workflows/` | `security.yml` (escaneo/gate) y `deploy.yml` (OIDC, sin claves estáticas). |
| `bootstrap/` | OIDC de GitHub Actions + backend de estado. |
| `docs/` | Hallazgos, remediación, evidencias, guion de demo, checklist e informe. |

## 3. Arquitectura de la demo

VPC pública (2 AZ) → ECS Fargate (1 tarea) publicando la app directamente por IP
pública del task (sin ALB), ECR para la imagen, S3 para artefactos, CloudWatch
Logs, KMS, SSM Parameter Store y VPC Flow Logs. El stack `secure` demuestra la
versión con **red privada + ALB**.

## 4. Antes (stack inseguro)

Desplegado y verificado en vivo (`http://184.195.170.37:8080/health`,
`version=latest`). Evidencia en `docs/evidencias/insegura-desplegada-2026-10-14.md`.
Hallazgos principales (detalle en `docs/hallazgos-iniciales.md`):

- SG con **22 y 80 abiertos a `0.0.0.0/0`** y egreso sin restringir.
- Subredes con **IP pública automática**; sin VPC Flow Logs.
- Log group **sin retención ni cifrado**.
- Rol de tarea con **`AdministratorAccess`** + política inline `Action:*`.
- **Secretos en texto plano** en variables de entorno (`DB_PASSWORD`, `API_TOKEN`).
- S3 **público** (ACL `AllUsers` + política pública), sin cifrado/versionado.
- ECR **mutable**, sin escaneo, sin cifrado y con política pública.
- Contenedor **root**, FS escribible, imagen **`latest`**.

| Escáner (baseline) | Resultado |
|--------------------|-----------|
| Checkov | **42 failed** / 43 passed |
| Trivy config | **23** misconfigs |
| Trivy secret | **2** (clave AWS + PAT de GitHub) |
| Trivy image | **3689** vulns (16 CRITICAL / 313 HIGH) |

## 5. Corrección (simulación)

La corrección se simula aplicando commits granulares sobre el stack inseguro, y
se demuestra reescaneando. Ver el mapeo completo hallazgo→commit en
`docs/remediacion.md`.

| Commit | Corrección |
|--------|-----------|
| `f1b625f` | SG: quita 22/80, solo 8080; descripciones; egreso 443 + DNS; default SG cerrado |
| `9675497` | KMS con rotación, Container Insights, retención 365 + KMS en logs, VPC Flow Logs, subredes sin IP pública auto |
| `54f0232` | IAM de mínimo privilegio; SSM `SecureString` para secretos |
| `3238f89` | ECR inmutable/escaneado/cifrado; S3 privado/cifrado/versionado/lifecycle |
| `d9cd6d8` | Contenedor no-root, FS solo lectura, secretos por SSM, imagen por digest, circuit breaker |
| `66997f5` | Notificaciones de eventos en S3 |
| `1f5912d` | SG con `create_before_destroy` + ECR `force_delete` (reemplazo sin cortar el servicio) |
| `40d4558` | Compuertas de CI para baseline (informativo), remediado y secure (gate) |

## 6. Después (stack remediado)

Desplegado y verificado en vivo: `http://184.192.101.2:8080/health` →
`{"version":"6bad1a6","commit":"6bad1a6","status":"healthy"}`, servicio ECS
1/1 `HEALTHY`. Escáneres:

| Escáner | Antes | Después |
|---------|-------|---------|
| Checkov | 42 failed | **0 failed** (124 passed) |
| Trivy config | 23 | **0** |
| Trivy secret | 2 | **0** |
| Trivy image (CRITICAL/HIGH, `--ignore-unfixed`) | 3689 | **0** |

Evidencia AWS y comandos en `docs/evidencias/remediada-desplegada-2026-10-14.md`.

## 7. Excepciones aceptadas (justificadas)

Documentadas en `checkov/remediated.yaml` y `trivy-ignore/remediated.ignore`, con
motivo, riesgo, control compensatorio, aprobador y fecha de revisión:

- `CKV_AWS_333` — el stack remediado conserva la arquitectura original (IP
  pública del task, sin ALB). El diseño sin exposición pública es `terraform/secure`.
- `CKV_AWS_144` — sin replicación cross-region (despliegue académico de una región).
- `CKV_AWS_18` — sin access logging propio del bucket (bucket privado/cifrado/versionado).
- `AWS-0104` — egreso 443 a `0.0.0.0/0` (necesario para ECR/SSM/KMS/Logs).

## 8. Cómo reproducir

```bash
# Antes
terraform -chdir=terraform/baseline init && terraform -chdir=terraform/baseline apply
bash scripts/scan.sh            # baseline: informativo

# Después
terraform -chdir=terraform/insecure init
terraform -chdir=terraform/insecure apply -var "image_uri=<imagen@sha256:...>"
bash scripts/verify.sh
bash scripts/scan.sh            # remediado + secure: gate (debe pasar)
```

## 9. Conclusiones

- El ciclo **detectar → corregir → verificar → desplegar** quedó cerrado con
  evidencia real en AWS y con compuertas de CI que impiden reintroducir los fallos.
- Se pasó de **42 hallazgos fallidos + secretos en claro + 3689 CVE** a **0
  fallos, 0 secretos y 0 vulnerabilidades corregibles**.
- Las correcciones se aplicaron de forma **trazable** (un commit por familia),
  sin romper el servicio (reemplazo del SG con `create_before_destroy`).
- El riesgo residual está **enumerado, justificado y aprobado**, no oculto tras
  `soft-fail`.
