---
inclusion: fileMatch
fileMatchPattern: "**/{pom.xml,application.yaml,db-config.yaml,security-config.yaml,.env-example}"
---

# Microservice Generation Phases

## Phase 1 - API & Skeleton (STOP for review)
1. Create `*-api` spec and `*-api/pom.xml` with codegen
2. Create `*-service/pom.xml` (minimal)
3. Create application class relying on auto-config starter
4. Add config files (see templates below):
   - `application.yaml` - main config with imports
   - `db-config.yaml` - database configuration
   - `security-config.yaml` - JWT and security settings
   - `.env-example` - environment variables template
   - `README.md`
5. Run: `mvn -pl <api-module-path> -am clean install -DskipTests=true`
6. **STOP for human review**

## Phase 2 - Entities & Repositories (STOP for review)
1. Implement JPA entities and repositories
2. Repositories MUST implement `SearchableRepository<T,ID>`
3. Expose metadata: `getSearchFields()`, `getAllowedFilterFields()`, `getAllowedSortFields()`, `getFieldAliases()`
4. Map DTOs carefully: Integer -> Long for ids, OffsetDateTime -> Instant
5. Run: `mvn -pl <service-module-path> -am clean install -DskipTests=true`
6. **STOP for human review**

## Phase 3 - Controllers, Services, Tests
1. Implement controllers using generated API interfaces
2. Business logic in service layer
3. Use `RequireRoles(CoreMsRoles.<SERVICE>_ADMIN)` for role-gated operations
4. Implement paginated listing with `PaginatedQueryExecutor.execute(...)`
5. Add integration tests (see integration-testing.md)
6. Run full build

## POM Guidance

### *-api POM
- Depend on `com.corems.common:api`
- Configure `maven-dependency-plugin` to unpack common API resources
- Configure `openapi-generator-maven-plugin` (no versions in child POMs)

### *-service POM
- Keep minimal
- Add runtime dependencies only
- Include `com.corems.common:autoconfig-starter`

## Configuration File Templates

### application.yaml
**Location**: `<service>-service/src/main/resources/application.yaml`

```yaml
server:
  port: ${SERVICE-NAME-PORT:300X}

spring:
  application:
    name: SERVICE-NAME
  main:
    banner-mode: off
  jackson:
    default-property-inclusion: non_null
  threads:
    virtual:
      enabled: ${VIRTUAL_THREADS_ENABLED:true}
  config:
    import: classpath:db-config.yaml, security-config.yaml

# Service-specific configuration
service-name:
  some-property: value
```

**Key Points**:
- Port uses environment variable with default fallback
- Application name in UPPERCASE with hyphens
- Always import db-config.yaml and security-config.yaml
- Banner mode off for cleaner logs
- Jackson configured to exclude null fields
- Virtual threads enabled by default (Java 21+ feature for better I/O concurrency)

### db-config.yaml
**Location**: `<service>-service/src/main/resources/db-config.yaml`

```yaml
spring:
  datasource:
    url: ${DATABASE_URL}
    username: ${DATABASE_USER}
    password: ${DATABASE_PASSWORD}
    driver-class-name: ${DATABASE_DRIVER_CLASS:org.postgresql.Driver}
  jpa:
    show-sql: false
    hibernate.ddl-auto: validate
    properties:
      hibernate:
        format_sql: true
        default_schema: ${DATABASE_SCHEMA:service_ms}
```

**Key Points**:
- All database credentials from environment variables
- `hibernate.ddl-auto: validate` - never auto-create schema
- Default schema matches service name with `_ms` suffix
- `show-sql: false` in production (use logging for debugging)

### security-config.yaml
**Location**: `<service>-service/src/main/resources/security-config.yaml`

```yaml
spring:
  security:
    cors:
      allowedOrigins: http://localhost:8080
    jwt:
      algorithm: ${AUTH_TOKEN_ALG:HS256}
      issuer: ${AUTH_TOKEN_ISSUER:corems}
      keyId: ${JWT_KEY_ID:corems-1}
      secretKey: ${AUTH_TOKEN_SECRET}
      privateKey: ${JWT_PRIVATE_KEY}
      publicKey: ${JWT_PUBLIC_KEY}
      refreshExpirationTimeInMinutes: 1440
      accessExpirationTimeInMinutes: 10
```

**Key Points**:
- CORS configured for local frontend
- JWT supports both symmetric (secretKey) and asymmetric (privateKey/publicKey)
- Standard token expiration times (10 min access, 24 hour refresh)
- Security is enabled by default via autoconfiguration
- To disable security for development: add `corems.security.enabled: false` to application.yaml

### .env-example
**Location**: `<service>-ms/.env-example`

```bash
## mandatory

# database
DATABASE_URL=jdbc:postgresql://localhost:5432/service_ms
DATABASE_USER=postgres
DATABASE_PASSWORD=postgres

# JWT symmetric key (for local development)
AUTH_TOKEN_SECRET=your-secret-key-here-min-256-bits

# service port
SERVICE-NAME-PORT=300X

## optional

# JWT RSA Keys (for production - generate with: openssl genrsa -out private.pem 2048 && openssl rsa -in private.pem -pubout -out public.pem)
# JWT_PRIVATE_KEY=
# JWT_PUBLIC_KEY=
```

**Key Points**:
- Separate mandatory and optional sections
- Use simple symmetric key (AUTH_TOKEN_SECRET) for local development
- RSA keys are optional for production use
- Service port matches application.yaml default
- Database URL includes schema name
- Never commit actual .env file (only .env-example)

## Lombok Dependency

**IMPORTANT**: Always add explicit Lombok dependency to `<service>-service/pom.xml`:

```xml
<dependency>
    <groupId>org.projectlombok</groupId>
    <artifactId>lombok</artifactId>
    <scope>provided</scope>
</dependency>
```

While parent POM configures Lombok in annotation processor paths, the explicit dependency ensures it's available during compilation. Other services may get it transitively, but always add it explicitly for new services.

## Port Allocation

**CRITICAL**: All services must run locally out of the box without port conflicts.

**Current Port Assignments**:
- 3000: user-ms
- 3001: communication-ms
- 3002: document-ms
- 3003: translation-ms
- 3004: template-ms
- 3005+: Available for new services

**Port Configuration Rules**:
1. Service default port in `application.yaml` MUST match client default port in `*ClientConfig.java`
2. Use next available port in sequence (3005, 3006, etc.)
3. Update this list when adding new services
4. Docker compose files must expose the same ports

**Example Port Configuration**:

Service (`application.yaml`):
```yaml
server:
  port: ${SERVICE-NAME-PORT:300X}
```

Client (`ServiceMsClientConfig.java`):
```java
@Value("${servicems.base-url:http://localhost:300X}")
private String serviceMsBaseUrl;
```

Both must use the same port number (300X).

## Docker Compose Configuration

**Location**: `<service>-ms/docker/docker-compose.yaml`

```yaml
services:
  service-name:
    build:
      context: ..
      dockerfile: docker/Dockerfile
    container_name: service-name
    ports:
      - "300X:300X"  # Must match application.yaml port
    environment:
      - DATABASE_URL=jdbc:postgresql://postgres:5432/service_ms
      - DATABASE_USER=postgres
      - DATABASE_PASSWORD=postgres
      - SERVICE-NAME-PORT=300X
      - JWT_PRIVATE_KEY=${JWT_PRIVATE_KEY}
      - JWT_PUBLIC_KEY=${JWT_PUBLIC_KEY}
    depends_on:
      - postgres
    networks:
      - corems-network

networks:
  corems-network:
    external: true
```

**Key Points**:
- Port mapping format: `"HOST:CONTAINER"` - both should match service port
- Container name matches service name
- Environment variables match .env-example
- Use external network `corems-network` for inter-service communication
- Database URL uses container name `postgres` not `localhost`
