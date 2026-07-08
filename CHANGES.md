# Platform Engineering Take-Home — Review Summary

This document summarizes findings, fixes applied, and recommended follow-up work across the Book Reading Service application, Terraform infrastructure, CI/CD pipeline, and Datadog monitoring configuration.

---

## 1. Application Code (`Program.cs`)

### Findings

| Priority | Issue | Impact |
|----------|--------|--------|
| P0 | **XXE in XML parsing** — `DtdProcessing.Parse` + `XmlUrlResolver` | External entity injection; `LanguagePrices_Unencrypted.xml` contains a `file://` XXE payload |
| P0 | **Hardcoded password + DES encryption** | Weak, obsolete crypto; key in source control |
| P1 | **Loop bug** — `titleResponse.Docs[0].EditionKeys` instead of `book.EditionKeys` | All results show editions for the first book only |
| P1 | **Wrong Open Library URL** — `/works/{editionKey}` for edition keys | Incorrect page counts and language data |
| P2 | **HttpClient per request** | Socket exhaustion under load |
| P2 | **Decrypt/deserialize inside inner loop** | Redundant I/O and crypto on every edition |
| P2 | **Encrypt on every startup** | Unnecessary file writes; unclear key/IV lifecycle |
| P3 | Dead code (`Encryption` class, unused search methods), naming inconsistencies | Maintainability |

### Fixes Applied

- **XXE mitigation** — Set `DtdProcessing = Prohibit` and `XmlResolver = null` when deserializing language pricing XML. This blocks external entity resolution while preserving normal deserialization of pricing data.

### Not Fixed (Documented for Follow-Up)

- Replace DES with AES-256; load secrets from Key Vault or environment variables
- Fix `Docs[0]` loop bug and Open Library endpoint (`/books/{editionKey}`)
- Reuse a single `HttpClient`; load and decrypt pricing data once per run
- Remove encryption from `Main`; run as a build/deploy step
- Strip malicious DTD/script content from `LanguagePrices_Unencrypted.xml`

---

## 2. Terraform (`terraform/`)

### Findings

| Priority | Issue | Impact |
|----------|--------|--------|
| P0 | Secrets in plain `env { value = ... }` | Credentials in Terraform state, Azure Portal, and logs |
| P0 | `acr_admin_password` exported as output | Registry credentials leaked via state/outputs |
| P0 | `nonprod.tfvars` had `environment = "prod"` | Nonprod deploys would target prod-named resources |
| P1 | All resource names hardcoded to `*-prod` | Variables unused; environment collision |
| P1 | ACR `admin_enabled = true` | Extra credential surface |
| P2 | Secret defaults in `variables.tf` | Passwords committed as defaults |
| P2 | Duplicate outputs in `main.tf` and `outputs.tf` | Confusion and duplicate sensitive output |
| P2 | No provider version pinning | Non-reproducible applies |

### Fixes Applied

- **Environment-aware naming** — Resources use `rg-${app_name}-${environment}` (e.g. `rg-myapp-nonprod`, `rg-myapp-prod`)
- **Secrets via Container App secret references** — DB connection string, API key, and Datadog key stored in `secret` blocks; env vars reference `secret_name`
- **ACR admin disabled** — User-assigned managed identity with `AcrPull` role for image pull (identity created before the app to avoid first-deploy pull failures)
- **Sensitive outputs removed** — No `acr_admin_password` in outputs
- **tfvars corrected** — `nonprod.tfvars` → `environment = "nonprod"`; prod/nonprod differ on retention, replicas, and SQL hostname
- **Provider pinning** — `azurerm ~> 3.0` and `required_version`; comment stub for remote state backend

### Files Changed

- `terraform/main.tf`
- `terraform/variables.tf`
- `terraform/outputs.tf`
- `terraform/configuration/nonprod.tfvars`
- `terraform/configuration/prod.tfvars`

---

## 3. CI/CD Pipeline (`pipeline/azure-pipelines.yml`)

### Findings

| Priority | Issue | Impact |
|----------|--------|--------|
| P0 | Hardcoded `acrPassword`, `sqlPassword`, `datadogApiKey` | Secrets in source control |
| P0 | `trigger: '*'` | Every branch could deploy infrastructure |
| P1 | Manual `az login` with undefined `$(servicePrincipalId)` variables | Login failure; anti-pattern vs service connections |
| P1 | `imageTag: latest` | Non-reproducible deploys |
| P1 | Hardcoded prod ACR/RG for all stages | Nonprod targeted prod resources |
| P1 | No secret vars passed to Terraform | Plan/apply would fail after Terraform fixes |
| P2 | Same health URL for nonprod and prod | Verification didn't match environment |
| P2 | `curl ... \|\| true` | Health check failures ignored |
| P2 | No prod approval gate | Direct auto-apply to production |

### Fixes Applied

- **Trigger scoped to `main`** — `pr: none` so PRs don't deploy
- **Immutable image tags** — `$(Build.BuildId)` instead of `latest`
- **Secrets via ADO variables** — `NONPROD_*` and `PROD_*` secret variables (documented in pipeline comments)
- **Service connections** — `AzureCLI@2` with `Nonprod-ServiceConnection` / `Production-ServiceConnection`
- **Per-environment ACR** — Nonprod → `acrmyappnonprod`; prod → `acrmyappprod`
- **Build once, deploy twice** — Image saved as pipeline artifact; loaded in each deploy stage
- **Terraform secrets via `-var`** — Aligns with updated `variables.tf`
- **Production approval** — `deployment` job with `environment: production`
- **Health checks from Terraform output** — `curl --fail` with retries; fails pipeline on error
- **Terraform installer** — Pins Terraform 1.6.6

### Azure DevOps Setup Required

- Service connections: `Nonprod-ServiceConnection`, `Production-ServiceConnection`
- Secret variables: `NONPROD_DATABASE_CONNECTION_STRING`, `NONPROD_API_KEY`, `NONPROD_DATADOG_API_KEY`, and prod equivalents
- Environment `production` with required approvers

---

## 4. Observability (`monitoring/`)

### Findings

| Priority | Issue | Impact |
|----------|--------|--------|
| P0 | Hardcoded Datadog `api_key` and `app_key` | Credentials in source control |
| P1 | Hardcoded `ca-myapp-api` | Doesn't match Terraform naming per environment |
| P1 | Error log monitor pages on any error (`> 0`) | Alert fatigue |
| P1 | `process.up` service check for Container Apps | Wrong health signal for ACA |
| P1 | Log query uses `index("*")` | Slow, noisy, cross-environment bleed |
| P2 | 1-minute CPU window | Flapping alerts |
| P2 | Dashboard uses `{*}` wildcards | Not scoped to target app/environment |
| P2 | No HTTP 5xx monitor | Gap in error coverage |

### Fixes Applied

- **Secrets via variables** — `datadog_api_key` and `datadog_app_key` marked `sensitive`; supply via `TF_VAR_*` or CI
- **Environment parameterization** — Monitors and dashboard scoped by `env`, `service`, and `container_app_name`
- **Replica monitor** — Replaces `process.up` with `azure.containerapps.management.replicas.count`; disabled when `min_expected_replicas = 0` (nonprod scale-to-zero)
- **Tuned thresholds** — CPU 5m window with warning/critical; error logs require >10 in 5m
- **HTTP 5xx monitor** — Added for application error rate
- **P95 response time** — More representative than plain average
- **On-call routing** — `oncall_notification` variable in alert messages
- **Per-env tfvars** — `configuration/nonprod.tfvars` and `configuration/prod.tfvars`

### Files Added/Changed

- `monitoring/datadog-monitors.tf`
- `monitoring/variables.tf`
- `monitoring/configuration/nonprod.tfvars`
- `monitoring/configuration/prod.tfvars`

### Apply Example

```bash
cd monitoring
export TF_VAR_datadog_api_key="..."
export TF_VAR_datadog_app_key="..."
terraform init
terraform plan -var-file="configuration/prod.tfvars"
```

---

## 5. With More Time

### Application
- Full crypto modernization (AES + Key Vault)
- Fix remaining logic bugs and add integration tests
- Sanitize `LanguagePrices_Unencrypted.xml`

### Infrastructure
- Azure Key Vault secret references for Container App secrets
- Remote Terraform backend (`azurerm`) with state locking
- Separate state files or workspaces per environment

### CI/CD
- Add Terraform fmt/validate and optional security scanning (e.g. `tfsec`, container scan)
- Promote exact image digest instead of tag where possible
- Add monitoring deploy stage after infrastructure apply

### Observability
- Validate Azure metric names against live Datadog integration
- SLO monitors and composite alerts to reduce deploy noise
- Wire monitor deployment into the pipeline

---

## 6. Summary

| Area | Critical Issues Found | Fixes Applied |
|------|----------------------|---------------|
| Application | XXE, weak crypto, logic bugs | XXE fix |
| Terraform | Plaintext secrets, env collision, ACR admin | Full config overhaul |
| Pipeline | Hardcoded secrets, unsafe triggers, no gates | Full pipeline rewrite |
| Monitoring | Hardcoded keys, wrong signals, alert fatigue | Full monitor overhaul |

The highest-impact remaining risk in the application is **hardcoded credentials and DES encryption**. Infrastructure, pipeline, and monitoring changes establish safer patterns for secrets, environment isolation, deployment gates, and alert quality.
