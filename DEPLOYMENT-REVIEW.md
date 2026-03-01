# Complete Deployment Lifecycle Review

## Current State Analysis

### ✅ What We Have

#### 1. CI/CD Workflows (GitHub Actions)
- ✅ **Java Service CI** - Build, test, optional Docker build
- ✅ **Java Service CD** - Deploy via docker-compose
- ✅ **Frontend CI/CD** - Separate workflows
- ✅ **Terraform Workflow** - Infrastructure management
- ✅ **Release Workflows** - Maven versioning

#### 2. Infrastructure as Code (Terraform)
- ✅ **AWS ECS Infrastructure** - Complete setup in `infra/` folder
  - VPC with public/private subnets
  - RDS PostgreSQL
  - ECS Fargate cluster
  - Application Load Balancer
  - S3 for documents
  - Amazon MQ (RabbitMQ)
  - 7 reusable modules
- ✅ **Service routing** - Path-based routing configured

#### 3. Services
- ✅ **4 Backend Services** - user-ms, communication-ms, document-ms, translation-ms
- ✅ **Dockerfiles** - All services have Dockerfiles
- ✅ **OpenAPI Specs** - API-first development
- ✅ **Database Migrations** - Flyway migrations ready

#### 4. Local Development
- ✅ **setup.sh** - Complete automation script
- ✅ **Docker Compose** - Local infrastructure (PostgreSQL, RabbitMQ, MinIO)
- ✅ **Environment files** - .env-example templates

---

## ❌ What's Missing / Issues

### Critical Issues

#### 1. **Service Context Path Configuration** ✅
**Status**: FIXED

All services now have context path configuration in `application.yaml`:
```yaml
server:
  servlet:
    context-path: /${SERVICE_PREFIX:}
```

Services configured:
- user-ms: `SERVICE_PREFIX=user`
- communication-ms: `SERVICE_PREFIX=communication`
- document-ms: `SERVICE_PREFIX=document`
- translation-ms: `SERVICE_PREFIX=translation`
- template-ms: `SERVICE_PREFIX=template`

Terraform automatically sets SERVICE_PREFIX environment variable for each service.

---

#### 2. **Service-Specific CI/CD Workflows** ✅
**Status**: FIXED

Created CI/CD workflows for all services:
- `user-ms-ci.yml` / `user-ms-cd.yml`
- `communication-ms-ci.yml` / `communication-ms-cd.yml`
- `document-ms-ci.yml` / `document-ms-cd.yml`
- `translation-ms-ci.yml` / `translation-ms-cd.yml`

CI triggers:
- On push to main/develop (service paths)
- On pull requests
- Builds Docker image
- Pushes to ghcr.io on main branch

CD triggers:
- Manual workflow dispatch
- Choose environment (dev/prod)
- Choose image tag or build fresh

---

#### 3. **Terraform Workflow Configuration** ✅
**Status**: FIXED
- Workflow uses `infra/` directory
- Environment-specific settings passed via workflow inputs
- Backend configured with S3 + DynamoDB
- Separate workflows for dev and prod environments

---

#### 4. **No Docker Image Registry Setup** 🟡
**Problem**: Workflows reference `ghcr.io` but:
- No GitHub Packages configuration
- No authentication setup documented
- Services need to push images before ECS can pull them

**Need**: 
- Configure GitHub Container Registry
- Document authentication
- Or use AWS ECR instead

---

#### 5. **CD Workflow Uses Docker Compose, Not ECS** 🟡
**Problem**: CD workflow deploys via docker-compose, but infrastructure is ECS

**Current CD**: Runs `docker-compose up` on a server
**Infrastructure**: AWS ECS Fargate (no servers)

**Need**: Update CD workflow to:
- Update ECS task definitions
- Trigger ECS service updates
- Or use Terraform to update service images

---

#### 6. **Environment-Specific Configurations** ✅
**Status**: FIXED
- Dev workflow: db.t3.micro, 256 CPU, 512 MB, 1 task
- Prod workflow: db.t3.small, 512 CPU, 1024 MB, 3 tasks
- Settings passed via workflow inputs
- Secrets managed in GitHub Secrets (not in tfvars)

---

#### 7. **No Database Migration in Deployment** 🟡
**Problem**: Migrations exist but not integrated into deployment

**Need**: Add migration step to CD workflow:
- Run Flyway migrations before deploying new service version
- Or use init containers in ECS

---

#### 8. **No Health Check Integration** 🟡
**Problem**: CD workflow has placeholder health check

**Need**: Actual health check that:
- Waits for ECS service to be stable
- Checks ALB target health
- Verifies service endpoints

---

#### 9. **No Rollback Strategy** 🟡
**Problem**: If deployment fails, no automatic rollback

**Need**: 
- ECS deployment circuit breaker
- Blue-green deployment option
- Rollback workflow

---

#### 10. **No Secrets Management** 🟡
**Problem**: Secrets in terraform.tfvars (not secure for prod)

**Need**:
- AWS Secrets Manager integration
- GitHub Secrets for CI/CD
- Terraform to reference secrets, not hardcode

---

#### 11. **No Monitoring/Alerting** 🟡
**Problem**: No visibility into deployment success/failure

**Need**:
- CloudWatch alarms
- Deployment notifications (Slack/email)
- Service health dashboards

---

#### 12. **Frontend Not in ECS Configuration** 🟡
**Problem**: Frontend has CI/CD but not in Terraform ECS setup

**Need**: Add frontend service to ECS or deploy separately (S3 + CloudFront)

---

## Testing Plan

### Phase 1: Fix Critical Path Issues (Week 1)

#### Step 1.1: Add Service Context Path
- [ ] Add `server.servlet.context-path` to each service's application.yaml
- [ ] Update Terraform to pass SERVICE_PREFIX environment variable
- [ ] Test locally: `SERVER_PREFIX=user ./mvnw spring-boot:run`
- [ ] Verify paths work: `/user/api/profile`, `/user/oauth2/token`

#### Step 1.2: Create Service-Specific Workflows
- [ ] Create `user-ms-ci.yml` calling reusable workflow
- [ ] Create `user-ms-cd.yml` calling reusable workflow
- [ ] Test CI workflow with PR
- [ ] Verify Docker image builds

#### Step 1.3: Fix Terraform Workflow
- [ ] Create `infra/environments/dev.tfvars`
- [ ] Update terraform workflow to use `infra/` directory
- [ ] Configure S3 backend for state
- [ ] Test terraform plan

---

### Phase 2: Setup Infrastructure (Week 1-2)

#### Step 2.1: Configure Docker Registry
- [ ] Enable GitHub Container Registry
- [ ] Configure authentication
- [ ] Push test image
- [ ] Verify ECS can pull from ghcr.io

#### Step 2.2: Deploy Infrastructure
- [ ] Review terraform.tfvars
- [ ] Run `terraform plan`
- [ ] Run `terraform apply` (dev environment)
- [ ] Verify all resources created
- [ ] Test ALB endpoint

#### Step 2.3: Configure Secrets
- [ ] Create AWS Secrets Manager secrets
- [ ] Update Terraform to use secrets
- [ ] Configure GitHub Secrets for CI/CD
- [ ] Test secret access

---

### Phase 3: Deploy First Service (Week 2)

#### Step 3.1: Deploy user-ms
- [ ] Build and push Docker image
- [ ] Update ECS task definition with image
- [ ] Deploy to ECS
- [ ] Check CloudWatch logs
- [ ] Test health endpoint via ALB

#### Step 3.2: Run Database Migrations
- [ ] Connect to RDS
- [ ] Run Flyway migrations
- [ ] Verify schema created
- [ ] Test database connectivity from service

#### Step 3.3: End-to-End Test
- [ ] Test OAuth2 endpoints via ALB
- [ ] Test user registration
- [ ] Test user login
- [ ] Verify JWT token generation

---

### Phase 4: Deploy Remaining Services (Week 2-3)

#### Step 4.1: Deploy communication-ms
- [ ] Build and push image
- [ ] Deploy to ECS
- [ ] Test messaging endpoints
- [ ] Verify RabbitMQ integration

#### Step 4.2: Deploy document-ms
- [ ] Build and push image
- [ ] Deploy to ECS
- [ ] Test file upload
- [ ] Verify S3 integration

#### Step 4.3: Deploy translation-ms
- [ ] Build and push image
- [ ] Deploy to ECS
- [ ] Test translation endpoints

---

### Phase 5: Automate Deployment (Week 3)

#### Step 5.1: Update CD Workflow for ECS
- [ ] Replace docker-compose with ECS deployment
- [ ] Add task definition update
- [ ] Add service update trigger
- [ ] Test automated deployment

#### Step 5.2: Add Health Checks
- [ ] Implement proper health check logic
- [ ] Add ECS deployment circuit breaker
- [ ] Test failed deployment rollback

#### Step 5.3: Add Monitoring
- [ ] Create CloudWatch dashboard
- [ ] Set up alarms for service health
- [ ] Configure deployment notifications

---

### Phase 6: Production Readiness (Week 4)

#### Step 6.1: Create Production Environment
- [ ] Create `prod.tfvars` with prod settings
- [ ] Deploy prod infrastructure
- [ ] Configure custom domain
- [ ] Add HTTPS certificate

#### Step 6.2: Setup Blue-Green Deployment
- [ ] Configure ECS blue-green deployment
- [ ] Test deployment with traffic shifting
- [ ] Verify rollback works

#### Step 6.3: Load Testing
- [ ] Run load tests against dev
- [ ] Verify auto-scaling works
- [ ] Test under failure conditions

---

## Priority Order

### 🔴 Must Fix Before Any Deployment
1. Create service-specific workflows
2. Fix Terraform workflow structure
3. Configure Docker registry (GitHub Container Registry or AWS ECR)
4. Add service context path configuration

### 🟡 Must Fix Before Production
5. Update CD workflow for ECS
6. Environment-specific configurations
7. Secrets management
8. Database migration integration
9. Health check integration
10. Monitoring and alerting

### 🟢 Nice to Have
11. Rollback strategy
12. Frontend deployment
13. Blue-green deployment
14. Advanced monitoring

---

## Estimated Timeline

- **Phase 1-2**: 1-2 weeks (Critical fixes + Infrastructure)
- **Phase 3-4**: 1-2 weeks (Service deployment)
- **Phase 5**: 1 week (Automation)
- **Phase 6**: 1 week (Production readiness)

**Total**: 4-6 weeks for complete production-ready deployment

---

## Next Immediate Steps

1. **Add Context Path**: Configure `server.servlet.context-path` in each service

2. **Create Service Workflows**: Create actual CI/CD workflow files for each service

3. **Fix Terraform Workflow**: Update to match current `infra/` structure

4. **Configure Registry**: Set up GitHub Container Registry or AWS ECR

5. **Deploy Infrastructure**: Run terraform apply to create AWS resources

6. **Test End-to-End**: Deploy one service and test complete flow

Would you like to proceed with creating a detailed step-by-step implementation plan?
