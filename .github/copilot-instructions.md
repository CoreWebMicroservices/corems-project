# Core Microservices — Autoconfig-first LLM Instructions

This is a short, prescriptive guide for generating and implementing Core Microservices. It assumes a clean, autoconfiguration-first workflow: services depend on the shared auto-config starter and do not add legacy `@Enable*` annotations.

## Quick Intent

- Prefer the shared auto-configuration starter on the classpath. Service application classes should be minimal and should NOT declare `@EnableCoreMs*` annotations.
- Use the starter and documented replacement patterns only when intentionally opting out.

## Platform & Conventions

- Java 25, Spring Boot 4, Maven multi-module reactor
- PostgreSQL database, JWT Authentication
- RabbitMQ / Apache Kafka for messaging
- Shared code lives in `common/`. Do NOT edit `common` in service PRs.
- Generated API models (from `*-api`) are canonical DTOs. Do NOT duplicate them locally.

## Folder Layout

```
<service>-ms/
  <service>-api/          # OpenAPI spec + generated models (DO NOT implement logic here)
  <service>-client/       # ApiClient auto-config for other services
  <service>-service/      # Implementation
    src/main/java/.../app/
      controller/
      service/
      repository/
      entity/
      config/
    src/main/resources/
      application.yaml
      db-config.yaml
      security-config.yaml
```

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

Distributed migrations - each service owns its SQL files in `migrations/` folder.
Migration runner in toolkit discovers and runs migrations from `repos/*/migrations/`.

### Structure
```
<service>-ms/migrations/
├── setup/      # V1.0.x - Initial schema (mutable until v1.0.0)
├── mockdata/   # R__xx - Dev/Stage seed data (repeatable)
└── changes/    # V1.1.0+ - Post-production changes (immutable)
```

### Schemas
- `user_ms` → app_user, app_user_role, login_token
- `document_ms` → document, document_tags, document_access_token
- `communication_ms` → message, email, sms, email_attachment
- `translation_ms` → translation_bundles

### Migration Rules
- Always sync with JPA entities (check entity files before modifying)
- Use `CREATE SCHEMA IF NOT EXISTS`, `CREATE TABLE IF NOT EXISTS`
- Use explicit FK names: `CONSTRAINT fk_{table}_{ref} FOREIGN KEY ...`
- Add `created_at` indexes on all tables with timestamps
- Mockdata uses `ON CONFLICT DO UPDATE/NOTHING` for idempotency

### Naming
- Versioned: `V{major}.{minor}.{patch}__{description}.sql`
- Repeatable: `R__{order}_{description}.sql`

### Running
```bash
# Dev with mockdata
mvn spring-boot:run -Dspring-boot.run.arguments="--migrations.include-mockdata=true"

# Or with JAR
java -jar migrations/target/migrations-*.jar --migrations.include-mockdata=true

# Clean + migrate (dev only)
java -jar migrations/target/migrations-*.jar --migrations.include-mockdata=true --migrations.clean-before-migrate=true
```

### Test Users (mockdata)
Password: `Password123!`
- admin@corems.local (all admin roles)
- john.admin@corems.local (USER_MS_ADMIN)
- sarah.admin@corems.local (COMMUNICATION_MS_ADMIN)
- mike.docadmin@corems.local (DOCUMENT_MS_ADMIN)
- lisa.transadmin@corems.local (TRANSLATION_MS_ADMIN)
- 25 regular users with USER_MS_USER + various roles

## PR Checklist

- Avoided editing `common`
- Used generated models instead of local DTOs
- Ran API codegen + build for `*-api`
- Avoided re-declaring parent-managed plugins
- Did not commit `.gen` files
- Migration changes sync with entity changes
