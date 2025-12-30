-- ============================================================================
-- V1.0.0 - Core PostgreSQL extensions
-- ============================================================================
-- Required extensions for all CoreMS services
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create migrations schema for Flyway tracking
CREATE SCHEMA IF NOT EXISTS migrations;
COMMENT ON SCHEMA migrations IS 'Database migration tracking';
