---
inclusion: fileMatch
fileMatchPattern: "**/{entity,repository}/**/*.java"
---

# Entities & Repositories

## Entity Naming & Structure

### Naming Conventions
- **Entity Classes**: MUST have `Entity` suffix to avoid conflicts with API models
  - ✅ `UserEntity`, `RoleEntity`, `ActionTokenEntity`
  - ❌ `User`, `Role`, `ActionToken` (conflicts with generated API models)

### Field Naming Standards
- **Timestamps**: End with `At` suffix
  - ✅ `createdAt`, `updatedAt`, `lastLoginAt`, `expiresAt`
  - ❌ `created`, `modified`, `lastLogin`, `expiration`

- **Booleans**: Start with `is` prefix
  - ✅ `isActive`, `isEnabled`, `isVerified`, `isDeleted`
  - ❌ `active`, `enabled`, `verified`, `deleted`

### Primary Keys
- **Default**: Use `BIGSERIAL` (Long) with auto-increment for all new tables
  ```java
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;
  ```

- **UUID**: Only use when absolutely necessary (distributed systems, external references)
  ```java
  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private UUID uuid;
  ```

- **Sequence Allocation**: Always use `allocationSize = 1` for sequences
  ```java
  @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "user_seq")
  @SequenceGenerator(name = "user_seq", sequenceName = "user_id_seq", allocationSize = 1)
  ```

## Entity Annotations
```java
@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EqualsAndHashCode(onlyExplicitlyIncluded = true)
public class UserEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @EqualsAndHashCode.Include
    private Long id;
    
    @Column(unique = true, nullable = false)
    private UUID uuid;
    
    @Column(nullable = false)
    private String email;
    
    @Column(nullable = false)
    private Boolean isActive;
    
    @Column(nullable = false, updatable = false)
    private Instant createdAt;
    
    @Column(nullable = false)
    private Instant updatedAt;
    
    @PrePersist
    protected void onCreate() {
        uuid = UUID.randomUUID();
        createdAt = Instant.now();
        updatedAt = Instant.now();
    }
    
    @PreUpdate
    protected void onUpdate() {
        updatedAt = Instant.now();
    }
}
```

### Lombok Rules
- Use: `@Getter`, `@Setter`, `@NoArgsConstructor`, `@AllArgsConstructor`, `@Builder`
- Use: `@EqualsAndHashCode(onlyExplicitlyIncluded=true)` with id included
- Avoid `@Data` on JPA entities (causes issues with lazy loading)

### Column Annotations
- Use `@Column(nullable = false)` for required fields
- Use `@Column(unique = true)` for unique constraints
- Use `@Column(updatable = false)` for immutable fields (like createdAt)
- Use `@Column(length = X)` for VARCHAR fields with specific lengths

### Timestamp Management
- Use `Instant` type for all timestamps (not `LocalDateTime` or `OffsetDateTime`)
- Use `@PrePersist` and `@PreUpdate` for automatic timestamp management
- Store in UTC, convert to user timezone in presentation layer

## Repository Pattern
Repositories MUST implement `SearchableRepository<T,ID>`:

```java
public interface UserRepository extends JpaRepository<UserEntity, Long>, SearchableRepository<UserEntity, Long> {
    
    // JPA method naming - preferred approach
    Optional<UserEntity> findByUuid(UUID uuid);
    Optional<UserEntity> findByEmail(String email);
    List<UserEntity> findByIsActiveTrue();
    void deleteByExpiresAtBefore(Instant expirationTime);
    
    @Override
    default Set<String> getSearchFields() {
        return Set.of("email", "firstName", "lastName");
    }
    
    @Override
    default Set<String> getAllowedFilterFields() {
        return Set.of("provider", "isActive", "createdAt");
    }
    
    @Override
    default Set<String> getAllowedSortFields() {
        return Set.of("createdAt", "email", "firstName");
    }
    
    @Override
    default Map<String, String> getFieldAliases() {
        return Map.of();
    }
}
```

## JPA Method Naming Convention (CRITICAL)
**ALWAYS use JPA method naming conventions instead of custom @Query annotations unless absolutely necessary.**

### Preferred (JPA Method Names):
```java
// Good - JPA derives the query automatically
Optional<UserEntity> findByEmail(String email);
Optional<UserEntity> findByUuid(UUID uuid);
List<UserEntity> findByIsActiveAndCreatedAtAfter(Boolean isActive, Instant date);
void deleteByExpiresAtBefore(Instant date);
void deleteByUserUuidAndActionType(UUID userUuid, ActionType actionType);
boolean existsByEmail(String email);
long countByIsActiveTrue();
```

### Avoid (Custom Queries):
```java
// Avoid - only use when JPA method naming cannot express the query
@Query("SELECT u FROM User u WHERE u.email = :email")
Optional<User> findUserByEmail(@Param("email") String email);
```

### When Custom Queries Are Acceptable:
- Complex joins across multiple entities
- Aggregate functions (COUNT, SUM, etc.)
- Native SQL for database-specific features
- Performance-critical queries that need optimization

## DTO Mapping
Map DTOs carefully between generated models and entities:

### Type Conversions
- `Integer` (API) -> `Long` (Entity) for IDs
- `OffsetDateTime` (API) -> `Instant` (Entity) for timestamps
- `String` (API enum) -> `Enum` (Entity) for type-safe enums
- API models use wrapper types (Integer, Boolean) - Entity uses primitives where appropriate

### Mapping Example
```java
private UserInfo mapToUserInfo(UserEntity entity) {
    return new UserInfo()
        .userId(entity.getUuid())
        .email(entity.getEmail())
        .firstName(entity.getFirstName())
        .lastName(entity.getLastName())
        .isActive(entity.getIsActive())
        .createdAt(entity.getCreatedAt().atOffset(ZoneOffset.UTC))
        .updatedAt(entity.getUpdatedAt().atOffset(ZoneOffset.UTC));
}
```

## Relationships

### One-to-Many / Many-to-One
```java
@Entity
@Table(name = "users")
public class UserEntity {
    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<RoleEntity> roles = new ArrayList<>();
}

@Entity
@Table(name = "roles")
public class RoleEntity {
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private UserEntity user;
}
```

### Many-to-Many
```java
@Entity
@Table(name = "users")
public class UserEntity {
    @ManyToMany
    @JoinTable(
        name = "user_roles",
        joinColumns = @JoinColumn(name = "user_id"),
        inverseJoinColumns = @JoinColumn(name = "role_id")
    )
    private Set<RoleEntity> roles = new HashSet<>();
}
```

### Relationship Best Practices
- Use `FetchType.LAZY` by default (avoid N+1 queries)
- Use `Set` for many-to-many (prevents duplicates)
- Use `List` for one-to-many with ordering
- Always specify `mappedBy` on the non-owning side
- Use `cascade = CascadeType.ALL` carefully (understand implications)
- Use `orphanRemoval = true` when child cannot exist without parent

## Indexes & Constraints

### Database Indexes
```sql
-- Unique constraints
CREATE UNIQUE INDEX idx_users_email ON users(email);
CREATE UNIQUE INDEX idx_users_uuid ON users(uuid);

-- Performance indexes
CREATE INDEX idx_users_created_at ON users(created_at);
CREATE INDEX idx_users_is_active ON users(is_active);

-- Composite indexes
CREATE INDEX idx_users_active_created ON users(is_active, created_at);

-- Partial indexes (PostgreSQL)
CREATE UNIQUE INDEX idx_users_phone_unique 
ON users(phone_number) 
WHERE phone_number IS NOT NULL;
```

### JPA Indexes
```java
@Entity
@Table(
    name = "users",
    indexes = {
        @Index(name = "idx_users_email", columnList = "email", unique = true),
        @Index(name = "idx_users_created_at", columnList = "created_at")
    }
)
public class UserEntity {
    // ...
}
```

## Soft Delete Pattern
```java
@Entity
@Table(name = "users")
@SQLDelete(sql = "UPDATE users SET is_deleted = true, deleted_at = NOW() WHERE id = ?")
@Where(clause = "is_deleted = false")
public class UserEntity {
    @Column(nullable = false)
    private Boolean isDeleted = false;
    
    private Instant deletedAt;
}
```

## Audit Fields Pattern
```java
@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
public abstract class AuditableEntity {
    @CreatedDate
    @Column(nullable = false, updatable = false)
    private Instant createdAt;
    
    @LastModifiedDate
    @Column(nullable = false)
    private Instant updatedAt;
    
    @CreatedBy
    @Column(updatable = false)
    private UUID createdBy;
    
    @LastModifiedBy
    private UUID updatedBy;
}

// Usage
@Entity
@Table(name = "users")
public class UserEntity extends AuditableEntity {
    // Entity-specific fields only
}
```

## Common Pitfalls to Avoid

### ❌ Don't Do This
```java
// Wrong: Entity name conflicts with API model
public class User { }

// Wrong: Poor field naming
private LocalDateTime created;
private boolean active;

// Wrong: Using Integer for auto-increment IDs
@Id
@GeneratedValue(strategy = GenerationType.IDENTITY)
private Integer id;

// Wrong: Custom query when JPA method naming works
@Query("SELECT u FROM UserEntity u WHERE u.email = :email")
Optional<UserEntity> getUser(@Param("email") String email);

// Wrong: Eager loading by default
@OneToMany(fetch = FetchType.EAGER)
private List<RoleEntity> roles;
```

### ✅ Do This Instead
```java
// Correct: Entity suffix avoids conflicts
public class UserEntity { }

// Correct: Proper field naming
private Instant createdAt;
private Boolean isActive;

// Correct: Long for auto-increment IDs
@Id
@GeneratedValue(strategy = GenerationType.IDENTITY)
private Long id;

// Correct: JPA method naming
Optional<UserEntity> findByEmail(String email);

// Correct: Lazy loading by default
@OneToMany(fetch = FetchType.LAZY)
private List<RoleEntity> roles;
```

## Paginated Queries
Use `PaginatedQueryExecutor.execute(...)` for listing endpoints:

```java
UsersPagedResponse response = PaginatedQueryExecutor.execute(
    userRepository,
    page, pageSize, sort, search, filter,
    this::mapToUserInfo
);
```
