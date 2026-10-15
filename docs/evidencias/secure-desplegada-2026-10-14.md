# Evidencia — stack seguro desplegado por CI (2026-10-14)

Registro del despliegue del stack `terraform/secure/` **desde GitHub Actions**
(`Deploy`), autenticado contra AWS por **OIDC** (sin claves estáticas). Es el
"después" de referencia productiva (subredes privadas + ALB).

- Cuenta: `948218213402` — Región: `us-east-1`
- Clúster ECS: `secure-demo-dev` · Servicio: `secure-demo-dev-service` (`ACTIVE`, 1/1)
- Task definition: `secure-demo-dev-app:3`
- Imagen: `948218213402.dkr.ecr.us-east-1.amazonaws.com/secure-demo-dev-app@sha256:3d4a14c978b7bffef51770068b5f4fcf49f8c2688715dc9d5ad863a712c31405`
- ALB: `secure-demo-dev-alb-369160995.us-east-1.elb.amazonaws.com`
- Security group de la app: `sg-04807b4f380ebbc93`
- KMS CMK: `arn:aws:kms:us-east-1:948218213402:key/9ac9b9fa-8c57-40b4-a013-56f9d581fedd`
- Bucket de access logs del ALB: `secure-demo-dev-alb-logs-948218213402`
- State backend: `aws-security-remediation-checkov-trivy-tfstate-948218213402` + `aws-security-remediation-checkov-trivy-tflock`

## 1. Salidas de Terraform (`terraform output`)

```
alb_dns_name        = "secure-demo-dev-alb-369160995.us-east-1.elb.amazonaws.com"
app_url             = "http://secure-demo-dev-alb-369160995.us-east-1.elb.amazonaws.com"
health_url          = "http://secure-demo-dev-alb-369160995.us-east-1.elb.amazonaws.com/health"
ecr_repository_url  = "948218213402.dkr.ecr.us-east-1.amazonaws.com/secure-demo-dev-app"
ecs_cluster_name    = "secure-demo-dev"
ecs_service_name    = "secure-demo-dev-service"
app_security_group_id = "sg-04807b4f380ebbc93"
kms_key_arn         = "arn:aws:kms:us-east-1:948218213402:key/9ac9b9fa-8c57-40b4-a013-56f9d581fedd"
alb_logs_bucket     = "secure-demo-dev-alb-logs-948218213402"
```

## 2. Estado del servicio ECS

```
$ aws ecs describe-services --cluster secure-demo-dev --services secure-demo-dev-service \
    --query "services[0].[status,runningCount,desiredCount,taskDefinition]" --output text
ACTIVE  1  1  arn:aws:ecs:us-east-1:948218213402:task-definition/secure-demo-dev-app:3
```

## 3. Verificación en vivo

```
$ curl -fsS http://secure-demo-dev-alb-369160995.us-east-1.elb.amazonaws.com/health
{"app": "insecure-infra-demo", "message": "ok", "version": "327cf364f40532a9901f9e0c1e1f068a309c88c5", "commit": "327cf364f40532a9901f9e0c1e1f068a309c88c5", "status": "healthy"}

$ curl -fsS http://secure-demo-dev-alb-369160995.us-east-1.elb.amazonaws.com/
{"app": "insecure-infra-demo", "message": "La aplicacion esta funcionando correctamente", "version": "327cf364f40532a9901f9e0c1e1f068a309c88c5", "commit": "327cf364f40532a9901f9e0c1e1f068a309c88c5"}
```

`version`/`commit` es el SHA inmutable de la imagen (ya no `latest`). El workflow
`Deploy` prueba `/health` en el pipeline tras `aws ecs wait services-stable`; el
job pasó en el primer intento.

## 4. Flujo CI/CD

```
git push (main) → security.yml (fmt, validate, Checkov, Trivy) → OK
               → deploy.yml → build+push (tag SHA-RUN)
                            → terraform apply (state remoto S3+DynamoDB)
                            → aws ecs wait services-stable
                            → curl /health (health check del ALB)
```

## 5. Incidentes reales y su corrección

1. **OIDC sin rol** — el primer `Deploy` falló en *Configure AWS credentials*
   porque el bootstrap se había destruido (no existía el rol). Se re-provisionó
   `bootstrap/` (proveedor OIDC + rol + backend de estado) y se configuraron en
   GitHub el secreto `AWS_ROLE_ARN` y las variables `TF_STATE_BUCKET`,
   `TF_LOCK_TABLE`, `AWS_REGION`.
2. **Permisos del rol incompletos** — se completó `bootstrap/iam.tf` con los
   permisos realmente necesarios (KMS data-plane + grants, `iam:PassRole`,
   configuración de S3/ECR, describes de EC2/ELB, `ssm:DescribeParameters` sobre
   `*`). Commits `78fa2dd`, `ab9e77f`.
3. **ECR inmutable + tag repetido** — el repositorio es `IMMUTABLE`; se cambió el
   tag de la imagen a `<SHA>-<RUN_NUMBER>` para que cada push sea único.
   Commit `78fa2dd`.

## 6. Reconciliación con la ejecución anterior

`docs/evidencias/ejecucion-2026-10-14.md` documenta una ejecución **manual**
anterior que terminó con `terraform destroy` (el DNS del ALB era
`secure-demo-dev-alb-765800279...`). Este documento registra el **redespliegue
por CI** posterior; el DNS del ALB cambió al recrearse (`...369160995...`).
