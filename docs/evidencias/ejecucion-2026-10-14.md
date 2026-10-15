# Evidencia de ejecución real

Fecha: 2026-10-14 · Cuenta AWS: `948218213402` · Región: `us-east-1` · CLI: aws-cli 1.46

> **Nota:** esta ejecución **manual** terminó con `terraform destroy` (el DNS del
> ALB era `secure-demo-dev-alb-765800279...`). Con posterioridad la
> infraestructura se **redesplegó desde CI** (OIDC); el estado actual y el DNS
> vigente están en `docs/evidencias/secure-desplegada-2026-10-14.md`.

Ejecución completa del ejercicio contra AWS real, incluido el ciclo de vida
(`apply` → verificación → `destroy`). Comandos y resultados observados.

## 0. Flujo de seguridad local (`scripts/scan.sh`) — exit 0

| Escáner | Objetivo | Resultado |
|---------|----------|-----------|
| `terraform fmt -check -recursive` | baseline, remediated, secure | sin cambios |
| `terraform validate` | baseline, remediated, secure | Success |
| Checkov | `terraform/baseline` | **42 failed** / 43 passed / 0 skipped |
| Checkov (`checkov/remediated.yaml`) | `terraform/insecure` (remediado) | **0 failed** / 124 passed |
| Checkov (`checkov/secure.yaml`) | `terraform/secure` | **0 failed** / 157 passed |
| Trivy config | `terraform/baseline` | múltiples HIGH (S3 público, SG abiertos, IAM, etc.) |
| Trivy config (`trivy-ignore/remediated.ignore`) | `terraform/insecure` (remediado) | **0** (exit 0) |
| Trivy config (`trivy-ignore/secure.ignore`) | `terraform/secure` | **0** (exit 0) |
| Trivy fs secretos | baseline / remediated / secure | 2 secretos / 0 / 0 |
| Trivy image | insegura (`python:latest`, root) | **3689 vulns** (16 CRITICAL, 313 HIGH) + PAT |
| Trivy image | segura (base pin por digest, sin pip) | **0** (exit 0) |

## 1. `bootstrap` apply

```
Apply complete! Resources: 9 added
github_actions_role_arn = arn:aws:iam::948218213402:role/github-actions-aws-remediation
oidc_provider_arn       = arn:aws:iam::948218213402:oidc-provider/token.actions.githubusercontent.com
tfstate_bucket          = aws-security-remediation-checkov-trivy-tfstate-948218213402
tflock_table            = aws-security-remediation-checkov-trivy-tflock
```

## 2. Deploy seguro (`scripts/deploy.sh dev`)

Incidente real encontrado y corregido durante el despliegue:

```
Error: modifying ELBv2 Load Balancer attributes:
InvalidConfigurationRequest: Access Denied for bucket:
secure-demo-dev-alb-logs-948218213402. Please check S3bucket permission
```

**Causa raíz:** el bucket usaba SSE-KMS (CMK) y **la entrega de access logs del
ALB no soporta SSE-KMS**, solo SSE-S3. Corrección: bucket a `AES256`; excepción
`CKV_AWS_145`/`AWS-0132` documentada. Commit `8295845`.

Resultado tras la corrección:

```
Apply complete! Resources: 3 added, 2 changed, 1 destroyed
alb_dns_name = secure-demo-dev-alb-765800279.us-east-1.elb.amazonaws.com
health_url   = http://secure-demo-dev-alb-765800279.us-east-1.elb.amazonaws.com/health
```

## 3. Verificación en vivo

```
$ aws ecs describe-services ... secure-demo-dev-service
status=ACTIVE  runningCount=1  desiredCount=1
taskDefinition=.../secure-demo-dev-app:1

$ curl -fsS http://secure-demo-dev-alb-765800279.us-east-1.elb.amazonaws.com/health
{"app":"insecure-infra-demo","message":"ok","version":"c589d00","commit":"c589d00","status":"healthy"}

$ curl -fsS http://.../  -> {"message":"La aplicacion esta funcionando correctamente", ...}

$ aws elbv2 describe-target-health ... -> healthy
```

Propiedades de seguridad observadas:

| Control | Evidencia |
|---------|-----------|
| ECR inmutable | `imageTagMutability=IMMUTABLE`, `scanOnPush=true`, `encryptionType=KMS` |
| Imagen pinneada | `image = ...@sha256:9b2ba92b...` (tag = SHA `c589d00`) |
| Contenedor sin root | `user=10001:10001`, `privileged=false`, `readonlyRootFilesystem=true` |
| Secretos gestionados | `secrets` desde SSM `SecureString` con CMK (`/secure-demo-dev/db/password`, `/api/token`) |
| SG mínimo | app SG: 8080 **solo** desde SG del ALB; SG default sin ingress; ALB SG: 80 desde 0.0.0.0/0 |
| Flow logs | `FlowLogs` estado `ACTIVE`, tráfico `ALL` |
| ALB access logs | `alb/AWSLogs/948218213402/ELBAccessLogTestFile` + log real entregado |
| Checkov secure | 0 failed / 157 passed |

## 4. Destrucción total (`terraform destroy`)

```
terraform/secure : Destroy complete! Resources: 23 destroyed
bootstrap        : Destroy complete! Resources:  9 destroyed
```

Verificación posterior (todo vacío): ECR, ECS, S3, IAM, OIDC, ALB, NAT (estado
`deleted`), EIP, SSM, KMS, DynamoDB, CloudWatch Log Groups. No quedan recursos
de la solución ni costos asociados.
