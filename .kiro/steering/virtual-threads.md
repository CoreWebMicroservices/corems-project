---
inclusion: always
---

# Virtual Threads in CoreMS

## Overview

CoreMS uses Java 21+ Virtual Threads (Project Loom) to improve I/O-bound performance across all microservices. Virtual threads are lightweight threads managed by the JVM that enable high concurrency with minimal resource overhead.

## Why Virtual Threads?

CoreMS microservices are I/O-heavy:
- **Database operations** (PostgreSQL via JPA)
- **Service-to-service HTTP calls** (WebClient)
- **Message queue operations** (RabbitMQ)
- **File storage operations** (MinIO S3)
- **External API calls** (OAuth, email providers)

Virtual threads allow handling thousands of concurrent requests without the memory overhead of platform threads.

## Configuration

### Enabled by Default

All services have virtual threads enabled by default via `application.yaml`:

```yaml
spring:
  threads:
    virtual:
      enabled: ${VIRTUAL_THREADS_ENABLED:true}
```

### What Gets Virtual Threads Automatically

When enabled, Spring Boot automatically uses virtual threads for:
- ✅ **Tomcat request handling** - Each HTTP request runs on a virtual thread
- ✅ **@Async methods** - Async operations use virtual thread executor
- ✅ **@Scheduled tasks** - Scheduled tasks run on virtual threads
- ✅ **WebClient** - Service-to-service calls use virtual threads

### What Stays on Platform Threads

These components continue using platform threads (as designed):
- Database connection pools (HikariCP)
- RabbitMQ connection management
- Thread pool management itself

## Environment Configuration

### Local Development (.env)

```bash
# Virtual threads enabled by default
VIRTUAL_THREADS_ENABLED=true
```

### Docker Compose

```yaml
environment:
  - VIRTUAL_THREADS_ENABLED=true
```

### Disabling Virtual Threads

To disable (e.g., for debugging or comparison):

```bash
VIRTUAL_THREADS_ENABLED=false
```

## Best Practices

### ✅ DO: Let Virtual Threads Handle I/O

Virtual threads excel at I/O-bound operations:

```java
@RestController
@RequiredArgsConstructor
public class UserController {
    private final UserRepository userRepository;
    private final CommunicationApi communicationApi;
    
    @GetMapping("/users/{id}")
    public UserDto getUser(@PathVariable Long id) {
        // Database I/O - runs on virtual thread
        var user = userRepository.findById(id);
        
        // HTTP call to another service - runs on virtual thread
        var notifications = communicationApi.getUserNotifications(id);
        
        return mapToDto(user, notifications);
    }
}
```

### ✅ DO: Use @Async for Background Tasks

```java
@Service
public class EmailService {
    
    @Async  // Runs on virtual thread executor
    public CompletableFuture<Void> sendWelcomeEmail(String email) {
        // I/O operation - perfect for virtual threads
        emailProvider.send(email, "Welcome!");
        return CompletableFuture.completedFuture(null);
    }
}
```

### ❌ DON'T: Use for CPU-Intensive Tasks

Virtual threads are NOT suitable for CPU-bound operations:

```java
// BAD: CPU-intensive work on virtual thread
@GetMapping("/compute")
public Result heavyComputation() {
    // This blocks the virtual thread for CPU work
    return performComplexCalculation();  // ❌
}

// GOOD: Use platform thread pool for CPU work
@Service
public class ComputeService {
    private final ExecutorService cpuExecutor = 
        Executors.newFixedThreadPool(Runtime.getRuntime().availableProcessors());
    
    public CompletableFuture<Result> heavyComputation() {
        return CompletableFuture.supplyAsync(
            this::performComplexCalculation,
            cpuExecutor  // ✅ Platform threads for CPU work
        );
    }
}
```

### ❌ DON'T: Use ThreadLocal Excessively

Virtual threads can create millions of instances - avoid ThreadLocal:

```java
// BAD: ThreadLocal with virtual threads
private static final ThreadLocal<Context> context = new ThreadLocal<>();  // ❌

// GOOD: Use method parameters or request-scoped beans
@RequestScope
public class RequestContext {
    private String userId;
    // ... getters/setters
}
```

### ✅ DO: Use Structured Concurrency (Java 21+)

For parallel I/O operations:

```java
@Service
@RequiredArgsConstructor
public class DashboardService {
    private final UserApi userApi;
    private final DocumentApi documentApi;
    private final CommunicationApi communicationApi;
    
    public DashboardDto getDashboard(Long userId) {
        try (var scope = new StructuredTaskScope.ShutdownOnFailure()) {
            // All run concurrently on virtual threads
            var userTask = scope.fork(() -> userApi.getUser(userId));
            var docsTask = scope.fork(() -> documentApi.getUserDocuments(userId));
            var notifTask = scope.fork(() -> communicationApi.getNotifications(userId));
            
            scope.join();  // Wait for all
            scope.throwIfFailed();
            
            return new DashboardDto(
                userTask.get(),
                docsTask.get(),
                notifTask.get()
            );
        } catch (Exception e) {
            throw new ServiceException("Dashboard load failed", e);
        }
    }
}
```

## Monitoring & Observability

### JVM Metrics

Monitor virtual thread usage via JMX or Spring Boot Actuator:

```yaml
management:
  endpoints:
    web:
      exposure:
        include: metrics,health
  metrics:
    enable:
      jvm: true
```

### Key Metrics to Watch

- `jvm.threads.virtual.count` - Number of virtual threads
- `jvm.threads.platform.count` - Number of platform threads
- `http.server.requests` - Request latency (should improve)
- `hikaricp.connections.active` - DB connection usage

### Logging

Virtual threads appear in logs with `VirtualThread` prefix:

```
[VirtualThread-123] INFO  c.c.userms.service.UserService - Processing user request
```

## Performance Expectations

### Before Virtual Threads (Platform Threads)
- ~200 concurrent requests (limited by thread pool)
- ~1MB memory per thread
- Thread pool exhaustion under load

### After Virtual Threads
- Thousands of concurrent requests
- ~1KB memory per virtual thread
- Graceful scaling under load

### Typical Improvements
- **Throughput**: 2-5x increase for I/O-heavy endpoints
- **Latency**: Reduced tail latency (p99)
- **Memory**: Lower memory footprint under load
- **Scalability**: Better handling of traffic spikes

## Troubleshooting

### Issue: No Performance Improvement

**Check:**
1. Is `VIRTUAL_THREADS_ENABLED=true`?
2. Are you testing I/O-bound operations? (CPU-bound won't improve)
3. Is the bottleneck elsewhere? (database, network)

### Issue: Higher Memory Usage

**Cause:** Creating too many virtual threads simultaneously

**Solution:** Add rate limiting or use semaphores:

```java
private final Semaphore concurrencyLimit = new Semaphore(1000);

public void processRequest() {
    concurrencyLimit.acquire();
    try {
        // Process request
    } finally {
        concurrencyLimit.release();
    }
}
```

### Issue: Pinned Virtual Threads

**Cause:** Synchronized blocks or native calls pin virtual threads to platform threads

**Solution:** Use `ReentrantLock` instead of `synchronized`:

```java
// BAD: synchronized pins virtual thread
private synchronized void updateCache() {  // ❌
    cache.put(key, value);
}

// GOOD: ReentrantLock doesn't pin
private final ReentrantLock lock = new ReentrantLock();

private void updateCache() {  // ✅
    lock.lock();
    try {
        cache.put(key, value);
    } finally {
        lock.unlock();
    }
}
```

## Testing with Virtual Threads

### Integration Tests

Virtual threads work transparently in tests:

```java
@SpringBootTest(webEnvironment = RANDOM_PORT)
class UserControllerIntegrationTest {
    // Tests run with virtual threads enabled
    // No special configuration needed
}
```

### Load Testing

Test virtual thread performance with high concurrency:

```bash
# Apache Bench - 10000 requests, 1000 concurrent
ab -n 10000 -c 1000 http://localhost:3000/api/users

# Compare with virtual threads disabled
VIRTUAL_THREADS_ENABLED=false ./setup.sh start user-ms
ab -n 10000 -c 1000 http://localhost:3000/api/users
```

## Migration Checklist

When adding virtual threads to existing services:

- [ ] Add `spring.threads.virtual.enabled: ${VIRTUAL_THREADS_ENABLED:true}` to `application.yaml`
- [ ] Add `VIRTUAL_THREADS_ENABLED=true` to `.env-example`
- [ ] Add environment variable to `docker-compose.yaml`
- [ ] Review code for `synchronized` blocks (replace with `ReentrantLock`)
- [ ] Review ThreadLocal usage (minimize or remove)
- [ ] Test under load to verify improvements
- [ ] Monitor metrics after deployment

## References

- [JEP 444: Virtual Threads](https://openjdk.org/jeps/444)
- [Spring Boot Virtual Threads Support](https://spring.io/blog/2023/09/09/all-together-now-spring-boot-3-2-graalvm-native-images-java-21-and-virtual)
- [Java 21 Virtual Threads Guide](https://docs.oracle.com/en/java/javase/21/core/virtual-threads.html)
