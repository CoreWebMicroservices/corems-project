# Service Integration Guide

## Overview
This guide explains how to integrate one microservice with another in the CoreMS project.

## Steps to Connect Services

### 1. Add Client Dependency to POM
Add the target service's client dependency to your service's `pom.xml`:

```xml
<!-- In <service>-service/pom.xml -->
<dependency>
    <groupId>com.corems.targetms</groupId>
    <artifactId>target-client</artifactId>
    <version>${project.version}</version>
</dependency>
```

**Example**: Communication service connecting to Template service:
```xml
<dependency>
    <groupId>com.corems.templatems</groupId>
    <artifactId>template-client</artifactId>
    <version>${project.version}</version>
</dependency>
```

### 2. Configure Base URL in application.yaml
Add the target service's base URL configuration to `application.yaml`:

```yaml
# In <service>-service/src/main/resources/application.yaml
targetms.base-url: ${TARGET-SERVICE-BASE-URL:http://localhost:300X}
```

**Example**: Communication service connecting to Template service:
```yaml
templatems.base-url: ${TEMPLATE-SERVICE-BASE-URL:http://localhost:3004}
```

**Port Reference**:
- User Service: 3000
- Communication Service: 3001
- Document Service: 3002
- Translation Service: 3003
- Template Service: 3004

### 3. Configure Docker Compose
Add the target service's base URL override to `docker-compose.yaml`:

```yaml
# In <service>-ms/docker/docker-compose.yaml
environment:
  - TARGET-SERVICE-BASE-URL=http://target-ms:300X
```

**Example**: Communication service connecting to Template service:
```yaml
environment:
  - TEMPLATE-SERVICE-BASE-URL=http://template-ms:3004
```

### 4. Inject Client API in AppConfig
Inject the target service's API client in your service's `AppConfig`:

```java
// In <service>-service/src/main/java/.../app/config/AppConfig.java
import com.corems.targetms.client.TargetApi;

@Configuration
public class AppConfig {
    private final TargetApi targetApi;

    public AppConfig(TargetApi targetApi) {
        this.targetApi = targetApi;
    }
}
```

**Example**: Communication service with Template service:
```java
import com.corems.templatems.client.RenderingApi;

@Configuration
public class AppConfig {
    private final RenderingApi renderingApi;

    public AppConfig(RenderingApi renderingApi) {
        this.renderingApi = renderingApi;
    }
}
```

### 5. Use Client API in Service Layer
Inject the API client into your service and use it:

```java
// In your service class
@Component
@RequiredArgsConstructor
public class YourService {
    private final TargetApi targetApi;

    public void doSomething() {
        // Call target service API
        var result = targetApi.someMethod(...);
    }
}
```

**Example**: Communication service rendering templates:
```java
@Component
@RequiredArgsConstructor
public class EmailService {
    private final RenderingApi renderingApi;

    public String renderTemplate(String templateId, Map<String, Object> params) {
        // Call template service to render
        var result = renderingApi.renderTemplate(templateId, params);
        return result.getRenderedContent();
    }
}
```

## Available Client APIs by Service

### Template Service (3004)
- `TemplatesApi` - Template CRUD operations
- `RenderingApi` - Template rendering with parameters

### Document Service (3002)
- `DocumentApi` - Document upload, download, delete operations

### User Service (3000)
- `UserApi` - User management operations
- `AuthApi` - Authentication operations

### Translation Service (3003)
- `TranslationApi` - Translation management operations

## Error Handling
When calling other services, handle potential errors:

```java
try {
    var result = targetApi.someMethod(...);
} catch (WebClientResponseException e) {
    log.error("Failed to call target service: {}", e.getMessage());
    throw ServiceException.of(
        YourServiceExceptionReasonCodes.EXTERNAL_SERVICE_ERROR,
        "Failed to call target service: " + e.getMessage()
    );
}
```

## Testing
When testing services that depend on other services:
- Mock the client API in unit tests
- Use real clients in integration tests
- Use `@SpringBootTest(webEnvironment = RANDOM_PORT)` for integration tests

```java
@SpringBootTest(webEnvironment = RANDOM_PORT)
public class YourServiceIntegrationTest {
    @MockBean
    private TargetApi targetApi;

    @Test
    public void testWithMockedDependency() {
        when(targetApi.someMethod(...)).thenReturn(...);
        // Test your service
    }
}
```
