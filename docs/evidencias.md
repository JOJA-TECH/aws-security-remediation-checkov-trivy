# Evidencias de la demostración

Checklist de artefactos y capturas que el equipo debe presentar. Se recomienda
guardar los archivos en `docs/evidencias/` (ignorada por Git) y las capturas de
pantalla/URLs en el informe.

## 1. Ejecución de Checkov sobre la infraestructura insegura

```bash
checkov -d terraform/insecure --framework terraform | tee docs/evidencias/checkov-insecure.txt
```
- **Esperado:** 42 controles fallidos (43 passed). Ver `docs/hallazgos-iniciales.md` §3.
- **Captura:** resumen final de Checkov y tabla de controles.

## 2. Ejecución de Trivy config / secret sobre la infraestructura insegura

```bash
trivy config terraform/insecure | tee docs/evidencias/trivy-config-insecure.txt
trivy fs --scanners secret terraform/insecure | tee docs/evidencias/trivy-secret-insecure.txt
```
- **Esperado:** 23 misconfiguraciones; 2 secretos (`aws-access-key-id` y `github-pat`).

## 3. Ejecución de Trivy sobre la imagen insegura

```bash
docker build -f app/Dockerfile.insecure -t insecure-demo:ci ./app
trivy image --severity CRITICAL,HIGH insecure-demo:ci | tee docs/evidencias/trivy-image-insecure.txt
```
- **Esperado:** múltiples vulnerabilidades OS/paquetes `CRITICAL`/`HIGH` de la
  base `python:latest` + `DS-0002` (root) + `DS-0001` (latest).
- **Verificación:** el conteo exacto depende del momento del build; capturarlo.

## 4. Lista de hallazgos

- **Entregable:** `docs/hallazgos-iniciales.md`.
- **Captura:** resumen cuantitativo y tablas por grupo.

## 5. Comparación inseguro vs corregido

- **Entregable:** diff entre `terraform/insecure` y `terraform/secure`.
  ```bash
  diff -ru terraform/insecure terraform/secure | tee docs/evidencias/diff-insecure-secure.txt
  ```
- **Captura:** tabla comparativa de `docs/correcciones.md`.

## 6. Checkov exitoso tras las correcciones

```bash
checkov -d terraform/secure --framework terraform --config-file checkov/secure.yaml
```
- **Esperado:** `Passed: 158, Failed: 0` (con los skips justificados de `checkov/secure.yaml`).
- **Captura:** salida con “Passed checks” y 0 failed.

## 7. Trivy exitoso tras las correcciones

```bash
trivy config --ignorefile trivy/secure.ignore --severity CRITICAL,HIGH --exit-code 1 terraform/secure
trivy fs --scanners secret,misconfig --skip-dirs terraform/insecure --skip-files app/Dockerfile.insecure \
  --ignorefile trivy/secure.ignore --severity CRITICAL,HIGH --exit-code 1 .
docker build -t secure-demo:ci ./app
trivy image --severity CRITICAL,HIGH --ignore-unfixed --exit-code 1 secure-demo:ci
```
- **Esperado:** exit code 0. Si aparecen CVE fijos, actualizar la imagen base
  `python:3.12.x-slim-bookworm`. Registrar cualquier vulnerabilidad aceptada
  (sin fix) en `trivy/secure.ignore` **con justificación**.

## 8. Pipeline bloqueado por una vulnerabilidad/incumplimiento

- **Cómo demostrarlo:** abrir un PR que introduzca un fallo controlado, p. ej.
  añadir a `terraform/secure/ecr.tf` `image_tag_mutability = "MUTABLE"`, o usar
  `image_uri` con `:latest`.
- **Esperado:** el job `Security` falla (Checkov o Terraform validation) y
  `Deploy` no se ejecuta.
- **Captura:** pantalla del workflow en rojo y el job `Deploy` ausente/omitido.

## 9. Pipeline exitoso tras las correcciones

- **Esperado:** `Security` en verde y `Deploy` en verde tras merge a `main`.
- **Captura:** ambas ejecuciones, el resumen del job y la URL de la aplicación.

## 10. Imagen publicada en ECR con etiqueta inmutable

```bash
aws ecr describe-repositories --repository-names secure-demo-dev-app \
  --query 'repositories[0].imageTagMutability'
aws ecr describe-images --repository-name secure-demo-dev-app \
  --query 'imageDetails[].imageTags' --output table
```
- **Esperado:** `IMMUTABLE` y la imagen etiquetada con el SHA del commit.
- **Captura:** salida de los comandos + consola de ECR.

## 11. Servicio ECS ejecutándose

```bash
aws ecs describe-services --cluster secure-demo-dev --services secure-demo-dev-service \
  --query 'services[0].{status:status,running:runningCount,desired:desiredCount}'
```
- **Esperado:** `status: ACTIVE`, `running == desired == 1`.
- **Captura:** consola de ECS (Tasks en RUNNING).

## 12. Prueba del endpoint /health

```bash
scripts/verify.sh "$(cd terraform/secure && terraform output -raw health_url)"
```
- **Esperado:** respuesta JSON con `"status":"healthy"`.
- **Captura:** `curl` con el JSON.

## 13. Aplicación accesible desde AWS

- Abrir la `app_url` en el navegador y capturar el JSON de `/` y `/version`.
- **Captura:** URL del ALB + respuesta.

## 14. `terraform plan` y `terraform apply`

```bash
cd terraform/secure
terraform init -backend-config=...
terraform plan  -var "image_uri=<digest>"  | tee ../docs/evidencias/plan.txt
terraform apply -var "image_uri=<digest>"  | tee ../docs/evidencias/apply.txt
```
- **Esperado:** plan/apply correctos y salidas (`app_url`, `health_url`).
- **Captura:** salida de ambos comandos.

## 15. `terraform destroy`

```bash
cd terraform/secure
terraform destroy -var "image_uri=<digest>" | tee ../docs/evidencias/destroy.txt
```
- **Esperado:** destrucción de todos los recursos.
- **Captura:** salida final y consola sin recursos.

---

## Estructura sugerida de evidencias

```text
docs/evidencias/
├── checkov-insecure.txt
├── checkov-secure.txt
├── trivy-config-insecure.txt
├── trivy-secret-insecure.txt
├── trivy-image-insecure.txt
├── trivy-image-secure.txt
├── diff-insecure-secure.txt
├── pipeline-blocked.png
├── pipeline-success.png
├── ecr-immutable.png
├── ecs-running.png
├── health-endpoint.png
├── plan.txt
├── apply.txt
└── destroy.txt
```
