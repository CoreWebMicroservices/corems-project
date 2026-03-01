# Service CI/CD Configuration Summary

## Overview

All services now have minimal CI/CD workflows that reference reusable workflows from the main `corems-project` repository. This provides centralized management while keeping service configuration minimal.

## Service Workflows

Each service has 3 workflow files in `.github/workflows/`:

### 1. CI Workflow (`ci.yml`)
**Trigger**: Push or PR to main/develop branches
**Purpose**: Build, test, and optionally push Docker images

```yaml
name: CI
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  ci:
    uses: CoreWebMicroservices/corems-project/.github/workflows/java-service-ci.yml@main
    with:
      service-name: 'user-ms'  # Only difference per service
      java-version: '25'
      build-docker: true
      push-docker: ${{ github.event_name == 'push' && github.ref == 'refs/heads/main' }}
      docker-registry: 'ghcr.io'
    secrets:
      github-token: ${{ secrets.GITHUB_TOKEN }}
      docker-password: ${{ secrets.GITHUB_TOKEN }}
```

**What it does**:
- Builds API → Client → Service modules
- Runs unit tests
- Builds Docker image
- Pushes to ghcr.io (only on push to main)

### 2. CD Workflow (`cd.yml`)
**Trigger**: Manual workflow dispatch
**Purpose**: Deploy service to dev or prod environment

```yaml
name: CD
on:
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [dev, prod]
      image-tag:
        type: string
        default: 'latest'

jobs:
  deploy:
    uses: CoreWebMicroservices/corems-project/.github/workflows/java-service-cd.yml@main
    with:
      service-name: 'user-ms'  # Only difference per service
      environment: ${{ github.event.inputs.environment }}
      image-tag: ${{ github.event.inputs.image-tag }}
      docker-registry: 'ghcr.io'
      java-version: '25'
    secrets:
      github-token: ${{ secrets.GITHUB_TOKEN }}
      docker-password: ${{ secrets.GITHUB_TOKEN }}
```

**What it does**:
- Optionally builds fresh Docker image (if image-tag='build')
- Pulls specified image from registry
- Deploys via docker-compose
- Runs health checks

### 3. Release Workflow (`release.yml`)
**Trigger**: Push tag matching `v*.*.*` (e.g., v1.0.0)
**Purpose**: Create versioned release with Maven artifacts and Docker images

```yaml
name: Release
on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  release:
    uses: CoreWebMicroservices/corems-project/.github/workflows/java-service-release.yml@main
    with:
      service-name: 'user-ms'  # Only difference per service
      java-version: '25'
      docker-registry: 'ghcr.io'
    secrets:
      github-token: ${{ secrets.GITHUB_TOKEN }}
      docker-password: ${{ secrets.GITHUB_TOKEN }}
```

**What it does**:
- Checks for SNAPSHOT dependencies (fails if found)
- Sets release version (removes -SNAPSHOT)
- Builds and tests
- Publishes Maven artifacts to GitHub Packages
- Builds and pushes Docker image with version tag
- Bumps to next SNAPSHOT version
- Creates GitHub Release

## Services Configured

All services have complete CI/CD workflows:

- ✅ `repos/user-ms/.github/workflows/` (ci.yml, cd.yml, release.yml)
- ✅ `repos/communication-ms/.github/workflows/` (ci.yml, cd.yml, release.yml)
- ✅ `repos/document-ms/.github/workflows/` (ci.yml, cd.yml, release.yml)
- ✅ `repos/translation-ms/.github/workflows/` (ci.yml, cd.yml, release.yml)

## Context Path Configuration

All services have context path configured in `application.yaml`:

```yaml
server:
  port: ${SERVICE-NAME-PORT:300X}
  servlet:
    context-path: /${SERVICE_PREFIX:}
```

This allows services to handle requests with service prefix:
- ALB forwards: `/user/api/profile` → user-ms
- Service receives: `/user/api/profile`
- Spring Boot handles: `/api/profile` (after stripping context path)

Terraform automatically sets `SERVICE_PREFIX` environment variable:
- user-ms: `SERVICE_PREFIX=user`
- communication-ms: `SERVICE_PREFIX=communication`
- document-ms: `SERVICE_PREFIX=document`
- translation-ms: `SERVICE_PREFIX=translation`

## Reusable Workflows (Main Project)

The main `corems-project` repository contains reusable workflows:

### `.github/workflows/java-service-ci.yml`
Reusable CI workflow with parameters:
- `service-name` (required)
- `java-version` (default: '25')
- `build-docker` (default: false)
- `push-docker` (default: false)
- `publish-artifacts` (default: false)
- `run-sonarqube` (default: false)

### `.github/workflows/java-service-cd.yml`
Reusable CD workflow with parameters:
- `service-name` (required)
- `environment` (required: dev/staging/prod)
- `image-tag` (default: 'latest', or 'build' for fresh build)
- `docker-registry` (default: 'ghcr.io')

### `.github/workflows/java-service-release.yml`
Reusable release workflow with parameters:
- `service-name` (required)
- `java-version` (default: '25')
- `docker-registry` (default: 'ghcr.io')

## Usage Examples

### Running CI
CI runs automatically on push/PR. To manually trigger:
```bash
# Push to main branch
git push origin main

# CI will:
# 1. Build all modules
# 2. Run tests
# 3. Build Docker image
# 4. Push to ghcr.io
```

### Deploying to Dev
```bash
# Via GitHub Actions UI:
# 1. Go to Actions > CD
# 2. Click "Run workflow"
# 3. Select environment: dev
# 4. Select image-tag: latest (or specific version)
# 5. Click "Run workflow"
```

### Creating a Release
```bash
# 1. Ensure no SNAPSHOT dependencies
mvn dependency:list | grep SNAPSHOT

# 2. Create and push tag
git tag v1.0.0
git push origin v1.0.0

# 3. Release workflow runs automatically:
# - Sets version to 1.0.0
# - Builds and publishes artifacts
# - Pushes Docker image: user-ms:1.0.0
# - Bumps to 1.1.0-SNAPSHOT
# - Creates GitHub Release
```

## Benefits

### Centralized Management
- Update workflow logic once in `corems-project`
- All services get updates automatically
- Consistent behavior across all services

### Minimal Service Configuration
- Each service: ~60 lines total (3 files × ~20 lines)
- Only service name differs between services
- Easy to add new services

### Version Control
- Use `@main` for latest workflow version
- Use `@v1.0.0` for stable workflow version
- Pin to specific version for production stability

### Easy Updates
- Add new environment? Update main repo once
- Change build process? Update main repo once
- All services inherit changes automatically

## GitHub Secrets Required

Each service repository needs these secrets:

### Automatic (provided by GitHub)
- `GITHUB_TOKEN` - Automatically available

### Manual Configuration (for AWS deployment)
- `AWS_ACCESS_KEY_ID` - AWS credentials for ECS deployment
- `AWS_SECRET_ACCESS_KEY` - AWS credentials for ECS deployment

## Next Steps

1. ✅ Context path configured in all services
2. ✅ CI workflows created for all services
3. ✅ CD workflows created for all services
4. ✅ Release workflows created for all services
5. ⏳ Test CI workflow with a push
6. ⏳ Test CD workflow with manual deployment
7. ⏳ Test release workflow with version tag
8. ⏳ Configure AWS credentials in GitHub Secrets
9. ⏳ Deploy infrastructure with Terraform
10. ⏳ Deploy services to ECS

## Troubleshooting

### Workflow not found
If you get "workflow not found" error:
- Ensure `corems-project` repository is public, or
- Add repository access token to secrets

### Docker push fails
- Ensure GitHub Container Registry is enabled
- Check `GITHUB_TOKEN` has package write permissions
- Verify image name format: `ghcr.io/owner/service-name:tag`

### Release fails on SNAPSHOT check
- Run `mvn dependency:list | grep SNAPSHOT`
- Update all SNAPSHOT dependencies to release versions
- Commit and push before creating release tag

### ECS deployment fails
- Verify AWS credentials are configured
- Check ECS cluster and service exist
- Ensure task definition is registered
- Verify security groups allow traffic
