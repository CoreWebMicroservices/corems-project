---
inclusion: always
---

# Core Microservices - Project Guidelines

## Project Context

This is an enterprise-grade microservices toolkit demonstrating modern architecture patterns for rapid application development. The project includes both backend services (Java Spring Boot) and a modular frontend (React + TypeScript).

**Main Repository**: https://github.com/CoreWebMicroservices/corems-project
**Architecture**: Distributed microservices with separate GitHub repositories per service

## Repository Structure

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
```

### Service Development
1. **Each service is a separate GitHub repository** under CoreWebMicroservices org
2. **Use setup.sh for all operations** - don't run services manually
3. **Environment files**: Each service has its own `.env` file (never commit these)
4. **Database migrations**: Use `./setup.sh migrate <service>` for schema changes
5. **Testing**: Use `./setup.sh test <service>` for service-specific tests

## Backend Architecture (Java Spring Boot)

### Service Structure
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
├── migrations/             # Database migrations
│   ├── setup/             # Schema (V1.0.x)
│   └── mockdata/          # Seed data (R__xx)
└── docker/                # Service containerization
```

### Code Standards
- **OpenAPI-first development**: Define API spec before implementation
- **Generated models**: Use generated DTOs, avoid custom POJOs
- **Autoconfiguration**: Include `com.corems.common:autoconfig-starter`
- **Minimal comments**: Code should be self-explanatory
- **Role-based security**: Use `@RequireRoles(CoreMsRoles.SERVICE_ADMIN)`

### Database Guidelines
- **Schema per service**: `user_ms`, `communication_ms`, etc.
- **UUID primary keys**: Use `UUID` type, not `VARCHAR(36)`
- **Sequence allocation**: Use `allocationSize = 1` for sequences
- **Migration sync**: Keep migrations in sync with JPA entities

## Frontend Architecture (React + TypeScript)

The frontend follows a modular architecture with domain-driven design principles. See `frontend-guidelines.md` for detailed frontend development guidelines.

### Key Principles
- **Modular Design**: Independent business logic modules
- **App-Level Composition**: Centralized routing and cross-module communication
- **Type Safety**: Full TypeScript coverage
- **State Management**: Hookstate for global state, local state for components
- **API Integration**: Centralized API layer with error handling

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

## Security & Authentication

### Backend Security
- **JWT Authentication**: All services use shared JWT validation
- **Role-based Access**: Use `CoreMsRoles` enum for permissions
- **OAuth2 Integration**: Google, GitHub, LinkedIn support
- **Identity Resolution**: Use `SecurityUtils.getUserPrincipal()`

### Frontend Security
- **Configurable AuthGuards**: Route protection based on roles
- **Token Management**: Automatic refresh and storage
- **Multi-provider OAuth**: Support for multiple social logins

## Environment Management

### Service Environment Files
Each service maintains its own `.env` file:
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

### Commit Standards
- Keep commit messages minimal and concise
- Use conventional commit format: `feat:`, `fix:`, `refactor:`
- Focus on what changed, not implementation details

### Security
- **Never commit .env files**: Always in .gitignore
- **Use .env-example**: Template files for environment setup
- **Secret scanning**: GitHub will block pushes with secrets

## Testing Strategy

### Backend Testing
- **Integration Tests**: Use generated API clients (`*Api` classes)
- **Real Authentication**: Don't use `@WithMockUser` with HTTP clients
- **Random Ports**: Use `@SpringBootTest(webEnvironment = RANDOM_PORT)`
- **Test Data**: Use unique emails to avoid conflicts

### Frontend Testing
- **Component Testing**: Focus on user interactions
- **API Mocking**: Mock backend responses for isolated testing
- **E2E Testing**: Test complete user workflows

## Documentation Standards

### README Files
Each service should have:
- Link to main project repository
- Brief feature overview
- Quick start instructions using setup.sh
- API endpoint documentation
- Environment variable reference

### API Documentation
- **OpenAPI specs**: Complete API documentation
- **Generated clients**: Type-safe API access
- **Postman collections**: Available for manual testing

## Performance & Scalability

### Backend Performance
- **Connection Pooling**: Configured for PostgreSQL
- **Caching**: Redis integration where appropriate
- **Async Processing**: RabbitMQ for background tasks

### Frontend Performance
- **Code Splitting**: Vite-based module loading
- **State Optimization**: Avoid global state pollution
- **API Caching**: React Query for server state

## Deployment & Operations

### Docker Strategy
- **Infrastructure first**: Start PostgreSQL, RabbitMQ, MinIO
- **Service dependencies**: Build parent → common → APIs → services
- **Environment-agnostic**: Generic Dockerfiles for any environment

### Monitoring
- **Health Checks**: All services expose `/actuator/health`
- **Logging**: Centralized logging configuration
- **Metrics**: Prometheus-ready endpoints

## When Writing Code

### Backend Development
1. Define OpenAPI spec first
2. Generate and build API models
3. Implement entities with proper JPA annotations
4. Create repositories extending `SearchableRepository`
5. Implement controllers using generated interfaces
6. Add integration tests with real HTTP calls
7. Update database migrations

### Frontend Development
1. Follow modular architecture - components in module folders
2. Use centralized routes from `@/app/router/routes`
3. Type everything with TypeScript
4. Use React Bootstrap components
5. Use CoreMsApi patterns for API calls
6. Make components configurable with props
7. Always display errors with ApiResponseAlert
8. Use environment variables for configuration

### General Guidelines
- **Security first**: Never expose sensitive data
- **Documentation**: Update README files for any changes
- **Testing**: Add tests for new functionality
- **Performance**: Consider caching and optimization
- **Maintainability**: Write self-explanatory code