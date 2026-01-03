# Core Microservices — Project Instructions

This is a comprehensive guide for developing with the Core Microservices toolkit. The project uses a distributed repository approach with separate GitHub repositories for each service under the CoreWebMicroservices organization.

## Project Structure

**Main Repository**: https://github.com/CoreWebMicroservices/corems-project
**Architecture**: Distributed microservices with separate GitHub repositories per service

```
corems-project/                    # Main toolkit (this repo)
├── repos/                         # Service repositories (cloned by setup.sh)
│   ├── parent/                    # Maven parent POM
│   ├── common/                    # Shared libraries
│   ├── user-ms/                   # User management service
│   ├── communication-ms/          # Email/SMS/notifications
│   ├── document-ms/               # File storage & management
│   ├── translation-ms/            # Internationalization
│   └── frontend/                  # React frontend application
├── docker/                        # Infrastructure (PostgreSQL, RabbitMQ, MinIO)
├── migrations/                    # Database migration runner
└── setup.sh                      # Build & deployment automation
```

## Development Workflow

### Quick Start Commands
```bash
# Clone and setup entire stack
git clone https://github.com/CoreWebMicroservices/corems-project.git
cd corems-project

# Start infrastructure
./setup.sh infra

# Build and start all services
./setup.sh start-all

# Individual service operations
./setup.sh build user-ms
./setup.sh start user-ms
./setup.sh stop user-ms
./setup.sh logs user-ms
./setup.sh migrate user-ms
```

### Service Development Guidelines
1. **Each service is a separate GitHub repository** under CoreWebMicroservices org
2. **Use setup.sh for all operations** - don't run services manually
3. **Environment files**: Each service has its own `.env` file (never commit these)
4. **Database migrations**: Use `./setup.sh migrate <service>` for schema changes
5. **Testing**: Use `./setup.sh test <service>` for service-specific tests

## Platform & Conventions

- **Backend**: Java 21+, Spring Boot 3.4+, Maven multi-module reactor
- **Frontend**: React 18+, TypeScript, Vite, React Bootstrap
- **Database**: PostgreSQL with schema per service
- **Authentication**: JWT with OAuth2 (Google, GitHub, LinkedIn)
- **Messaging**: RabbitMQ / Apache Kafka
- **Storage**: MinIO (S3-compatible)
- **Containerization**: Docker with docker-compose per service

### Repository Strategy
- **Main toolkit**: Contains setup scripts, infrastructure, and migration runner
- **Service repositories**: Separate GitHub repos for each microservice
- **Shared libraries**: `common/` module with autoconfiguration
- **Generated models**: API-first development with OpenAPI codegen

## Service Structure

```
<service>-ms/
├── <service>-api/          # OpenAPI spec + generated models
├── <service>-client/       # Generated API client
├── <service>-service/      # Implementation
│   └── src/main/java/.../app/
│       ├── controller/     # REST endpoints
│       ├── service/        # Business logic
│       ├── repository/     # Data access
│       ├── entity/         # JPA entities
│       └── config/         # Configuration
│   └── src/main/resources/
│       ├── application.yaml
│       ├── db-config.yaml
│       └── security-config.yaml
├── migrations/             # Database migrations
│   ├── setup/             # Schema (V1.0.x)
│   └── mockdata/          # Seed data (R__xx)
└── docker/                # Service containerization
```

## Service URLs & Ports

### Development Environment
- **Frontend**: http://localhost:8080
- **User Service**: http://localhost:3000
- **Communication Service**: http://localhost:3001
- **Document Service**: http://localhost:3002
- **Translation Service**: http://localhost:3003

### Infrastructure
- **PostgreSQL**: localhost:5432
- **RabbitMQ**: localhost:5672 (Management: 15672)
- **MinIO**: localhost:9000 (Console: 9001)

## Autoconfiguration-First Rules

- Include shared auto-config starter: `com.corems.common:autoconfig-starter`
- Also add `com.corems.common:logging` in service POM for compile-time resolution
- Starter wires logging, error handling, security automatically
- If excluding shared security, document why and provide replacement beans

## Roles (CoreMsRoles enum)

```java
// User Microservice
USER_MS_ADMIN, USER_MS_USER

// Communication Microservice
COMMUNICATION_MS_ADMIN, COMMUNICATION_MS_USER

// Translation Microservice
TRANSLATION_MS_ADMIN

// Document Microservice
DOCUMENT_MS_ADMIN, DOCUMENT_MS_USER

// System roles
SYSTEM, SUPER_ADMIN
```

## Security Rules

- Use `com.corems.common.security.SecurityUtils`:
  - `SecurityUtils.getUserPrincipal()` - returns UserPrincipal or throws UNAUTHORIZED
  - `SecurityUtils.getUserPrincipalOptional()` - returns Optional<UserPrincipal>
- Resolve identity from Spring Security only; cast to `UserPrincipal` in service layer
- Do NOT rely on X-User or client-supplied headers
- Use `@RequireRoles(CoreMsRoles.<SERVICE>_ADMIN)` for role-gated operations

## OpenAPI Checklist

- Place spec at: `*-api/src/main/resources/<service>-api.yaml`
- Include `servers:` section
- Every operation MUST have explicit `operationId` (camelCase)
- Reuse `.gen/common-api.yaml` components for shared responses/parameters
- Add validation constraints in schema (pattern, minLength/maxLength)
- Run codegen + compile before implementing logic

## Entities & Lombok

- Use: `@Getter`, `@Setter`, `@NoArgsConstructor`, `@AllArgsConstructor`
- Use: `@EqualsAndHashCode(onlyExplicitlyIncluded=true)` with id included
- Avoid `@Data` on JPA entities
- Repositories MUST implement `SearchableRepository<T,ID>`

## Integration Testing

**CRITICAL**: `@WithMockUser` does NOT work with generated API clients making real HTTP requests.

Use real authentication flow:
```java
private TokenResponse createUserAndAuthenticate() {
    authenticationApi.signUp(signUpRequest);
    TokenResponse tokenResponse = authenticationApi.signIn(signInRequest);
    apiClient.setBearerToken(tokenResponse.getAccessToken());
    return tokenResponse;
}
```

Generated API clients throw `RestClientResponseException` (not `ApiException`):
```java
assertThatThrownBy(() -> authenticationApi.signIn(invalidRequest))
    .isInstanceOf(RestClientResponseException.class)
    .satisfies(ex -> assertThat(((RestClientResponseException) ex)
        .getStatusCode().value()).isEqualTo(400));
```

## Code Style

### Import Style
- Prefer explicit imports for generated models and nested enums
- Example: `import com.corems.communicationms.api.model.MessageResponse.SentByTypeEnum;`

### Commenting Policy
- Keep code self-explanatory; comments are exceptional
- Allow: short rationale, links to issues/specs, brief markers for logical blocks
- Remove: comments that restate code (`// set userId`, `// populate sender info`)
- Use Javadoc for public APIs (required for controller/service methods)
- Tag actionable items: `TODO:` / `FIXME:` with owner/ticket

## Generation Phases (MANDATORY pauses)

### Phase 1 — API & Skeleton (STOP for review)
1. Create `*-api` spec and POM with codegen
2. Create `*-service/pom.xml` and minimal application class
3. Add config files: `application.yaml`, `db-config.yaml`, `security-config.yaml`
4. Run: `mvn -pl <api-module-path> -am clean install -DskipTests=true`
5. **STOP for human review**

### Phase 2 — Entities & Repositories (STOP for review)
1. Implement JPA entities and repositories
2. Repositories implement `SearchableRepository<T,ID>` with metadata methods
3. Map DTOs: Integer -> Long for ids, OffsetDateTime -> Instant
4. Run: `mvn -pl <service-module-path> -am clean install -DskipTests=true`
5. **STOP for human review**

### Phase 3 — Controllers, Services, Tests
1. Implement controllers using generated API interfaces
2. Business logic in service layer
3. Add integration tests using real auth flow (not @WithMockUser)
4. Run full build with tests

## Database Migrations

Each service owns its migrations in `<service>-ms/migrations/` folder.
Migration runner in main toolkit discovers and executes migrations from all services.

### Structure
```
<service>-ms/migrations/
├── setup/      # V1.0.x - Schema setup
└── mockdata/   # R__xx - Dev/Stage seed data
```

### Schemas per Service
- `user_ms` → app_user, app_user_role, login_token
- `document_ms` → document, document_tags, document_access_token
- `communication_ms` → message, email, sms, email_attachment
- `translation_ms` → translation_bundles

### Running Migrations
```bash
# Run migrations for specific service
./setup.sh migrate user-ms

# Run all migrations
./setup.sh migrate

# Include mockdata (development)
./setup.sh migrate --mockdata
```

## Environment Management

### Service Environment Files
Each service maintains its own `.env` file (never commit these):
```bash
# Database
SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/<service>_ms
SPRING_DATASOURCE_USERNAME=postgres
SPRING_DATASOURCE_PASSWORD=postgres

# Service Configuration
SERVER_PORT=300x
```

### Frontend Environment
```bash
VITE_API_URL=http://localhost
VITE_USER_MS_PORT=3000
VITE_COMMUNICATION_MS_PORT=3001
VITE_DOCUMENT_MS_PORT=3002
VITE_TRANSLATION_MS_PORT=3003
```

## Git & Repository Management

### Repository Strategy
- **Main toolkit**: https://github.com/CoreWebMicroservices/corems-project
- **Individual services**: Separate repositories under CoreWebMicroservices org
- **No git history migration**: Focus on functionality over history

### Security
- **Never commit .env files**: Always in .gitignore
- **Use .env-example**: Template files for environment setup
- **Secret scanning**: GitHub will block pushes with secrets

## Frontend Development (React + TypeScript)

### Architecture Principles
- **Modular Design**: Independent business logic modules
- **App-Level Composition**: Centralized routing and cross-module communication
- **Type Safety**: Full TypeScript coverage
- **State Management**: Hookstate for global state, local state for components

### Key Guidelines
- Use global imports: `@/app/layout/AppLayout` (never relative imports)
- Centralized routes from `@/app/router/routes`
- No cross-module imports between business modules
- Use React Bootstrap for all UI components
- API integration via centralized `CoreMsApi` layer

## PR Checklist

### Backend
- ✅ Avoided editing `common` directly
- ✅ Used generated models instead of local DTOs
- ✅ Ran API codegen + build for `*-api`
- ✅ Migration changes sync with entity changes
- ✅ Added integration tests with real HTTP calls
- ✅ Updated service README if needed

### Frontend
- ✅ Followed modular architecture principles
- ✅ Used centralized routes and global imports
- ✅ Added proper TypeScript types
- ✅ Used React Bootstrap components
- ✅ Implemented proper error handling with MessageHandler

### General
- ✅ Did not commit `.env` files
- ✅ Updated documentation for any changes
- ✅ Tested with `./setup.sh` commands
- ✅ Verified service starts and health checks pass
