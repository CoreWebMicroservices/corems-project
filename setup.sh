#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOS_DIR="$SCRIPT_DIR/repos"
INFRA_DIR="$SCRIPT_DIR/infra"
DOCKER_DIR="$SCRIPT_DIR/docker"
GITHUB_ORG="CoreWebMicroservices"
GITHUB_BASE="https://github.com/$GITHUB_ORG"

# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_banner() {
    echo -e "${BLUE}"
    echo "   ____               __  __ _                                 _               "
    echo "  / ___|___  _ __ ___|  \/  (_) ___ _ __ ___  ___  ___ _ ____   _(_) ___ ___  ___ "
    echo " | |   / _ \| '__/ _ \ |\/| | |/ __| '__/ _ \/ __|/ _ \ '__\ \ / / |/ __/ _ \/ __|"
    echo " | |__| (_) | | |  __/ |  | | | (__| | | (_) \__ \  __/ |   \ V /| | (_|  __/\__ \\"
    echo "  \____\___/|_|  \___|_|  |_|_|\___|_|  \___/|___/\___|_|    \_/ |_|\___\___||___/"
    echo -e "${NC}"
    echo ""
}

ensure_docker_network() {
    if ! docker network inspect corems-network >/dev/null 2>&1; then
        log_info "Creating corems-network..."
        docker network create corems-network
    fi
}

check_env() {
    if [ ! -f "$SCRIPT_DIR/.env" ]; then
        log_error ".env file not found"
        log_warn "Copy .env-example to .env and configure it:"
        echo "  cp .env-example .env"
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Environment Commands
# -----------------------------------------------------------------------------
cmd_create_env() {
    local target="${1:-all}"
    
    log_info "Creating environment files..."
    
    case "$target" in
        all)
            create_main_env
            create_service_envs
            ;;
        main)
            create_main_env
            ;;
        services)
            create_service_envs
            ;;
        *-ms)
            create_individual_service_env "$target"
            ;;
        *)
            log_error "Unknown env target: $target"
            echo "Usage: ./setup.sh create-env [all|main|services|<service-name>]"
            echo "Examples:"
            echo "  ./setup.sh create-env all"
            echo "  ./setup.sh create-env services"
            echo "  ./setup.sh create-env user-ms"
            exit 1
            ;;
    esac
    
    log_success "Environment files created!"
}

create_main_env() {
    if [ -f "$SCRIPT_DIR/.env" ]; then
        log_warn "Main .env already exists, skipping..."
        return
    fi
    
    log_info "Creating main .env file..."
    cp "$SCRIPT_DIR/.env-example" "$SCRIPT_DIR/.env"
    log_success "Created main .env file"
}

create_service_envs() {
    log_info "Creating service environment files..."
    
    if [ ! -d "$REPOS_DIR" ]; then
        log_error "No services found. Run './setup.sh init' first."
        return 1
    fi
    
    for service_dir in "$REPOS_DIR"/*/; do
        if [ -d "$service_dir" ]; then
            local service_name=$(basename "$service_dir")
            
            # Skip non-service directories
            if [[ "$service_name" == "parent" || "$service_name" == "common" ]]; then
                continue
            fi
            
            create_individual_service_env "$service_name"
        fi
    done
}

create_individual_service_env() {
    local service_name="$1"
    local service_dir="$REPOS_DIR/$service_name"
    local env_file="$service_dir/.env"
    
    if [ ! -d "$service_dir" ]; then
        log_error "Service not found: $service_name"
        return 1
    fi
    
    if [ -f "$env_file" ]; then
        log_warn "$service_name: .env already exists, skipping..."
        return
    fi
    
    log_info "Creating .env for $service_name..."
    
    # Handle frontend differently - copy from .env.local
    if [[ "$service_name" == "frontend" ]]; then
        local env_local_file="$service_dir/.env.local"
        if [ -f "$env_local_file" ]; then
            cp "$env_local_file" "$env_file"
            log_success "Created .env for $service_name (from .env.local)"
        else
            log_warn "$service_name: .env.local not found, skipping..."
        fi
    else
        # For other services, copy from their own .env-example
        local service_env_example="$service_dir/.env-example"
        if [ -f "$service_env_example" ]; then
            cp "$service_env_example" "$env_file"
            log_success "Created .env for $service_name (from service .env-example)"
        else
            log_warn "$service_name: .env-example not found, skipping..."
        fi
    fi
}

# -----------------------------------------------------------------------------
# Repository Commands
# -----------------------------------------------------------------------------
cmd_init() {
    log_info "Initializing Core Microservices..."
    
    mkdir -p "$REPOS_DIR"
    
    # Clone infrastructure repo
    clone_infra
    
    # Clone required repos
    log_info "Cloning required repositories..."
    clone_repo "parent"
    clone_repo "common"
    
    log_success "Initialization complete!"
    echo ""
    echo "Next steps:"
    echo "  ./setup.sh add user-ms document-ms    # Add services"
    echo "  ./setup.sh init-base                  # Add base services + frontend"
    echo "  ./setup.sh list                       # Show available services"
}

cmd_init_base() {
    log_info "Initializing Core Microservices with base services..."
    
    mkdir -p "$REPOS_DIR"
    
    # Clone infrastructure repo
    clone_infra
    
    # Clone required repos and base services
    log_info "Cloning required repositories and base services..."
    clone_repo "parent"
    clone_repo "common"
    clone_repo "user-ms"
    clone_repo "document-ms"
    clone_repo "communication-ms"
    clone_repo "translation-ms"
    clone_repo "frontend"
    
    log_success "Base initialization complete!"
    echo ""
    echo "Base services installed:"
    echo "  ✓ parent (Maven parent POM)"
    echo "  ✓ common (Shared libraries)"
    echo "  ✓ user-ms (User management service)"
    echo "  ✓ document-ms (File storage & management)"
    echo "  ✓ communication-ms (Email/SMS/notifications)"
    echo "  ✓ translation-ms (Internationalization)"
    echo "  ✓ frontend (React frontend application)"
    echo ""
    echo "Next steps:"
    echo "  ./setup.sh build all                  # Build all services"
    echo "  ./setup.sh start-all                  # Start complete stack"
}

cmd_init_all() {
    log_info "Checking and fetching all available repositories..."
    
    mkdir -p "$REPOS_DIR"
    
    # Clone infrastructure repo
    clone_infra
    
    # List of all known repositories in the CoreWebMicroservices organization
    local all_repos=(
        "parent"
        "common"
        "user-ms"
        "document-ms"
        "communication-ms"
        "translation-ms"
        "frontend"
    )
    
    log_info "Fetching all repositories from $GITHUB_ORG organization..."
    
    for repo in "${all_repos[@]}"; do
        clone_repo "$repo"
    done
    
    log_success "All repositories initialized!"
    echo ""
    echo "All available services installed:"
    echo "  ✓ parent (Maven parent POM)"
    echo "  ✓ common (Shared libraries)"
    echo "  ✓ user-ms (User management service)"
    echo "  ✓ document-ms (File storage & management)"
    echo "  ✓ communication-ms (Email/SMS/notifications)"
    echo "  ✓ translation-ms (Internationalization)"
    echo "  ✓ frontend (React frontend application)"
    echo ""
    echo "Next steps:"
    echo "  ./setup.sh build all                  # Build all services"
    echo "  ./setup.sh start-all                  # Start complete stack"
}

cmd_add() {
    if [ $# -eq 0 ]; then
        log_error "No services specified. Usage: ./setup.sh add <service1> <service2> ..."
        echo ""
        cmd_list
        exit 1
    fi
    
    mkdir -p "$REPOS_DIR"
    
    for service in "$@"; do
        clone_repo "$service"
    done
    
    log_success "Services added!"
}

cmd_list() {
    echo "Installed:"
    if [ -d "$REPOS_DIR" ]; then
        local found=false
        for dir in "$REPOS_DIR"/*/; do
            if [ -d "$dir" ]; then
                found=true
                local repo_name=$(basename "$dir")
                local branch=$(cd "$dir" && git branch --show-current 2>/dev/null || echo "unknown")
                echo "  ✓ $repo_name ($branch)"
            fi
        done
        if [ "$found" = false ]; then
            echo "  (none)"
        fi
    else
        echo "  (none)"
    fi
}

cmd_update() {
    log_info "Updating all repositories..."
    
    if [ ! -d "$REPOS_DIR" ]; then
        log_error "No services found. Run './setup.sh init' first."
        exit 1
    fi
    
    for dir in "$REPOS_DIR"/*/; do
        if [ -d "$dir/.git" ]; then
            repo_name=$(basename "$dir")
            log_info "Updating $repo_name..."
            (cd "$dir" && git pull)
        fi
    done
    
    log_success "All repositories updated!"
}

cmd_checkout() {
    local branch="${1:-main}"
    
    log_info "Checking out '$branch' branch for all services..."
    
    if [ ! -d "$REPOS_DIR" ]; then
        log_error "No services found. Run './setup.sh init' first."
        exit 1
    fi
    
    for dir in "$REPOS_DIR"/*/; do
        if [ -d "$dir/.git" ]; then
            repo_name=$(basename "$dir")
            log_info "Checking out $repo_name to $branch..."
            (cd "$dir" && git fetch && git checkout "$branch" && git pull) || log_warn "Failed to checkout $repo_name"
        fi
    done
    
    log_success "All repositories checked out to '$branch'!"
}

cmd_cleanup() {
    log_info "Cleaning up merged branches in all services..."
    
    if [ ! -d "$REPOS_DIR" ]; then
        log_error "No services found. Run './setup.sh init' first."
        exit 1
    fi
    
    for dir in "$REPOS_DIR"/*/; do
        if [ -d "$dir/.git" ]; then
            repo_name=$(basename "$dir")
            log_info "Cleaning $repo_name..."
            (
                cd "$dir"
                git fetch --prune
                git checkout main 2>/dev/null || git checkout master 2>/dev/null || true
                
                # Delete local branches that have been merged into main/master
                local merged_branches=$(git branch --merged | grep -v "^\*" | grep -v "main" | grep -v "master" | xargs)
                if [ -n "$merged_branches" ]; then
                    echo "  Deleting merged branches: $merged_branches"
                    git branch -d $merged_branches 2>/dev/null || true
                else
                    echo "  No merged branches to delete"
                fi
            )
        fi
    done
    
    log_success "Cleanup complete!"
}

# -----------------------------------------------------------------------------
# Full Stack Commands
# -----------------------------------------------------------------------------
cmd_start_all() {
    log_info "Starting complete CoreMS stack..."
    
    check_env
    ensure_docker_network
    
    # Build all dependencies and services first
    log_info "Building all dependencies and services..."
    build_dependencies
    build_services
    
    # Start infrastructure first
    log_info "Starting infrastructure services..."
    docker_start_infra_component "postgres"
    docker_start_infra_component "rabbitmq" 
    docker_start_infra_component "s3-minio"
    
    # Wait for infrastructure to be ready
    log_info "Waiting for infrastructure to be ready..."
    sleep 10
    
    # Start all application services
    log_info "Starting all application services..."
    docker_start_all_services
    
    log_success "Complete CoreMS stack started!"
}

cmd_stop_all() {
    log_info "Stopping complete CoreMS stack..."
    
    docker_stop "all"
    
    log_success "CoreMS stack stopped!"
}

cmd_restart_all() {
    log_info "Restarting complete CoreMS stack..."
    cmd_stop_all
    sleep 2
    cmd_start_all
}

# -----------------------------------------------------------------------------
# Full Stack Command
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Helper function to get all service directories
# -----------------------------------------------------------------------------
get_service_dirs() {
    if [ ! -d "$REPOS_DIR" ]; then
        return
    fi
    
    for service_dir in "$REPOS_DIR"/*/; do
        if [ -d "$service_dir" ]; then
            local service_name=$(basename "$service_dir")
            # Skip non-service directories
            if [[ "$service_name" != "parent" && "$service_name" != "common" && "$service_name" != "frontend" ]]; then
                echo "$service_dir"
            fi
        fi
    done
}

# -----------------------------------------------------------------------------
# Helper function to find module by pattern
# -----------------------------------------------------------------------------
find_module() {
    local service_dir="$1"
    local pattern="$2"
    
    for module_dir in "$service_dir"*/; do
        if [ -d "$module_dir" ]; then
            local module_name=$(basename "$module_dir")
            if [[ "$module_name" == *"$pattern" ]]; then
                echo "$module_name"
                return
            fi
        fi
    done
}

# -----------------------------------------------------------------------------
# Helper function to build modules by type
# -----------------------------------------------------------------------------
build_modules_by_type() {
    local module_type="$1"
    local step_num="$2"
    
    log_info "$step_num. Building $module_type modules..."
    
    while IFS= read -r service_dir; do
        local service_name=$(basename "$service_dir")
        local module=$(find_module "$service_dir" "$module_type")
        
        if [ -n "$module" ]; then
            log_info "   Building $service_name ($module)..."
            (cd "$service_dir" && mvn clean install -pl "$module" -DskipTests)
        else
            log_warn "   $service_name: No *-$module_type module found, skipping..."
        fi
    done < <(get_service_dirs)
}
cmd_build() {
    local target="${1:-all}"
    
    log_info "Building dependencies in correct order..."
    
    if [ ! -d "$REPOS_DIR" ]; then
        log_error "No services found. Run './setup.sh init' first."
        exit 1
    fi
    
    case "$target" in
        deps|dependencies)
            build_dependencies
            ;;
        all)
            build_dependencies
            build_services
            ;;
        services)
            build_services
            ;;
        *-ms)
            # Individual service build
            build_individual_service "$target"
            ;;
        *)
            log_error "Unknown build target: $target"
            echo "Usage: ./setup.sh build [deps|services|all|<service-name>]"
            echo "Examples:"
            echo "  ./setup.sh build deps"
            echo "  ./setup.sh build communication-ms"
            echo "  ./setup.sh build user-ms"
            exit 1
            ;;
    esac
    
    log_success "Build complete!"
}

# -----------------------------------------------------------------------------
# Build Commands
# -----------------------------------------------------------------------------
build_dependencies() {
    # Step 1: Build parent (needed by everything)
    if [ -d "$REPOS_DIR/parent" ]; then
        log_info "1. Building parent..."
        (cd "$REPOS_DIR/parent" && mvn clean install -DskipTests)
    else
        log_warn "parent not found, skipping..."
    fi
    
    # Step 2: Build common (depends on parent, needed by all services)
    if [ -d "$REPOS_DIR/common" ]; then
        log_info "2. Building common..."
        (cd "$REPOS_DIR/common" && mvn clean install -DskipTests)
    else
        log_warn "common not found, skipping..."
    fi
    
    # Step 3: Build all *-api modules (needed by clients)
    build_modules_by_type "api" "3"
    
    # Step 4: Build all *-client modules (needed by services)
    build_modules_by_type "client" "4"
}

build_services() {
    # Step 5: Build all *-service modules
    build_modules_by_type "service" "5"
}

# -----------------------------------------------------------------------------
# Individual Service Build
# -----------------------------------------------------------------------------
build_individual_service() {
    local service_name="$1"
    local service_dir="$REPOS_DIR/$service_name"
    
    if [ ! -d "$service_dir" ]; then
        log_error "Service not found: $service_name"
        log_info "Available services:"
        for dir in "$REPOS_DIR"/*/; do
            if [ -d "$dir" ]; then
                local name=$(basename "$dir")
                if [[ "$name" != "parent" && "$name" != "common" ]]; then
                    echo "  - $name"
                fi
            fi
        done
        exit 1
    fi
    
    log_info "Building individual service: $service_name"
    
    # Handle frontend differently (Node.js project)
    if [[ "$service_name" == "frontend" ]]; then
        log_info "  Building frontend (Node.js project)..."
        (cd "$service_dir" && npm ci && npm run build)
    else
        # Build the entire service (all modules) with clean install
        log_info "  Building all modules for $service_name..."
        (cd "$service_dir" && mvn clean install -DskipTests)
    fi
    
    log_success "Built $service_name successfully!"
}

# -----------------------------------------------------------------------------
# Migration Commands
# -----------------------------------------------------------------------------
cmd_migrate() {
    log_info "Running database migrations..."
    
    check_env
    
    # Load environment variables from .env
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
    
    local args=""
    local service_filter=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --mockdata) args="$args --migrations.include-mockdata=true"; shift ;;
            --clean) args="$args --migrations.clean-before-migrate=true"; shift ;;
            --service) service_filter="$2"; shift 2 ;;
            *-ms) service_filter="$1"; shift ;;
            *) shift ;;
        esac
    done
    
    if [ -n "$service_filter" ]; then
        args="$args --migrations.service-filter=$service_filter"
        log_info "Running migrations for service: $service_filter"
    fi
    
    cd "$SCRIPT_DIR/migrations/runner"
    mvn spring-boot:run -Dspring-boot.run.arguments="$args"
}

# -----------------------------------------------------------------------------
# Docker Commands
# -----------------------------------------------------------------------------
cmd_docker() {
    local action="${1:-help}"
    local component="${2:-}"
    
    case "$action" in
        start)   docker_start "$component" ;;
        up)      docker_start "$component" ;;
        stop)    docker_stop "$component" ;;
        restart) docker_stop "$component"; sleep 2; docker_start "$component" ;;
        rebuild) docker_rebuild_with_build "$component" ;;
        logs)    docker_logs "$component" ;;
        status)  docker_status ;;
        clean)   docker_clean ;;
        *)       docker_help ;;
    esac
}

docker_help() {
    echo "Docker management commands:"
    echo ""
    echo "Usage: ./setup.sh docker <action> [component]"
    echo ""
    echo "Actions:"
    echo "  start <component>   Start component(s) (quick - no rebuild)"
    echo "  up <component>      Alias for start"
    echo "  stop <component>    Stop component(s)"
    echo "  restart <component> Restart component(s)"
    echo "  rebuild <component> Maven build + Docker rebuild + start (slow)"
    echo "  logs <component>    View logs"
    echo "  status              Show status of all containers"
    echo "  clean               Stop all and remove volumes"
    echo ""
    echo "Components:"
    echo "  infra      All infrastructure (postgres, rabbitmq, minio)"
    echo "  services   All microservices (from services/*/docker/)"
    echo "  all        Everything"
    echo "  postgres   PostgreSQL database"
    echo "  rabbitmq   RabbitMQ message broker"
    echo "  minio      MinIO S3 storage"
    echo ""
    echo "Examples:"
    echo "  ./setup.sh docker start all      # Quick start (daily development)"
    echo "  ./setup.sh docker rebuild all    # Full rebuild (when needed)"
    echo "  ./setup.sh docker logs postgres"
    echo "  ./setup.sh docker status"
}

docker_start() {
    local component="$1"
    
    if [ -z "$component" ]; then
        log_error "Please specify a component (infra, services, all, postgres, rabbitmq, minio, or service name like communication-ms)"
        return 1
    fi
    
    check_env
    ensure_docker_network
    
    case "$component" in
        infra)
            docker_start_infra_component "postgres"
            docker_start_infra_component "rabbitmq"
            docker_start_infra_component "s3-minio"
            ;;
        services)
            docker_start_all_services_quick
            ;;
        all)
            docker_start_infra_component "postgres"
            docker_start_infra_component "rabbitmq"
            docker_start_infra_component "s3-minio"
            docker_start_all_services_quick
            ;;
        postgres|rabbitmq|s3-minio)
            docker_start_infra_component "$component"
            ;;
        minio)
            docker_start_infra_component "s3-minio"
            ;;
        *-ms|frontend)
            docker_start_individual_service_quick "$component"
            ;;
        *)
            log_error "Unknown component: $component"
            echo "Available components:"
            echo "  infra, services, all, postgres, rabbitmq, minio"
            echo "  Individual services: communication-ms, user-ms, document-ms, translation-ms, frontend"
            return 1
            ;;
    esac
    
    log_success "Done!"
}

docker_start_infra_component() {
    local component="$1"
    local file="$DOCKER_DIR/infra/${component}-compose.yaml"
    
    if [ -f "$file" ]; then
        log_info "Starting $component..."
        docker-compose --env-file "$SCRIPT_DIR/.env" -f "$file" up -d
    else
        log_error "Compose file not found: $file"
        return 1
    fi
}

docker_start_all_services() {
    log_info "Starting all services from repos/*/docker/..."
    
    if [ ! -d "$REPOS_DIR" ]; then
        log_warn "No repos directory found. Run './setup.sh init' first."
        return
    fi
    
    # First, ensure all services are built
    log_info "Ensuring all services are built..."
    build_services
    
    local found=false
    while IFS= read -r service_dir; do
        local service_name=$(basename "$service_dir")
        docker_start_individual_service "$service_name"
        found=true
    done < <(get_service_dirs)
    
    # Also check frontend
    if [ -d "$REPOS_DIR/frontend/docker" ]; then
        docker_start_individual_service "frontend"
        found=true
    fi
    
    if [ "$found" = false ]; then
        log_warn "No services with docker-compose files found"
    fi
}

docker_start_all_services_quick() {
    log_info "Starting all services (quick - no rebuild)..."
    
    if [ ! -d "$REPOS_DIR" ]; then
        log_warn "No repos directory found. Run './setup.sh init' first."
        return
    fi
    
    local found=false
    while IFS= read -r service_dir; do
        local service_name=$(basename "$service_dir")
        docker_start_individual_service_quick "$service_name"
        found=true
    done < <(get_service_dirs)
    
    # Also check frontend
    if [ -d "$REPOS_DIR/frontend/docker" ]; then
        docker_start_individual_service_quick "frontend"
        found=true
    fi
    
    if [ "$found" = false ]; then
        log_warn "No services with docker-compose files found"
    fi
}

docker_start_individual_service() {
    local service_name="$1"
    local service_dir="$REPOS_DIR/$service_name"
    local compose_file="$service_dir/docker/docker-compose.yaml"
    local compose_file_alt="$service_dir/docker/docker-compose.yml"
    local env_file="$service_dir/.env"
    
    if [ ! -d "$service_dir" ]; then
        log_error "Service not found: $service_name"
        return 1
    fi
    
    # Build the service first
    log_info "Building $service_name before starting..."
    build_individual_service "$service_name"
    
    if [ -f "$compose_file" ]; then
        log_info "Starting $service_name..."
        if [ -f "$env_file" ]; then
            docker-compose --env-file "$env_file" -f "$compose_file" up -d --build
        else
            log_warn "$service_name: No .env file found, using defaults..."
            docker-compose -f "$compose_file" up -d --build
        fi
    elif [ -f "$compose_file_alt" ]; then
        log_info "Starting $service_name..."
        if [ -f "$env_file" ]; then
            docker-compose --env-file "$env_file" -f "$compose_file_alt" up -d --build
        else
            log_warn "$service_name: No .env file found, using defaults..."
            docker-compose -f "$compose_file_alt" up -d --build
        fi
    else
        log_error "$service_name: No docker-compose.yaml found in docker/ directory"
        return 1
    fi
}

docker_start_individual_service_quick() {
    local service_name="$1"
    local service_dir="$REPOS_DIR/$service_name"
    local compose_file="$service_dir/docker/docker-compose.yaml"
    local compose_file_alt="$service_dir/docker/docker-compose.yml"
    local env_file="$service_dir/.env"
    
    if [ ! -d "$service_dir" ]; then
        log_error "Service not found: $service_name"
        return 1
    fi
    
    if [ -f "$compose_file" ]; then
        log_info "Starting $service_name (quick)..."
        if [ -f "$env_file" ]; then
            docker-compose --env-file "$env_file" -f "$compose_file" up -d
        else
            log_warn "$service_name: No .env file found, using defaults..."
            docker-compose -f "$compose_file" up -d
        fi
    elif [ -f "$compose_file_alt" ]; then
        log_info "Starting $service_name (quick)..."
        if [ -f "$env_file" ]; then
            docker-compose --env-file "$env_file" -f "$compose_file_alt" up -d
        else
            log_warn "$service_name: No .env file found, using defaults..."
            docker-compose -f "$compose_file_alt" up -d
        fi
    else
        log_error "$service_name: No docker-compose.yaml found in docker/ directory"
        return 1
    fi
}

docker_stop() {
    local component="$1"
    
    if [ -z "$component" ]; then
        log_error "Please specify a component"
        return 1
    fi
    
    case "$component" in
        infra)
            docker_stop_infra_component "postgres"
            docker_stop_infra_component "rabbitmq"
            docker_stop_infra_component "s3-minio"
            ;;
        services)
            docker_stop_all_services
            ;;
        all)
            docker_stop_all_services
            docker_stop_infra_component "postgres"
            docker_stop_infra_component "rabbitmq"
            docker_stop_infra_component "s3-minio"
            ;;
        postgres|rabbitmq|s3-minio)
            docker_stop_infra_component "$component"
            ;;
        minio)
            docker_stop_infra_component "s3-minio"
            ;;
        *-ms|frontend)
            docker_stop_individual_service "$component"
            ;;
        *)
            log_error "Unknown component: $component"
            echo "Available components:"
            echo "  infra, services, all, postgres, rabbitmq, minio"
            echo "  Individual services: communication-ms, user-ms, document-ms, translation-ms, frontend"
            return 1
            ;;
    esac
    
    log_success "Done!"
}

docker_stop_infra_component() {
    local component="$1"
    local file="$DOCKER_DIR/infra/${component}-compose.yaml"
    
    if [ -f "$file" ]; then
        log_info "Stopping $component..."
        docker-compose -f "$file" down
    fi
}

docker_stop_all_services() {
    log_info "Stopping all services..."
    
    if [ ! -d "$REPOS_DIR" ]; then
        return
    fi
    
    for service_dir in "$REPOS_DIR"/*/; do
        if [ -d "$service_dir" ]; then
            local service_name=$(basename "$service_dir")
            docker_stop_individual_service "$service_name"
        fi
    done
}

docker_stop_individual_service() {
    local service_name="$1"
    local service_dir="$REPOS_DIR/$service_name"
    local compose_file="$service_dir/docker/docker-compose.yaml"
    local compose_file_alt="$service_dir/docker/docker-compose.yml"
    
    if [ ! -d "$service_dir" ]; then
        log_error "Service not found: $service_name"
        return 1
    fi
    
    if [ -f "$compose_file" ]; then
        log_info "Stopping $service_name..."
        docker-compose -f "$compose_file" down
    elif [ -f "$compose_file_alt" ]; then
        log_info "Stopping $service_name..."
        docker-compose -f "$compose_file_alt" down
    else
        log_warn "$service_name: No docker-compose.yaml found, skipping..."
    fi
}

docker_rebuild() {
    local component="$1"
    
    if [ -z "$component" ]; then
        log_error "Please specify a component to rebuild"
        return 1
    fi
    
    check_env
    ensure_docker_network
    
    log_info "Rebuilding $component..."
    
    case "$component" in
        postgres|rabbitmq|s3-minio)
            local file="$DOCKER_DIR/infra/${component}-compose.yaml"
            if [ -f "$file" ]; then
                docker-compose -f "$file" down 2>/dev/null || true
                docker-compose --env-file "$SCRIPT_DIR/.env" -f "$file" up -d --build
            fi
            ;;
        minio)
            docker_rebuild "s3-minio"
            ;;
        services)
            for service_dir in "$REPOS_DIR"/*/; do
                if [ -d "$service_dir" ]; then
                    local service_name=$(basename "$service_dir")
                    local compose_file="$service_dir/docker/docker-compose.yaml"
                    local compose_file_alt="$service_dir/docker/docker-compose.yml"
                    
                    if [ -f "$compose_file" ]; then
                        log_info "Rebuilding $service_name..."
                        docker-compose -f "$compose_file" down 2>/dev/null || true
                        docker-compose --env-file "$SCRIPT_DIR/.env" -f "$compose_file" up -d --build
                    elif [ -f "$compose_file_alt" ]; then
                        log_info "Rebuilding $service_name..."
                        docker-compose -f "$compose_file_alt" down 2>/dev/null || true
                        docker-compose --env-file "$SCRIPT_DIR/.env" -f "$compose_file_alt" up -d --build
                    fi
                fi
            done
            ;;
        *)
            log_error "Unknown component: $component"
            return 1
            ;;
    esac
    
    log_success "Rebuilt $component!"
}

docker_rebuild_with_build() {
    local component="$1"
    
    if [ -z "$component" ]; then
        log_error "Please specify a component to rebuild"
        return 1
    fi
    
    check_env
    ensure_docker_network
    
    log_info "Rebuilding $component (with Maven build)..."
    
    case "$component" in
        postgres|rabbitmq|s3-minio)
            docker_rebuild "$component"
            ;;
        minio)
            docker_rebuild "s3-minio"
            ;;
        services)
            # Build all services first
            build_services
            for service_dir in "$REPOS_DIR"/*/; do
                if [ -d "$service_dir" ]; then
                    local service_name=$(basename "$service_dir")
                    docker_stop_individual_service "$service_name"
                    docker_start_individual_service "$service_name"
                fi
            done
            ;;
        all)
            docker_rebuild_with_build "services"
            ;;
        *-ms|frontend)
            docker_stop_individual_service "$component"
            docker_start_individual_service "$component"
            ;;
        *)
            log_error "Unknown component: $component"
            return 1
            ;;
    esac
    
    log_success "Rebuilt $component!"
}

docker_logs() {
    local component="$1"
    
    if [ -z "$component" ]; then
        log_error "Please specify a component"
        return 1
    fi
    
    case "$component" in
        postgres|rabbitmq|s3-minio)
            local file="$DOCKER_DIR/infra/${component}-compose.yaml"
            if [ -f "$file" ]; then
                docker-compose -f "$file" logs -f
            fi
            ;;
        minio)
            docker_logs "s3-minio"
            ;;
        *-ms|frontend)
            docker_logs_individual_service "$component"
            ;;
        *)
            log_error "Unknown component: $component"
            echo "Available components:"
            echo "  postgres, rabbitmq, minio"
            echo "  Individual services: communication-ms, user-ms, document-ms, translation-ms, frontend"
            return 1
            ;;
    esac
}

docker_logs_individual_service() {
    local service_name="$1"
    local service_dir="$REPOS_DIR/$service_name"
    local compose_file="$service_dir/docker/docker-compose.yaml"
    local compose_file_alt="$service_dir/docker/docker-compose.yml"
    
    if [ ! -d "$service_dir" ]; then
        log_error "Service not found: $service_name"
        return 1
    fi
    
    if [ -f "$compose_file" ]; then
        log_info "Showing logs for $service_name..."
        docker-compose -f "$compose_file" logs -f
    elif [ -f "$compose_file_alt" ]; then
        log_info "Showing logs for $service_name..."
        docker-compose -f "$compose_file_alt" logs -f
    else
        log_error "$service_name: No docker-compose.yaml found"
        return 1
    fi
}

docker_status() {
    echo -e "${BLUE}CoreMS Docker Status${NC}"
    echo ""
    docker ps --filter "name=corems-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || \
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

docker_clean() {
    log_warn "Stopping all containers and removing volumes..."
    
    docker_stop_all_services
    docker_stop_infra_component "postgres"
    docker_stop_infra_component "rabbitmq"
    docker_stop_infra_component "s3-minio"
    
    log_success "Cleaned!"
}

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------
cmd_help() {
    show_banner
    echo "Usage: ./setup.sh <command> [options]"
    echo ""
    echo "Repository Commands:"
    echo "  init                      Initialize project (clone parent + common)"
    echo "  init-base                 Initialize with base services (parent + common + core services + frontend)"
    echo "  init-all                  Initialize with all available repositories"
    echo "  add <services...>         Add services (e.g., add user-ms document-ms)"
    echo "  list                      List available and installed services"
    echo "  update                    Pull latest for all cloned repos"
    echo "  checkout [branch]         Checkout branch for all repos (default: main)"
    echo "  cleanup                   Delete local branches merged into main"
    echo ""
    echo "Environment Commands:"
    echo "  create-env [all|main|services|<service>] Create .env files"
    echo ""
    echo "Migration Commands:"
    echo "  migrate [--mockdata] [--clean] [<service>]   Run database migrations"
    echo ""
    echo "Build Commands:"
    echo "  build [deps|services|all|<service>] Build dependencies and/or services"
    echo ""
    echo "Start Commands:"
    echo "  start-all             Start complete CoreMS stack (infra + services)"
    echo "  stop-all              Stop complete CoreMS stack"
    echo "  restart-all           Restart complete CoreMS stack"
    echo ""
    echo "Docker Commands:"
    echo "  docker start <component>  Start component(s) (quick - no rebuild)"
    echo "  docker up <component>     Alias for start"
    echo "  docker stop <component>   Stop component(s) or individual service"
    echo "  docker restart <component> Restart component(s) or individual service"
    echo "  docker rebuild <component> Maven build + Docker rebuild + start (slow)"
    echo "  docker logs <component>   View logs for component or individual service"
    echo "  docker status             Show running containers"
    echo "  docker clean              Stop all and remove volumes"
    echo ""
}

# -----------------------------------------------------------------------------
# Utilities
# -----------------------------------------------------------------------------
clone_repo() {
    local repo_name=$1
    local repo_path="$REPOS_DIR/$repo_name"
    
    if [ -d "$repo_path" ]; then
        log_warn "$repo_name already exists, skipping..."
        return
    fi
    
    log_info "Cloning $repo_name..."
    git clone "$GITHUB_BASE/$repo_name.git" "$repo_path"
    log_success "Cloned $repo_name"
}

clone_infra() {
    if [ -d "$INFRA_DIR" ]; then
        log_warn "Infrastructure repo already exists, skipping..."
        return
    fi
    
    log_info "Cloning infrastructure repository..."
    git clone "$GITHUB_BASE/corems-infra.git" "$INFRA_DIR"
    log_success "Cloned infrastructure repository"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    case "${1:-help}" in
        init)       shift; cmd_init "$@" ;;
        init-base)  cmd_init_base ;;
        init-all)   cmd_init_all ;;
        add)        shift; cmd_add "$@" ;;
        list)       cmd_list ;;
        update)     cmd_update ;;
        checkout)   shift; cmd_checkout "$@" ;;
        cleanup)    cmd_cleanup ;;
        create-env) shift; cmd_create_env "$@" ;;
        start-all)  cmd_start_all ;;
        stop-all)   cmd_stop_all ;;
        restart-all) cmd_restart_all ;;
        build)      shift; cmd_build "$@" ;;
        migrate)    shift; cmd_migrate "$@" ;;
        docker)     shift; cmd_docker "$@" ;;
        help|--help|-h) cmd_help ;;
        *)          log_error "Unknown command: $1"; cmd_help; exit 1 ;;
    esac
}

main "$@"
