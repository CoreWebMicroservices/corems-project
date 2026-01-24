---
inclusion: fileMatch
fileMatchPattern: "**/*.java"
---

# Exception Handling Guidelines

## Use ServiceException with ExceptionReasonCodes Enum

**CRITICAL**: Always use `com.corems.common.exception.ServiceException` with an enum that implements `ExceptionReasonCodes` for all business logic errors. This ensures the common error handler processes exceptions consistently across all services.

### ❌ DON'T Create Custom Exception Classes

```java
// WRONG - Custom exception won't be handled by common error handler
public class TemplateNotFoundException extends RuntimeException {
    public TemplateNotFoundException(String message) {
        super(message);
    }
}

throw new TemplateNotFoundException("Template not found");
```

### ❌ DON'T Use String Reason Codes

```java
// WRONG - ServiceException requires an enum, not a string
throw ServiceException.of(
    "TEMPLATE_NOT_FOUND",  // String is not accepted
    "Template 'welcome-email' not found", 
    HttpStatus.NOT_FOUND
);
```

### ✅ DO Use ServiceException with ExceptionReasonCodes Enum

```java
// CORRECT - ServiceException with enum implementing ExceptionReasonCodes
import com.corems.common.exception.ServiceException;
import com.corems.templatems.app.exception.TemplateServiceExceptionReasonCodes;

throw ServiceException.of(
    TemplateServiceExceptionReasonCodes.TEMPLATE_NOT_FOUND,  // Enum value
    "Template 'welcome-email' not found"  // Optional additional message
);
```

## Creating Service-Specific Exception Reason Codes

Each service should define its own enum implementing `ExceptionReasonCodes`:

```java
package com.corems.templatems.app.exception;

import com.corems.common.exception.handler.ExceptionReasonCodes;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import lombok.ToString;
import org.springframework.http.HttpStatus;

@Getter
@RequiredArgsConstructor
@ToString
public enum TemplateServiceExceptionReasonCodes implements ExceptionReasonCodes {

    TEMPLATE_EXISTS("template.exists", HttpStatus.CONFLICT, "Template already exists"),
    TEMPLATE_NOT_FOUND("template.not_found", HttpStatus.NOT_FOUND, "Template not found"),
    INVALID_TEMPLATE_SYNTAX("template.invalid_syntax", HttpStatus.BAD_REQUEST, "Invalid template syntax"),
    TEMPLATE_RENDERING_FAILED("template.rendering_failed", HttpStatus.INTERNAL_SERVER_ERROR, "Template rendering failed");

    private final String errorCode;
    private final HttpStatus httpStatus;
    private final String description;
}
```

## ServiceException API

### Basic Usage
```java
// With reason code enum and optional message
ServiceException.of(ExceptionReasonCodeEnum, String details)

// With reason code enum only (uses description from enum)
ServiceException.of(ExceptionReasonCodeEnum)
```

**Note**: ServiceException does not currently support passing the original exception cause. Only the error message can be included in the details parameter.

### Common Patterns

**Not Found (404)**
```java
throw ServiceException.of(
    TemplateServiceExceptionReasonCodes.TEMPLATE_NOT_FOUND, 
    "Template with ID " + templateId + " not found"
);
```

**Bad Request (400)**
```java
throw ServiceException.of(
    TemplateServiceExceptionReasonCodes.INVALID_INPUT, 
    "Email format is invalid"
);
```

**Conflict (409)**
```java
throw ServiceException.of(
    TemplateServiceExceptionReasonCodes.TEMPLATE_EXISTS, 
    "Template with ID " + templateId + " already exists"
);
```

**Internal Server Error (500)**
```java
throw ServiceException.of(
    TemplateServiceExceptionReasonCodes.RENDERING_FAILED, 
    "Failed to process request: " + e.getMessage()
);
```

## Using Default Exception Reason Codes

For common errors, use `DefaultExceptionReasonCodes` from common module:

```java
import com.corems.common.exception.handler.DefaultExceptionReasonCodes;

throw ServiceException.of(
    DefaultExceptionReasonCodes.UNAUTHORIZED, 
    "Invalid credentials"
);

throw ServiceException.of(
    DefaultExceptionReasonCodes.NOT_FOUND, 
    "Resource not found"
);

throw ServiceException.of(
    DefaultExceptionReasonCodes.SERVER_ERROR, 
    "Unexpected error occurred"
);
```

## Error Code Conventions

Use descriptive, lowercase error codes with dots:

- `template.not_found`
- `template.exists`
- `template.invalid_syntax`
- `user.not_found`
- `user.unauthorized`

## Wrapping External Exceptions

When catching exceptions from external libraries, include the error message in the details:

```java
try {
    Template template = handlebars.compileInline(content);
} catch (IOException e) {
    throw ServiceException.of(
        TemplateServiceExceptionReasonCodes.TEMPLATE_COMPILATION_FAILED,
        "Failed to compile template: " + e.getMessage()
    );
}
```

**Note**: The original exception cause cannot be passed to ServiceException. Consider logging the original exception before throwing ServiceException if stack trace information is needed for debugging.

## Error Response Format

The common error handler returns errors in this format:

```json
{
  "timestamp": "2024-01-18T10:30:00Z",
  "status": 404,
  "error": "Not Found",
  "message": "Template 'welcome-email' not found",
  "path": "/api/templates/welcome-email",
  "reasonCode": "template.not_found"
}
```

## Best Practices

1. **Always use ServiceException with enum** - Never create custom exception classes or use string reason codes
2. **Create service-specific enums** - Define ExceptionReasonCodes enum for each service
3. **Provide clear messages** - Include context (IDs, field names, etc.) and original error messages
4. **Use appropriate HTTP status codes** - Match the error type in enum definition
5. **Include reason codes** - For programmatic error handling
6. **Log exceptions before throwing** - Use `log.error()` with the original exception for debugging since cause cannot be passed
7. **Don't expose internal details** - Sanitize error messages for users

## Examples from Existing Services

### User Service
```java
UserEntity user = userRepository.findByUuid(userId)
    .orElseThrow(() -> ServiceException.of(
        UserServiceExceptionReasonCodes.USER_NOT_FOUND, 
        "User with ID " + userId + " not found"
    ));
```

### Template Service
```java
if (templateRepository.findByTemplateIdAndIsDeletedFalse(templateId).isPresent()) {
    throw ServiceException.of(
        TemplateServiceExceptionReasonCodes.TEMPLATE_EXISTS,
        "Template with ID " + templateId + " already exists"
    );
}
```

### Communication Service
```java
try {
    emailService.send(message);
} catch (Exception e) {
    log.error("Failed to send email", e);  // Log with original exception
    throw ServiceException.of(
        DefaultExceptionReasonCodes.SERVER_ERROR,
        "Failed to send email: " + e.getMessage()
    );
}
```
