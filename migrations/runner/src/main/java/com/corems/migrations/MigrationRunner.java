package com.corems.migrations;

import org.flywaydb.core.Flyway;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

import javax.sql.DataSource;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Stream;

/**
 * Migration runner that discovers and executes Flyway migrations for each service separately.
 * 
 * Each service gets its own Flyway execution with its own schema for history tracking.
 * This allows each service to have independent versioning (V1.0.0, V1.0.1, etc.)
 */
@SpringBootApplication
public class MigrationRunner implements CommandLineRunner {

    private final DataSource dataSource;

    @Value("${migrations.include-mockdata:false}")
    private boolean includeMockdata;

    @Value("${migrations.clean-before-migrate:false}")
    private boolean cleanBeforeMigrate;

    @Value("${migrations.service-filter:}")
    private String serviceFilter;

    @Value("${migrations.repos-path:../../repos}")
    private String reposPath;

    public MigrationRunner(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    public static void main(String[] args) {
        SpringApplication.run(MigrationRunner.class, args);
    }

    @Override
    public void run(String... args) throws Exception {
        System.out.println(">>> Starting migrations...");
        System.out.println(">>> Include mockdata: " + includeMockdata);
        System.out.println(">>> Clean before migrate: " + cleanBeforeMigrate);
        
        if (serviceFilter != null && !serviceFilter.isEmpty()) {
            System.out.println(">>> Service filter: " + serviceFilter);
        }
        
        // Run core migrations first (only if no service filter)
        if (serviceFilter == null || serviceFilter.isEmpty()) {
            runCoreMigrations();
        }
        
        // Discover and run migrations for each service
        List<ServiceMigration> services = discoverServices();
        
        if (services.isEmpty()) {
            System.out.println(">>> WARNING: No service migrations found!");
            return;
        }
        
        // Filter services if specified
        if (serviceFilter != null && !serviceFilter.isEmpty()) {
            services = services.stream()
                    .filter(service -> service.name.equals(serviceFilter))
                    .toList();
            
            if (services.isEmpty()) {
                System.out.println(">>> ERROR: Service not found: " + serviceFilter);
                System.out.println(">>> Available services:");
                discoverServices().forEach(s -> System.out.println("    - " + s.name));
                return;
            }
        }
        
        for (ServiceMigration service : services) {
            runServiceMigration(service);
        }
        
        System.out.println(">>> All migrations completed!");
    }
    
    private void runCoreMigrations() {
        Path corePath = Path.of("../core");
        if (!Files.exists(corePath)) {
            System.out.println(">>> No core migrations found, skipping...");
            return;
        }
        
        System.out.println(">>> Running core migrations...");
        
        Flyway flyway = Flyway.configure()
                .dataSource(dataSource)
                .schemas("migrations")
                .defaultSchema("migrations")
                .createSchemas(true)
                .locations("filesystem:" + corePath.toAbsolutePath())
                .table("flyway_schema_history")
                .cleanDisabled(!cleanBeforeMigrate)
                .baselineOnMigrate(true)
                .baselineVersion("0")
                .load();
        
        if (cleanBeforeMigrate) {
            flyway.clean();
        }
        
        var result = flyway.migrate();
        System.out.println(">>> Core migrations executed: " + result.migrationsExecuted);
    }
    
    private void runServiceMigration(ServiceMigration service) {
        System.out.println(">>> Running migrations for: " + service.name);
        
        List<String> locations = new ArrayList<>();
        locations.add("filesystem:" + service.setupPath.toAbsolutePath());
        
        if (includeMockdata && service.mockdataPath != null && Files.exists(service.mockdataPath)) {
            locations.add("filesystem:" + service.mockdataPath.toAbsolutePath());
            System.out.println("    Including mockdata");
        }
        
        // Each service uses its own schema for flyway history
        // Schema name derived from service name: user-ms -> user_ms
        String schemaName = service.name.replace("-", "_");
        
        Flyway flyway = Flyway.configure()
                .dataSource(dataSource)
                .schemas(schemaName)
                .defaultSchema(schemaName)
                .createSchemas(true)
                .locations(locations.toArray(new String[0]))
                .table("flyway_schema_history")  // Each schema has its own history table
                .cleanDisabled(!cleanBeforeMigrate)
                .baselineOnMigrate(true)
                .baselineVersion("0")
                .load();
        
        if (cleanBeforeMigrate) {
            System.out.println("    WARNING: Cleaning schema " + schemaName);
            flyway.clean();
        }
        
        var result = flyway.migrate();
        System.out.println("    Migrations executed: " + result.migrationsExecuted);
        System.out.println("    Schema version: " + result.targetSchemaVersion);
    }
    
    private List<ServiceMigration> discoverServices() throws Exception {
        List<ServiceMigration> services = new ArrayList<>();
        
        Path reposDir = Path.of(reposPath);
        if (!Files.exists(reposDir) || !Files.isDirectory(reposDir)) {
            System.out.println(">>> Repos directory not found: " + reposDir.toAbsolutePath());
            return services;
        }
        
        try (Stream<Path> dirs = Files.list(reposDir)) {
            dirs.filter(Files::isDirectory).forEach(servicePath -> {
                Path setupPath = servicePath.resolve("migrations/setup");
                Path mockdataPath = servicePath.resolve("migrations/mockdata");
                
                if (Files.exists(setupPath)) {
                    String serviceName = servicePath.getFileName().toString();
                    // Only process *-ms services (skip parent, common, frontend)
                    if (serviceName.endsWith("-ms")) {
                        services.add(new ServiceMigration(
                            serviceName,
                            setupPath,
                            Files.exists(mockdataPath) ? mockdataPath : null
                        ));
                        System.out.println(">>> Found service: " + serviceName);
                    }
                }
            });
        }
        
        return services;
    }
    
    private record ServiceMigration(String name, Path setupPath, Path mockdataPath) {}
}
