# Hallazgos iniciales — infraestructura insegura

Este documento registra los hallazgos obtenidos al analizar la carpeta
`terraform/insecure/` y el `Dockerfile.insecure` con **Checkov** y **Trivy**.
Los resultados fueron reproducidos localmente; los números que aparecen aquí
corresponden a las versiones indicadas.

## 1. Metodología y comandos

```bash
# Checkov sobre la infraestructura insegura (todos los hallazgos visibles)
checkov -d terraform/insecure --framework terraform

# Checkov sobre la infraestructura corregida (debe quedar en 0)
checkov -d terraform/secure --framework terraform --config-file .checkov.yaml

# Trivy: misconfiguración de IaC
trivy config terraform/insecure
trivy config terraform/secure --ignorefile .trivyignore

# Trivy: secretos en el repositorio
trivy fs --scanners secret,misconfig terraform/insecure

# Trivy: vulnerabilidades de la imagen construida
docker build -f app/Dockerfile.insecure -t insecure-demo:ci ./app
trivy image --severity CRITICAL,HIGH insecure-demo:ci

# Trivy sobre todo el repositorio
trivy fs .
```

Versiones usadas para generar esta evidencia:

| Herramienta | Versión |
|-------------|---------|
| Checkov     | 3.2.x / 3.3.x |
| Trivy       | 0.5x / 0.76.x |
| Terraform   | 1.9.x / 1.15.x |

## 2. Resumen cuantitativo

| Escáner | Objetivo | Hallazgos |
|---------|----------|-----------|
| Checkov `terraform` | `terraform/insecure` | **42 FAILED** (43 passed, 23 recursos) |
| Trivy `config` | `terraform/insecure` | **23 misconfigurations** |
| Trivy `secret` | `terraform/insecure/ecs.tf` | **2 secrets** (AWS key + GitHub PAT) |
| Trivy `config`/`fs` | `app/Dockerfile.insecure` | **5 misconfigurations** (ver §5) |
| Trivy `image` | `insecure-demo:ci` | Se ejecuta en el pipeline (ver §6) |

## 3. Hallazgos de Checkov (`terraform/insecure`)

42 controles fallidos. Se listan agrupados por configuración intencional.
`—` indica que la versión de Checkov no expone severidad para ese control.

### 3.1 Grupo de seguridad / red

| Control | Nombre | Recurso |
|---------|--------|---------|
| CKV_AWS_24 | No ingress 0.0.0.0/0 a puerto 22 (SSH) | `aws_security_group.app` |
| CKV_AWS_260 | No ingress 0.0.0.0/0 a puerto 80 | `aws_security_group.app` |
| CKV_AWS_23 | Cada SG y regla debe tener descripción | `aws_security_group.app` |
| CKV_AWS_382 | No egress 0.0.0.0/0 en puertos sensibles | `aws_security_group.app` |
| CKV_AWS_130 | Subredes no deberían asignar IP pública por defecto | `aws_subnet.public[0..1]` |
| CKV2_AWS_11 | Flow Logs habilitados en la VPC | `aws_vpc.main` |
| CKV2_AWS_12 | El SG por defecto debe restringir todo el tráfico | `aws_vpc.main` |

### 3.2 IAM excesivamente permisivo

| Control | Nombre | Recurso |
|---------|--------|---------|
| CKV2_AWS_40 | Política IAM con privilegios IAM completos | `aws_iam_role_policy.task_wildcard` |
| CKV_AWS_274 | Uso de políticas administradas por AWS (`AdministratorAccess`) | `aws_iam_role_policy_attachment.task_admin` |
| CKV_AWS_286 | Prevención de escalada de privilegios | `aws_iam_role_policy.task_wildcard` |
| CKV_AWS_287 | Exposición de credenciales | `aws_iam_role_policy.task_wildcard` |
| CKV_AWS_288 | Exfiltración de datos | `aws_iam_role_policy.task_wildcard` |
| CKV_AWS_289 | Gestión de permisos | `aws_iam_role_policy.task_wildcard` |
| CKV_AWS_290 | Escritura sin restricciones | `aws_iam_role_policy.task_wildcard` |
| CKV_AWS_355 | `Resource: "*"` en política | `aws_iam_role_policy.task_wildcard` |
| CKV_AWS_62 | Política administrativa `*-*` completa | `aws_iam_role_policy.task_wildcard` |
| CKV_AWS_63 | `Action: "*"` en política | `aws_iam_role_policy.task_wildcard` |

### 3.3 ECR

| Control | Nombre | Recurso |
|---------|--------|---------|
| CKV_AWS_51 | Etiquetas de imagen inmutables | `aws_ecr_repository.app` |
| CKV_AWS_163 | Escaneo en push habilitado | `aws_ecr_repository.app` |
| CKV_AWS_136 | Encriptación con KMS administrado por el cliente | `aws_ecr_repository.app` |
| CKV_AWS_32 | Política de ECR no pública | `aws_ecr_repository_policy.app_public` |

### 3.4 ECS / contenedores / logs

| Control | Nombre | Recurso |
|---------|--------|---------|
| CKV_AWS_65 | Container Insights habilitado en el cluster | `aws_ecs_cluster.main` |
| CKV_AWS_333 | Servicios ECS sin IP pública asignada | `aws_ecs_service.app` |
| CKV_AWS_66 | Retención de logs especificada | `aws_cloudwatch_log_group.app` |
| CKV_AWS_158 | Log group encriptado con KMS | `aws_cloudwatch_log_group.app` |
| CKV_AWS_338 | Retención de logs ≥ 1 año | `aws_cloudwatch_log_group.app` |

### 3.5 Almacenamiento (S3 público)

| Control | Nombre | Recurso |
|---------|--------|---------|
| CKV_AWS_20 | ACL pública de lectura | `aws_s3_bucket.artifacts` |
| CKV_AWS_379 | ACL no segura / transporte de datos | `aws_s3_bucket_acl.artifacts` |
| CKV2_AWS_6 | Falta Public Access Block | `aws_s3_bucket.artifacts` |
| CKV_AWS_53 | `block_public_acls` | `aws_s3_bucket_public_access_block.artifacts` |
| CKV_AWS_54 | `block_public_policy` | `aws_s3_bucket_public_access_block.artifacts` |
| CKV_AWS_55 | `ignore_public_acls` | `aws_s3_bucket_public_access_block.artifacts` |
| CKV_AWS_56 | `restrict_public_buckets` | `aws_s3_bucket_public_access_block.artifacts` |
| CKV_AWS_70 | Política con `Principal: "*"` | `aws_s3_bucket_policy.artifacts_public` |
| CKV_AWS_19 / CKV_AWS_145 | Encriptación (por defecto / KMS) | `aws_s3_bucket.artifacts` |
| CKV_AWS_18 | Access logging | `aws_s3_bucket.artifacts` |
| CKV_AWS_21 | Versionado | `aws_s3_bucket.artifacts` |
| CKV_AWS_144 | Replicación cross-region | `aws_s3_bucket.artifacts` |
| CKV2_AWS_61 | Lifecycle | `aws_s3_bucket.artifacts` |
| CKV2_AWS_62 | Event notifications | `aws_s3_bucket.artifacts` |
| CKV2_AWS_65 | ACLs deshabilitadas | `aws_s3_bucket_ownership_controls.artifacts` |

## 4. Hallazgos de Trivy `config` (`terraform/insecure`)

23 misconfiguraciones:

| ID | Severidad | Descripción | Archivo |
|----|-----------|-------------|---------|
| AWS-0104 | CRITICAL | Egress sin restricción a 0.0.0.0/0 | `security.tf` |
| AWS-0107 | HIGH | Ingress sin restricción a SSH (22) | `security.tf` |
| AWS-0030 | HIGH | Escaneo de imágenes ECR deshabilitado | `ecr.tf` |
| AWS-0031 | HIGH | Etiquetas ECR mutables | `ecr.tf` |
| AWS-0032 | HIGH | Política de ECR con acceso público | `ecr.tf` |
| AWS-0164 | HIGH x2 | Subred asigna IP pública | `network.tf` |
| AWS-0086 | HIGH | S3 block public ACL deshabilitado | `storage.tf` |
| AWS-0087 | HIGH | S3 block public policy deshabilitado | `storage.tf` |
| AWS-0091 | HIGH | S3 ignore public ACL deshabilitado | `storage.tf` |
| AWS-0092 | HIGH | S3 accesible públicamente vía ACL | `storage.tf` |
| AWS-0093 | HIGH | S3 restrict public bucket deshabilitado | `storage.tf` |
| AWS-0132 | HIGH | S3 sin clave KMS administrada | `storage.tf` |
| AWS-0017 | LOW | Log group sin CMK | `main.tf` |
| AWS-0033 | LOW | ECR sin CMK | `ecr.tf` |
| AWS-0034 | LOW | ECS sin Container Insights | `main.tf` |
| AWS-0090 | MEDIUM | S3 sin versionado | `storage.tf` |
| AWS-0124 | LOW x4 | Reglas de SG sin descripción | `security.tf` |
| AWS-0178 | MEDIUM | VPC Flow Logs deshabilitados | `network.tf` |
| AWS-0089 | LOW | S3 sin access logging | `storage.tf` |

## 5. Hallazgos de Trivy sobre el Dockerfile inseguro

`Dockerfile.insecure` — 5 misconfiguraciones:

| ID | Severidad | Descripción |
|----|-----------|-------------|
| DS-0031 | CRITICAL x4 | Secretos pasados como variables de entorno |
| DS-0002 | HIGH | La imagen se ejecuta como `root` |
| DS-0001 | MEDIUM | Se usa la etiqueta mutable `latest` |
| DS-0026 | LOW | No existe `HEALTHCHECK` |

## 6. Secretos detectados (Trivy secret)

`trivy fs --scanners secret terraform/insecure/ecs.tf` reporta **2 secretos**:

| Regla | Severidad | Ubicación | Valor (ficticio) |
|-------|-----------|-----------|------------------|
| AWS `aws-access-key-id` | CRITICAL | `ecs.tf` línea del `AWS_ACCESS_KEY_ID` | `AKIAFAKEKEY123456789` |
| GitHub `github-pat` | CRITICAL | `ecs.tf` línea del `API_TOKEN` | `ghp_FAKEfakeFAKEfake1234567890abcdefghij` |

> Todos los valores son **ficticios** y están marcados como inseguros en el
> propio código. No existe ninguna credencial real.

## 7. Hallazgos de Trivy `image` (imagen insegura)

El pipeline ejecuta:

```bash
trivy image --severity CRITICAL,HIGH insecure-demo:ci
```

Resultado **esperado** (debe verificarse en la demostración, ya que la imagen
depende de la base `python:latest` en el momento del build):

- Vulnerabilidades `CRITICAL`/`HIGH` del sistema operativo de la imagen base
  `python:latest` (Debian), típicamente decenas de CVEs.
- El contenedor está configurado como `root` (DS-0002) y con la etiqueta
  `latest` (DS-0001).
- Secretos embebidos como variables de entorno (detectados por Trivy config,
  no por el scanner de secretos, que no procesa Dockerfiles).

Comando de verificación y evidencia:

```bash
docker build -f app/Dockerfile.insecure -t insecure-demo:ci ./app
trivy image --severity CRITICAL,HIGH insecure-demo:ci | tee docs/evidencias/trivy-image-insecure.txt
```

> Nota: este entorno de generación no disponía de un daemon de Docker activo,
> por lo que el escaneo de imagen no pudo ejecutarse aquí. El pipeline y el
> script `scripts/scan.sh` sí lo ejecutan. No se inventan conteos de CVEs.

## 8. Relación entre hallazgos y problemas intencionales

| # | Problema intencional | Evidencia principal |
|---|----------------------|---------------------|
| 1 | Puerto administrativo (22) abierto a 0.0.0.0/0 | CKV_AWS_24, AWS-0107 |
| 2 | Contenedor como `root` | DS-0002 |
| 3 | Etiqueta mutable `latest` | DS-0001, CKV_AWS_51 (ECR), AWS-0031 |
| 4 | IAM excesivamente permisiva (`*`/`*`, AdministratorAccess) | CKV2_AWS_40, CKV_AWS_274/355/62, CKV_AWS_286-290 |
| 5 | Secretos visibles en variables de entorno | Trivy secret (2), DS-0031 |
| 6 | ECR con etiquetas mutables y sin escaneo | CKV_AWS_51, CKV_AWS_163, AWS-0030/0031 |
| 7 | Almacenamiento público (S3 public-read) | CKV_AWS_20, CKV_AWS_53-56, AWS-0086/0092/0093 |
