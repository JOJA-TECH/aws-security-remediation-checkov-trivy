# Evidencia — stack remediado desplegado (2026-10-14)

Registro del despliegue **después** de aplicar las correcciones in-place sobre
`terraform/insecure` (ver `docs/remediacion.md`). Complementa
`docs/evidencias/insegura-desplegada-2026-10-14.md` (el "antes").

- Cuenta: `948218213402` — Región: `us-east-1`
- Imagen: `948218213402.dkr.ecr.us-east-1.amazonaws.com/insecure-demo-dev-app@sha256:f71f5dd82ace7f3bde4898a55998042506624dbec01ef059e8136e32aaa50f2d`
- Task definition: `insecure-demo-dev-app:3`
- Servicio: `insecure-demo-dev-service` (1/1, `HEALTHY`)
- IP pública del task: `184.192.101.2` (ENI `eni-0175fe1c9cd4231a3`)
- Security group: `sg-07bcdba1adf05d13c`

> Nota: la infraestructura se destruyó y redesplegó (2026-10-14); los
> identificadores anteriores eran `sha256:ff2578...`, task def `:2`, IP
> `13.223.96.23`, SG `sg-0721379f35cb0f6da`.

## 1. Aplicación en ejecución

```
$ curl -s http://184.192.101.2:8080/health
{"app": "insecure-infra-demo", "message": "ok", "version": "6bad1a6", "commit": "6bad1a6", "status": "healthy"}

$ curl -s http://184.192.101.2:8080/
{"app": "insecure-infra-demo", "message": "La aplicacion esta funcionando correctamente", "version": "6bad1a6", "commit": "6bad1a6"}
```

`version`/`commit` ya no es `latest`/`unknown` sino el SHA inmutable de la imagen.

## 2. Hallazgo → control efectivo (evidencia AWS)

| Hallazgo original | Control remediado | Evidencia |
|-------------------|-------------------|-----------|
| SG con 22 y 80 abiertos al mundo | SG `sg-07bcdba1adf05d13c`: ingreso **solo 8080** (descrito); egreso a **443** y **DNS 53 (VPC)** | `describe-security-groups` |
| Subredes con IP pública automática | `map_public_ip_on_launch=false`; el task publica IP de forma explícita | `describe-subnets` |
| Sin logs de flujo | VPC Flow Logs `fl-086b045232ecfe391` **ACTIVE** | `describe-flow-logs` |
| Log group sin retención/KMS | `/ecs/insecure-demo-dev-app` retención **365** + KMS | `describe-log-groups` |
| Sin cifrado (secrets/ECR/logs) | KMS `arn:...:key/50dc5774-...` con **rotación anual** | `get-key-rotation-status` |
| Rol de tarea con `AdministratorAccess` + `Action:*` | Rol de tarea **sin políticas**; rol de ejecución de mínimo privilegio | `list-role-policies` / `get-role-policy` |
| Secretos en variables de entorno | `DB_PASSWORD`/`API_TOKEN` como SSM **SecureString** e inyectados por `secrets` | `describe-task-definition` |
| S3 con ACL `AllUsers` y política pública | S3: Block Public Access total, cifrado **KMS**, versionado, lifecycle, notificaciones; ACL privada | `get-public-access-block` / `get-bucket-encryption` / `get-bucket-acl` |
| ECR mutable, sin escaneo, sin cifrado | ECR: `IMMUTABLE`, `scan_on_push`, cifrado **KMS**, lifecycle, sin política pública | `describe-repositories` |
| Contenedor root, FS escribible, `latest` | task `user=10001:10001`, `readonlyRootFilesystem=true`, `privileged=false`, imagen por **digest** | `describe-task-definition` |
| Sin circuit breaker | Deployment circuit breaker con **rollback** habilitado | `describe-services` |

### Rol de ejecución (mínimo privilegio)

```json
{"Statement":[
 {"Sid":"EcrAuth","Action":"ecr:GetAuthorizationToken","Resource":"*"},
 {"Sid":"EcrPull","Action":["ecr:GetDownloadUrlForLayer","ecr:BatchGetImage","ecr:BatchCheckLayerAvailability"],"Resource":"...:repository/insecure-demo-dev-app"},
 {"Sid":"LogsWrite","Action":["logs:PutLogEvents","logs:CreateLogStream"],"Resource":"...:log-group:/ecs/insecure-demo-dev-app:*"},
 {"Sid":"ReadAppSecrets","Action":["ssm:GetParameters","ssm:GetParameter"],"Resource":["...:parameter/insecure-demo-dev/db/password","...:parameter/insecure-demo-dev/api/token"]},
 {"Sid":"DecryptSecrets","Action":"kms:Decrypt","Resource":"...:key/50dc5774-..."}
]}
```

## 3. Escáneres — después

| Escáner | Objetivo | Resultado |
|---------|----------|-----------|
| Checkov | `terraform/insecure` | **124 passed / 0 failed** (3 hallazgos excepcionados en `checkov/remediated.yaml`) |
| Trivy config | `terraform/insecure` (CRITICAL,HIGH) | **0**, exit 0 |
| Trivy image | imagen corregida (CRITICAL,HIGH, `--ignore-unfixed`) | **0** |
| ECR scan-on-push | imagen `6bad1a6` | sin parche upstream → `--ignore-unfixed` (ver §4) |
| Trivy secret | repo | **0** (los secretos hardcodeados del baseline desaparecieron) |

## 4. Nota sobre la imagen base

La imagen endurecida no tiene dependencias de aplicación (`requirements.txt`
vacío) ni tooling de `pip`; solo queda el SO base (Debian 12.15, `python:3.12-slim`
fijado por digest + `apt-get upgrade`). El escaneo ECR reporta unos pocos CVE de
paquetes del SO (`util-linux`, `glibc`) que **no tienen versión corregida
disponible** en Debian en la fecha del escaneo (`affected`, sin `FixedVersion`).
Por eso la compuerta de CI usa `--ignore-unfixed`: **0 vulnerabilidades
corregibles CRITICAL/HIGH**. Riesgo residual mitigado por el contexto de
ejecución: usuario no-root, FS de solo lectura, sin privilegios, red de ingreso
restringida.
