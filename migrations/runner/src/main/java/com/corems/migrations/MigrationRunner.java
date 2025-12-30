package com.corems.migrations;

import org.flywaydb.core.Flyway;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

import javax.sql.DataSource;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Stream;

/**
 * Migration runner that discovers and executes Flyway migrations from installed services.
 * 
 * Scans:
 * - migrations/core/     : Core migrations (extensions, etc.)
 * - repos/{service}/migrations/setup/    : Service schema setup
 * - repos/{service}/migrations/mockdata/ : Service seed data (optional)
 */
@SpringBootApplication
public class MigrationRunner implements CommandLineRunner {

    private final DataSource dataSource;

    @Value("${migrations.include-mockdata:false}")
    private boolean includeMockdata;

    @Value("${migrations.clean-before-migrate:false}")
    private boolean cleanBeforeMigrate;

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
        List<String> locations = discoverMigrationLocations();

        System.out.println(">>> Discovered migration locations:");
        locations.forEach(loc -> System.out.println("    - " + loc));

        Flyway flyway = Flyway.configure()
                .dataSource(dataSource)
                .schemas("migrations")
                .defaultSchema("migrations")
                .createSchemas(true)
                .locations(locations.toArray(new String[0]))
                .cleanDisabled(!cleanBeforeMigrate)
                .baselineOnMigrate(true)
                .baselineVersion("0")
                .load();

        if (cleanBeforeMigrate) {
            System.out.println(">>> WARNING: Cleaning database before migration!");
            flyway.clean();
        }

        var result = flyway.migrate();

        System.out.println(">>> Migration completed!");
        System.out.println(">>> Migrations executed: " + result.migrationsExecuted);
        System.out.println(">>> Schema version: " + result.targetSchemaVersion);
    }

    private List<String> discoverMigrationLocations() throws IOException {
        List<String> locations = new ArrayList<>();

        // Core migrations (always included)
        Path corePath = Path.of("../core");
        if (Files.exists(corePath)) {
            locations.add("filesystem:" + corePath.toAbsolutePath());
        }

        // Discover service migrations from repos/
        Path reposDir = Path.of(reposPath);
        if (Files.exists(reposDir) && Files.isDirectory(reposDir)) {
            try (Stream<Path> services = Files.list(reposDir)) {
                services.filter(Files::isDirectory).forEach(servicePath -> {
                    Path setupPath = servicePath.resolve("migrations/setup");
                    Path mockdataPath = servicePath.resolve("migrations/mockdata");

                    if (Files.exists(setupPath)) {
                        locations.add("filesystem:" + setupPath.toAbsolutePath());
                        System.out.println(">>> Found migrations for: " + servicePath.getFileName());
                    }

                    if (includeMockdata && Files.exists(mockdataPath)) {
                        locations.add("filesystem:" + mockdataPath.toAbsolutePath());
                        System.out.println(">>> Including mockdata for: " + servicePath.getFileName());
                    }
                });
            }
        }

        if (locations.isEmpty()) {
            System.out.println(">>> WARNING: No migration locations found!");
        }

        return locations;
    }
}
