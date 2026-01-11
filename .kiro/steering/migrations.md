---
inclusion: fileMatch
fileMatchPattern: "**/migrations/**"
---

# Database Migrations Guide

## Overview

CoreMS uses a distributed migration approach:
- **Migration runner** lives in `core-microservices/migrations/runner/`
- **SQL files** live in each service repo under `migrations/`
- Runner discovers and executes migrations from all installed services

## Structure

Each service repo:
```
<service>-ms/
└── migrations/
    ├── setup/      # V1.0.x - Schema setup
    └── mockdata/   # R__xx - Dev/Stage seed data
```

Core toolkit:
```
core-microservices/
└── migrations/
    ├── runner/     # Flyway runner app
    └── core/       # Core migrations (extensions)
```

## Schemas

| Schema | Service | Tables |
|--------|---------|--------|
| `migrations` | Flyway | flyway_schema_history |
| `user_ms` | user-ms | app_user, app_user_role, login_token |
| `document_ms` | document-ms | document, document_tags, document_access_token |
| `communication_ms` | communication-ms | message, email, sms, email_attachment |
| `translation_ms` | translation-ms | translation_bundles |

## Naming Conventions

### Versioned Migrations (setup/)
- Format: `V{major}.{minor}.{patch}__{description}.sql`
- Example: `V1.0.0__create_user_schema.sql`
- Run once, tracked by checksum

### Repeatable Migrations (mockdata/)
- Format: `R__{order}_{description}.sql`
- Example: `R__01_users_roles.sql`
- Re-run when checksum changes

## Best Practices

### Development vs Production
- **Pre-v1.0 Development**: V1.0.0 migrations can be modified directly for schema changes
- **Post-v1.0 Release**: All schema changes must use new versioned migrations (V1.0.1, V1.0.2, etc.)
- **Checksum Changes**: Flyway tracks checksums - modifying existing migrations in production will cause failures

### Primary Keys
- **New tables**: Use `BIGSERIAL` for primary keys (maps to `Long` in JPA)
- **Legacy tables**: Keep existing `SERIAL` for backward compatibility
- **Rationale**: `BIGINT` prevents overflow issues and is modern best practice

### Schema Creation
```sql
CREATE SCHEMA IF NOT EXISTS schema_name;
SET search_path TO schema_name;
-- tables here
RESET search_path;
```

### Tables
- Always use `IF NOT EXISTS`
- Use explicit constraint names: `CONSTRAINT fk_{table}_{ref_table} FOREIGN KEY ...`
- Add `created_at` indexes for time-based queries
- Use `TIMESTAMP WITH TIME ZONE` for timestamps

### Foreign Keys
```sql
-- Good: explicit naming
CONSTRAINT fk_user_role_user FOREIGN KEY (user_id) REFERENCES app_user(id) ON DELETE CASCADE

-- Avoid: auto-generated names
user_id INTEGER REFERENCES app_user(id)
```

### Mockdata
- Use `ON CONFLICT DO UPDATE` or `ON CONFLICT DO NOTHING` for idempotency
- Use fixed UUIDs for test data (e.g., `20000000-0000-0000-0000-000000000001`)

## Running Migrations

```bash
# From core-microservices/
./setup.sh migrate                    # Schema only
./setup.sh migrate --mockdata         # Include seed data
./setup.sh migrate --mockdata --clean # Clean + migrate (dev only)
```

## Roles Reference

From `CoreMsRoles` enum (don't use SYSTEM or SUPER_ADMIN in mockdata):
- `USER_MS_ADMIN`, `USER_MS_USER`
- `COMMUNICATION_MS_ADMIN`, `COMMUNICATION_MS_USER`
- `DOCUMENT_MS_ADMIN`, `DOCUMENT_MS_USER`
- `TRANSLATION_MS_ADMIN`

## Entity Sync

Always sync migrations with actual JPA entities in each service repo.
