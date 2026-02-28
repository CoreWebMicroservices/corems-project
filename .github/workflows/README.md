# CoreMS CI/CD Workflows

Reusable GitHub Actions workflows for CoreMS microservices.

## Quick Start

### 1. Copy Example to Your Service

```bash
# Java service
cp .github/workflows/examples/java-service-example.yml \
   your-service/.github/workflows/ci.yml

# Frontend
cp .github/workflows/examples/frontend-example.yml \
   frontend/.github/workflows/ci.yml
```

### 2. Update Service Name

```yaml
with:
  service-name: your-service  # Change this
```

### 3. Push and Done

```bash
git add .github/workflows/ci.yml
git commit -m "Add CI"
git push
```

CI runs automatically on every push and PR.

## Available Workflows

### CI Workflows

**`java-service-ci.yml`** - Java microservices
- Build (Maven)
- Unit tests
- Optional: Maven artifacts, Docker, SonarQube

**`frontend-ci.yml`** - React frontend
- Build (npm)
- Lint & type check
- Unit tests
- Optional: Docker, SonarQube

### CD Workflows

**`java-service-cd.yml`** - Deploy Java services
- Build Docker image (optional)
- Deploy via docker-compose

**`frontend-cd.yml`** - Deploy frontend
- Pull Docker image
- Deploy via docker-compose

**`java-service-release.yml`** - Create versioned releases
- Update Maven version
- Publish versioned artifacts
- Build and push versioned Docker images
- Create GitHub release

## Configuration

### Minimal (Recommended)

Fast CI with tests only:

```yaml
with:
  service-name: user-ms
  publish-artifacts: false
  build-docker: false
  run-sonarqube: false
```

**Result**: ~5 minutes

### Main Branch Features

Enable features on main branch:

```yaml
with:
  service-name: user-ms
  publish-artifacts: ${{ github.ref == 'refs/heads/main' }}
  build-docker: false  # Build in CD
  run-sonarqube: ${{ github.ref == 'refs/heads/main' }}
```

**Result**: 
- PRs: ~5 min (tests only)
- Main: ~10 min (tests + artifacts + SonarQube)

### Full CI/CD

Complete pipeline with deployment:

```yaml
jobs:
  ci:
    uses: CoreWebMicroservices/corems-project/.github/workflows/java-service-ci.yml@main
    with:
      service-name: user-ms
      publish-artifacts: ${{ github.ref == 'refs/heads/main' }}
      
  deploy:
    needs: ci
    if: github.ref == 'refs/heads/main'
    uses: CoreWebMicroservices/corems-project/.github/workflows/java-service-cd.yml@main
    with:
      service-name: user-ms
      environment: dev
      image-tag: build  # Build fresh
```

## Feature Flags

| Flag | Default | Description |
|------|---------|-------------|
| `publish-artifacts` | `false` | Publish Maven artifacts to GitHub Packages |
| `build-docker` | `false` | Build Docker image |
| `push-docker` | `false` | Push Docker image to registry |
| `run-sonarqube` | `false` | Run SonarQube code analysis |

## Secrets

### Always Required
- `GITHUB_TOKEN` (auto-provided)

### Optional (based on features)
- `DOCKER_USERNAME` + `DOCKER_PASSWORD` (for Docker Hub)
- `SONAR_TOKEN` (for SonarQube)

Add secrets in: Repository Settings → Secrets → Actions

## Examples

See `.github/workflows/examples/` for:
- `java-service-example.yml` - Minimal Java CI
- `java-service-cicd-example.yml` - Complete CI/CD
- `java-service-full-example.yml` - All features enabled
- `java-service-release-example.yml` - Release workflow
- `frontend-example.yml` - Frontend CI
- `parent-common-example.yml` - Library CI

## Releases

Create a versioned release by pushing a git tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

This triggers the release workflow which:
1. Updates Maven version to match tag
2. Builds and tests
3. Publishes versioned Maven artifacts
4. Builds and pushes versioned Docker image
5. Creates GitHub release

Artifacts:
- Maven: `com.corems.user-ms:*:1.0.0`
- Docker: `ghcr.io/corewebmicroservices/user-ms:1.0.0`
- Docker: `ghcr.io/corewebmicroservices/user-ms:latest`

## Deployment

### Build in CD (Recommended)

```yaml
# CI - tests only
ci:
  with:
    build-docker: false

# CD - build during deployment
deploy:
  with:
    image-tag: build  # Builds fresh
```

**Why**: Faster PR feedback

### Build in CI (Alternative)

```yaml
# CI - build and push
ci:
  with:
    build-docker: ${{ github.ref == 'refs/heads/main' }}
    push-docker: ${{ github.ref == 'refs/heads/main' }}

# CD - use pre-built image
deploy:
  with:
    image-tag: latest  # Uses CI image
```

**Why**: Build once, deploy many times

## Troubleshooting

**CI is slow**
- Disable optional features
- Check if Docker is building unnecessarily

**Maven artifacts not found**
- Enable `publish-artifacts: true`
- Check `GITHUB_TOKEN` is available

**Docker build fails**
- Verify `docker/Dockerfile` exists
- Check Maven build succeeds first

**SonarQube fails**
- Verify `SONAR_TOKEN` is configured
- Check token is valid

## Architecture

```
Service Repo                    CoreMS Project
─────────────                   ──────────────
.github/workflows/ci.yml   →    .github/workflows/
  (minimal config)                ├── java-service-ci.yml
                                  ├── java-service-cd.yml
                                  ├── frontend-ci.yml
                                  └── frontend-cd.yml
                                    (reusable workflows)
```

Update reusable workflows once, applies to all services.

## Best Practices

1. Start minimal - enable features incrementally
2. Use branch conditions for main-only features
3. Build Docker in CD for faster PRs
4. Publish Maven artifacts on main branch
5. Keep PRs under 10 minutes

## Support

- Examples: `.github/workflows/examples/`
- Issues: Open in corems-project repository
