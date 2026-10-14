# Correcciones aplicadas

Cada corrección sigue el mismo formato: **configuración insegura original →
hallazgo → cambio aplicado → razón de seguridad → evidencia**. La
infraestructura corregida vive en `terraform/secure/` y el Dockerfile seguro en
`app/Dockerfile`.

---

## C1. Grupos de seguridad restringidos al tráfico necesario

- **Original:** `aws_security_group.app` con ingress a los puertos `22`, `80` y
  `8080` desde `0.0.0.0/0`, egress `-1` abierto y sin descripciones.
- **Hallazgo:** `CKV_AWS_23`, `CKV_AWS_24`, `CKV_AWS_260`, `CKV_AWS_382`;
  Trivy `AWS-0104` (CRITICAL), `AWS-0107` (HIGH), `AWS-0124` (LOW).
- **Cambio:** en `terraform/secure/security.tf` el puerto de la aplicación solo
  acepta tráfico **del security group del ALB**
  (`referenced_security_group_id`). El egress se limita a `443/tcp` hacia
  Internet y a DNS (`53/udp` y `53/tcp`) hacia la CIDR de la VPC. Todas las
  reglas y grupos tienen `description`.
- **Razón:** eliminar superficie de ataque y aplicar el principio de mínima
  exposición. La aplicación no debe ser alcanzable salvo a través del balanceador.
- **Evidencia:** `terraform/secure/security.tf`; Checkov sobre `terraform/secure`
  sin hallazgos de SG; `trivy config terraform/secure` limpio.

## C2. Eliminación del acceso administrativo abierto

- **Original:** ingress SSH `22` desde `0.0.0.0/0`.
- **Hallazgo:** `CKV_AWS_24`, Trivy `AWS-0107` (HIGH).
- **Cambio:** no existe ningún puerto administrativo abierto. El acceso
  operativo se realiza por **ECS Exec / SSM Session Manager** (gestión sin
  puertos entrantes), y el único ingress público es `80` en el ALB.
- **Razón:** SSH expuesto a Internet es uno de los vectores de intrusión más
  explotados; se elimina por completo.
- **Evidencia:** `terraform/secure/security.tf` (no hay regla `22`);
  `aws_security_group.app` solo con puerto de app.

## C3. Contenedor como usuario no privilegiado

- **Original:** `Dockerfile.insecure` sin `USER` (root) y task definition con
  `privileged = true` y `readonlyRootFilesystem = false`.
- **Hallazgo:** Trivy `DS-0002` (HIGH). Nota: el contenedor `root` también
  amplía el impacto de cualquier RCE.
- **Cambio:**
  - `app/Dockerfile` crea el usuario `app` (UID/GID `10001`) y termina con
    `USER 10001:10001`.
  - `terraform/secure/ecs.tf` fija `user = "10001:10001"`,
    `readonlyRootFilesystem = true` y `privileged = false`.
- **Razón:** reducir privilegios dentro del contenedor y hacer el sistema de
  archivos de solo lectura limita la escalada y la persistencia.
- **Evidencia:** `app/Dockerfile` y `terraform/secure/ecs.tf`; `trivy config`
  del Dockerfile seguro sin `DS-0002`.

## C4. Imagen identificada por SHA de commit / digest inmutable

- **Original:** task definition desplegaba `...:latest`.
- **Hallazgo:** Trivy `DS-0001` (MEDIUM); Checkov/Trivy sobre políticas de
  etiquetas mutables (`CKV_AWS_51`, `AWS-0031`).
- **Cambio:** la variable `image_uri` en `terraform/secure/variables.tf` valida
  que **no** termine en `:latest` y que contenga `@sha256:` o un tag tipo SHA.
  El workflow de deploy publica con el SHA del commit y **despliega por digest**.
- **Razón:** una referencia inmutable garantiza reproducibilidad y evita
  “dependency confusion”/mutación de la imagen desplegada.
- **Evidencia:** `terraform/secure/variables.tf` (bloques `validation`);
  `.github/workflows/deploy.yml` (paso que resuelve el digest).

## C5. ECR con etiquetas inmutables, escaneo y KMS

- **Original:** `image_tag_mutability = "MUTABLE"`, `scan_on_push = false`,
  encriptación `AES256` y política con `Principal: "*"`.
- **Hallazgo:** `CKV_AWS_51`, `CKV_AWS_163`, `CKV_AWS_136`, `CKV_AWS_32`;
  Trivy `AWS-0030`, `AWS-0031`, `AWS-0032` (HIGH), `AWS-0033` (LOW).
- **Cambio:** `terraform/secure/ecr.tf` usa
  `image_tag_mutability = "IMMUTABLE"`, `scan_on_push = true`,
  `encryption_type = "KMS"` con la clave administrada, y una política de ciclo
  de vida. No hay política de repositorio pública (el acceso se controla por IAM).
- **Razón:** impedir sobrescrituras de imágenes, detectar vulnerabilidades en
  el registro y cifrar el contenido en reposo con clave propia.
- **Evidencia:** `terraform/secure/ecr.tf`; salida de Checkov limpia.

## C6. Permisos mínimos mediante IAM

- **Original:** rol de tarea con `AdministratorAccess` y política inline
  `Action: "*"`, `Resource: "*"`.
- **Hallazgo:** `CKV2_AWS_40`, `CKV_AWS_274`, `CKV_AWS_355`, `CKV_AWS_62`,
  `CKV_AWS_286..290`.
- **Cambio:** en `terraform/secure/iam.tf`:
  - El **rol de ejecución** tiene una política inline con acciones concretas
    (`ecr:*` del repositorio, `logs:*` del log group, `ssm:GetParameter(s)` de
    los parámetros propios, `kms:Decrypt` de la clave propia).
  - El **rol de tarea** no tiene permisos adjuntos (la aplicación no necesita
    APIs de AWS).
  - El rol de GitHub Actions (en `bootstrap/`) está acotado por servicio y,
    cuando la API lo permite, por ARN; `iam:PassRole` se restringe a
    `ecs-tasks.amazonaws.com` y a roles `secure-demo-*`.
- **Razón:** el principio de menor privilegio acota el impacto de un compromiso.
- **Evidencia:** `terraform/secure/iam.tf`, `bootstrap/iam.tf`; Checkov limpio.

## C7. Secretos fuera del código (SSM SecureString)

- **Original:** `DB_PASSWORD`, `API_TOKEN`, `AWS_ACCESS_KEY_ID`,
  `AWS_SECRET_ACCESS_KEY` en texto plano (Dockerfile, task definition y `.tf`).
- **Hallazgo:** Trivy secret (`aws-access-key-id` y `github-pat`, CRITICAL);
  Trivy `DS-0031` (CRITICAL).
- **Cambio:** `terraform/secure/secrets.tf` genera los valores con
  `random_password` en tiempo de `apply` y los guarda como
  **SSM Parameter Store `SecureString`** cifrados con la CMK. La task definition
  los inyecta con el bloque `secrets`/`valueFrom` en runtime.
- **Razón:** no versionar secretos; rotarlos y controlarlos de forma centralizada.
- **Evidencia:** `terraform/secure/secrets.tf`, `terraform/secure/ecs.tf`;
  `trivy fs --scanners secret` limpio en rutas seguras.

## C8. Bloqueo del despliegue ante vulnerabilidades críticas/altas

- **Original:** no existía pipeline de seguridad; se desplegaba directamente.
- **Hallazgo:** riesgo organizacional (no detectado por una herramienta).
- **Cambio:** `.github/workflows/security.yml` falla el pipeline si:
  - `terraform fmt -check` o `terraform validate` fallan,
  - Checkov reporta **cualquier** control fallido en `terraform/secure`
    (las excepciones deben ser skips específicos en `.checkov.yaml`),
  - Trivy (imagen) encuentra vulnerabilidades `CRITICAL`/`HIGH` **con fix
    disponible**,
  - Trivy fs detecta secretos o misconfiguraciones `CRITICAL`/`HIGH` en las
    rutas seguras.
  El workflow `deploy.yml` solo se ejecuta si `Security` termina en éxito.
- **Razón:** “shift-left” y control de calidad de seguridad como compuerta.
- **Evidencia:** `.github/workflows/security.yml` y `deploy.yml`; artefactos
  `checkov-results` y `trivy-results`.

## Correcciones adicionales (más allá del mínimo)

- **Red privada:** subredes privadas para las tareas, un NAT Gateway y subredes
  públicas solo para el ALB/NAT (`CKV_AWS_130`, `AWS-0164`).
- **VPC Flow Logs** cifrados con KMS (`CKV2_AWS_11`, `AWS-0178`).
- **KMS CMK** para ECR, Logs, SSM y S3 (`CKV_AWS_136/158/145`, `AWS-0017/0132`).
- **Log groups** con retención ≥ 365 días (`CKV_AWS_66/338`, `CKV_AWS_338`).
- **S3 privado**: Public Access Block total, SSE-KMS, versionado, lifecycle y
  política que solo permite al servicio de ELB escribir logs
  (`CKV_AWS_20/53-56/145/21`, `AWS-0086/0091/0092/0093/0090/0132`).
- **SG por defecto** de la VPC bloqueado (`CKV2_AWS_12`).
- **ALB + target group** con health check `/health` y circuit breaker con
  rollback, tareas privadas sin IP pública (`CKV_AWS_333`).
- **Container Insights** habilitado (`CKV_AWS_65`, `AWS-0034`).

---

## Hallazgos aceptados o excluidos

Las siguientes excepciones están declaradas de forma **específica** (nunca
mediante `soft-fail` global). El comentario de exclusión vive en
`.checkov.yaml` y `.trivyignore`.

| Control | Motivo técnico | Riesgo asociado | Medida compensatoria | Aprobador | Revisión | Comentario (dónde) |
|---------|----------------|-----------------|----------------------|-----------|----------|--------------------|
| `CKV_AWS_2` | El ALB solo tiene listener HTTP; no hay dominio ni certificado ACM en el alcance académico. | Tráfico sin cifrar entre cliente y ALB. | ALB es el único ingress; los datos de la demo no son sensibles; en producción se añade listener 443 con ACM. | `arquitectura-uc` | 2026-06-30 | `.checkov.yaml`, bloque TLS |
| `CKV_AWS_103` | Igual que `CKV_AWS_2` (no existe listener HTTPS, no aplica TLS 1.2). | Igual que `CKV_AWS_2`. | Igual que `CKV_AWS_2`. | `arquitectura-uc` | 2026-06-30 | `.checkov.yaml` |
| `CKV_AWS_378` | El target group usa HTTP porque el listener es HTTP. | Igual que `CKV_AWS_2`. | Igual que `CKV_AWS_2`. | `arquitectura-uc` | 2026-06-30 | `.checkov.yaml` |
| `CKV2_AWS_20` | No hay listener HTTPS al que redirigir. | Igual que `CKV_AWS_2`. | Igual que `CKV_AWS_2`. | `arquitectura-uc` | 2026-06-30 | `.checkov.yaml` |
| `CKV2_AWS_28` | WAF tiene costo mensual no justificable en una demo. | Sin filtrado L7. | Lista de IP permitidas vía `var.allowed_http_cidrs` en el SG del ALB. | `arquitectura-uc` | 2026-06-30 | `.checkov.yaml` |
| `CKV_AWS_18` / `AWS-0089` | El bucket ya almacena los access logs del ALB; “loguear el logger” requiere otro bucket. | Sin auditoría de acceso al bucket de logs. | Versionado + SSE-KMS + bucket privado; CloudTrail a nivel de cuenta. | `arquitectura-uc` | 2026-06-30 | `.checkov.yaml`, `.trivyignore` |
| `CKV_AWS_144` | Replicación cross-region aumenta costo y no aporta a la demo. | Pérdida ante desastre regional. | Versionado habilitado; el bucket es solo para logs. | `arquitectura-uc` | 2026-06-30 | `.checkov.yaml` |
| `CKV_AWS_150` | Protección de borrado del ALB dificultaría `terraform destroy` y el control de costos. | Borrado accidental del ALB. | `prevent_destroy` puede habilitarse en producción; el estado está versionado. | `arquitectura-uc` | 2026-06-30 | `.checkov.yaml` |
| `CKV_AWS_260` / `AWS-0053` | El ALB es el punto de entrada HTTP público de la demo. | Superficie HTTP pública. | Se puede restringir con `allowed_http_cidrs`; solo puerto 80. | `arquitectura-uc` | 2026-06-30 | `.checkov.yaml`, `.trivyignore` |
| `AWS-0054` (Trivy) | Listener HTTP sin TLS (misma razón que `CKV_AWS_2`). | Igual que `CKV_AWS_2`. | Igual que `CKV_AWS_2`. | `arquitectura-uc` | 2026-06-30 | `.trivyignore` |
| `AWS-0104` (Trivy) | Egress `443` a `0.0.0.0/0` es necesario para alcanzar las APIs de AWS (ECR/SSM/KMS) a través del NAT. | Egress amplio en 443. | Solo puerto 443; sin 80 ni otros puertos; NAT único. | `arquitectura-uc` | 2026-06-30 | `.trivyignore` |
