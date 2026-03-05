# Importing Existing Railway Resources

## Overview

If you already have Railway projects, services, environments, and variables
configured manually, you can import them into Terraform state so Terraform
manages them going forward — without recreating anything.

## Prerequisites

1. Railway API token for the workspace (`RAILWAY_TOKEN`)
2. The brand's tfvars file populated (`envs/<brand>.tfvars`)
3. UUIDs for each resource (see "Finding UUIDs" below)

## Finding UUIDs

### Project ID
Railway Dashboard → Project → Settings → General → "Project ID"

### Service IDs
Railway Dashboard → Project → Service → Settings → "Service ID"

### Environment IDs
Not directly shown in the UI. After importing the project, the default
environment ID is available. Additional environments are imported by name.

Alternatively, use the Railway CLI:
```bash
railway environment list
```

Or the Railway GraphQL API:
```bash
curl -s -X POST https://backboard.railway.app/graphql/v2 \
  -H "Authorization: Bearer $RAILWAY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query":"query { project(id: \"<PROJECT_ID>\") { environments { edges { node { id name } } } } }"}' \
  | jq '.data.project.environments.edges[].node'
```

## Import Commands

Run these from `railway/stacks/brand/` after `tofu init`.

### Step 1 — Import the project

```bash
tofu import -var-file=envs/<brand>.tfvars \
  'railway_project.this' '<PROJECT_UUID>'
```

### Step 2 — Import additional environments

The first environment (default) is part of the project. Import others:

```bash
# Import the "prod" environment (if "dev" is the default)
tofu import -var-file=envs/<brand>.tfvars \
  'railway_environment.this["prod"]' '<PROJECT_UUID>:prod'
```

### Step 3 — Import services

```bash
# API service
tofu import -var-file=envs/<brand>.tfvars \
  'railway_service.this["<brand>-api"]' '<API_SERVICE_UUID>'

# Web service
tofu import -var-file=envs/<brand>.tfvars \
  'railway_service.this["<brand>-web"]' '<WEB_SERVICE_UUID>'

# Database service
tofu import -var-file=envs/<brand>.tfvars \
  'railway_service.this["<brand>-db"]' '<DB_SERVICE_UUID>'
```

### Step 4 — Import environment variables

Format: `<SERVICE_UUID>:<ENV_NAME>:<VAR_NAME>`

```bash
# Example: import PORT variable for api service in dev environment
tofu import -var-file=envs/<brand>.tfvars \
  'railway_variable.this["<brand>-api:dev:PORT"]' '<API_SERVICE_UUID>:dev:PORT'

# Example: import DATABASE_URL for api service in dev environment
tofu import -var-file=envs/<brand>.tfvars \
  'railway_variable.this["<brand>-api:dev:DATABASE_URL"]' '<API_SERVICE_UUID>:dev:DATABASE_URL'
```

Repeat for each variable, per service, per environment.

> **Tip:** If you have many variables, you can script this:
> ```bash
> SERVICE_UUID="<uuid>"
> SERVICE_KEY="<brand>-api"
> ENV="dev"
> for VAR in PORT DATABASE_URL NODE_ENV; do
>   tofu import -var-file=envs/<brand>.tfvars \
>     "railway_variable.this[\"${SERVICE_KEY}:${ENV}:${VAR}\"]" \
>     "${SERVICE_UUID}:${ENV}:${VAR}"
> done
> ```

### Step 5 — Import custom domains

Format: `<SERVICE_UUID>:<ENV_NAME>:<DOMAIN>`

```bash
# Example: import custom domain for web service in dev environment
tofu import -var-file=envs/<brand>.tfvars \
  'railway_custom_domain.this["<brand>-web:dev:dev.<brand-domain>"]' \
  '<WEB_SERVICE_UUID>:dev:dev.<brand-domain>'
```

## Verification

After importing all resources:

```bash
# Plan should show no changes (or minimal drift)
tofu plan -var-file=envs/<brand>.tfvars
```

If there's drift, review each change carefully:
- **Expected:** Terraform normalising values it didn't know about
- **Unexpected:** Configuration mismatch between tfvars and actual Railway state

Fix any mismatches in your tfvars file, then re-plan until clean.

## Notes

- Variables are **sensitive** — their values won't show in plan output
- Importing a `railway_variable` triggers a service redeployment on next apply
  if the value changes. Be careful with environment variables that contain
  Railway reference variables (e.g. `${{service.DATABASE_URL}}`)
- The workspace itself cannot be imported — it's pre-created and the token
  is scoped to it
