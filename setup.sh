#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICES_DIR="$SCRIPT_DIR/services"
DOCKER_DIR="$SCRIPT_DIR/docker"
GITHUB_ORG="core-microservices"
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

check_docker_env() {
    if [ ! -f "$DOCKER_DIR/.env" ]; then
        log_error ".env file not found in docker/"
        log_warn "Copy .env-example to .env and configure it:"
        echo "  cp docker/.env-example docker/.env"
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Repository Commands
# -----------------------------------------------------------------------------
cmd_init() {
    log_info "Initializing Core Microservices..."
    
    mkdir -p "$SERVICES_DIR"
    
    # Clone required repos
    log_info "Cloning required repositories..."
    clone_repo "parent"
    clone_repo "common"
    
    log_success "Initialization complete!"
    echo ""
    echo "Next steps:"
    echo "  ./setup.sh add user-ms document-ms    # Add services"
    echo "  ./setup.sh list                       # Show available services"
}

cmd_add() {
    if [ $# -eq 0 ]; then
        log_error "No services specified. Usage: ./setup.sh add <service1> <service2> ..."
        echo ""
        cmd_list
        exit 1
    fi
    
    mkdir -p "$SERVICES_DIR"
    
    for service in "$@"; do
        clone_repo "$service"
    done
    
    log_success "Services added!"
}

cmd_list() {
    echo "Available services:"
    echo ""
    echo "  parent            Parent POM - dependency management"
    echo "  common            Shared libraries - security, logging, utils"
    echo "  user-ms           User management - authentication, authorization"
    echo "  document-ms       Document management - file storage, metadata"
    echo "  communication-ms  Communication - emails, SMS, notifications"
    echo "  translation-ms    Localization - i18n bundles"
    echo "  frontend          Vue.js frontend application"
    echo ""
    echo "Installed:"
    if [ -d "$SERVICES_DIR" ]; then
        local found=false
        for dir in "$SERVICES_DIR"/*/; do
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
    
    if [ ! -d "$SERVICES_DIR" ]; then
        log_error "No services found. Run './setup.sh init' first."
        exit 1
    fi
    
    for dir in "$SERVICES_DIR"/*/; do
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
    
    if [ ! -d "$SERVICES_DIR" ]; then
        log_error "No services found. Run './setup.sh init' first."
        exit 1
    fi
    
    for dir in "$SERVICES_DIR"/*/; do
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
    
    if [ ! -d "$SERVICES_DIR" ]; then
        log_error "No services found. Run './setup.sh init' first."
        exit 1
    fi
    
    for dir in "$SERVICES_DIR"/*/; do
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
# Migration Commands
# -----------------------------------------------------------------------------
cmd_migrate() {
    log_info "Running database migrations..."
    
    local args=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --mockdata) args="$args --migrations.include-mockdata=true"; shift ;;
            --clean) args="$args --migrations.clean-before-migrate=true"; shift ;;
            *) shift ;;
        esac
    done
    
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
        stop)    docker_stop "$component" ;;
        restart) docker_stop "$component"; sleep 2; docker_start "$component" ;;
        rebuild) docker_rebuild "$component" ;;
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
    echo "  start <component>   Start component(s)"
    echo "  stop <component>    Stop component(s)"
    echo "  restart <component> Restart component(s)"
    echo "  rebuild <component> Rebuild and restart"
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
    echo "  ./setup.sh docker start infra"
    echo "  ./setup.sh docker start services"
    echo "  ./setup.sh docker logs postgres"
    echo "  ./setup.sh docker status"
}

docker_start() {
    local component="$1"
    
    if [ -z "$component" ]; then
        log_error "Please specify a component (infra, services, all, postgres, rabbitmq, minio)"
        return 1
    fi
    
    check_docker_env
    ensure_docker_network
    
    case "$component" in
        infra)
            docker_start_infra_component "postgres"
            docker_start_infra_component "rabbitmq"
            docker_start_infra_component "s3-minio"
            ;;
        services)
            docker_start_all_services
            ;;
        all)
            docker_start_infra_component "postgres"
            docker_start_infra_component "rabbitmq"
            docker_start_infra_component "s3-minio"
            docker_start_all_services
            ;;
        postgres|rabbitmq|s3-minio)
            docker_start_infra_component "$component"
            ;;
        minio)
            docker_start_infra_component "s3-minio"
            ;;
        *)
            log_error "Unknown component: $component"
            return 1
            ;;
    esac
    
    log_success "Done!"
}

docker_start_infra_component() {
    local component="$1"
    local file="$DOCKER_DIR/infrastructure/${component}-compose.yaml"
    
    if [ -f "$file" ]; then
        log_info "Starting $component..."
        docker-compose --env-file "$DOCKER_DIR/.env" -f "$file" up -d
    else
        log_error "Compose file not found: $file"
        return 1
    fi
}

docker_start_all_services() {
    log_info "Starting all services from services/*/docker/..."
    
    if [ ! -d "$SERVICES_DIR" ]; then
        log_warn "No services directory found. Run './setup.sh init' first."
        return
    fi
    
    local found=false
    for service_dir in "$SERVICES_DIR"/*/; do
        if [ -d "$service_dir" ]; then
            local service_name=$(basename "$service_dir")
            local compose_file="$service_dir/docker/docker-compose.yaml"
            local compose_file_alt="$service_dir/docker/docker-compose.yml"
            
            if [ -f "$compose_file" ]; then
                found=true
                log_info "Starting $service_name..."
                docker-compose --env-file "$DOCKER_DIR/.env" -f "$compose_file" up -d
            elif [ -f "$compose_file_alt" ]; then
                found=true
                log_info "Starting $service_name..."
                docker-compose --env-file "$DOCKER_DIR/.env" -f "$compose_file_alt" up -d
            else
                log_warn "$service_name: No docker-compose.yaml found in docker/"
            fi
        fi
    done
    
    if [ "$found" = false ]; then
        log_warn "No services with docker-compose files found"
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
        *)
            log_error "Unknown component: $component"
            return 1
            ;;
    esac
    
    log_success "Done!"
}

docker_stop_infra_component() {
    local component="$1"
    local file="$DOCKER_DIR/infrastructure/${component}-compose.yaml"
    
    if [ -f "$file" ]; then
        log_info "Stopping $component..."
        docker-compose -f "$file" down
    fi
}

docker_stop_all_services() {
    log_info "Stopping all services..."
    
    if [ ! -d "$SERVICES_DIR" ]; then
        return
    fi
    
    for service_dir in "$SERVICES_DIR"/*/; do
        if [ -d "$service_dir" ]; then
            local service_name=$(basename "$service_dir")
            local compose_file="$service_dir/docker/docker-compose.yaml"
            local compose_file_alt="$service_dir/docker/docker-compose.yml"
            
            if [ -f "$compose_file" ]; then
                log_info "Stopping $service_name..."
                docker-compose -f "$compose_file" down
            elif [ -f "$compose_file_alt" ]; then
                log_info "Stopping $service_name..."
                docker-compose -f "$compose_file_alt" down
            fi
        fi
    done
}

docker_rebuild() {
    local component="$1"
    
    if [ -z "$component" ]; then
        log_error "Please specify a component to rebuild"
        return 1
    fi
    
    check_docker_env
    ensure_docker_network
    
    log_info "Rebuilding $component..."
    
    case "$component" in
        postgres|rabbitmq|s3-minio)
            local file="$DOCKER_DIR/infrastructure/${component}-compose.yaml"
            if [ -f "$file" ]; then
                docker-compose -f "$file" down 2>/dev/null || true
                docker-compose --env-file "$DOCKER_DIR/.env" -f "$file" up -d --build
            fi
            ;;
        minio)
            docker_rebuild "s3-minio"
            ;;
        services)
            for service_dir in "$SERVICES_DIR"/*/; do
                if [ -d "$service_dir" ]; then
                    local service_name=$(basename "$service_dir")
                    local compose_file="$service_dir/docker/docker-compose.yaml"
                    local compose_file_alt="$service_dir/docker/docker-compose.yml"
                    
                    if [ -f "$compose_file" ]; then
                        log_info "Rebuilding $service_name..."
                        docker-compose -f "$compose_file" down 2>/dev/null || true
                        docker-compose --env-file "$DOCKER_DIR/.env" -f "$compose_file" up -d --build
                    elif [ -f "$compose_file_alt" ]; then
                        log_info "Rebuilding $service_name..."
                        docker-compose -f "$compose_file_alt" down 2>/dev/null || true
                        docker-compose --env-file "$DOCKER_DIR/.env" -f "$compose_file_alt" up -d --build
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

docker_logs() {
    local component="$1"
    
    if [ -z "$component" ]; then
        log_error "Please specify a component"
        return 1
    fi
    
    case "$component" in
        postgres|rabbitmq|s3-minio)
            local file="$DOCKER_DIR/infrastructure/${component}-compose.yaml"
            if [ -f "$file" ]; then
                docker-compose -f "$file" logs -f
            fi
            ;;
        minio)
            docker_logs "s3-minio"
            ;;
        *)
            # Try to find in services
            local compose_file="$SERVICES_DIR/$component/docker/docker-compose.yaml"
            local compose_file_alt="$SERVICES_DIR/$component/docker/docker-compose.yml"
            
            if [ -f "$compose_file" ]; then
                docker-compose -f "$compose_file" logs -f
            elif [ -f "$compose_file_alt" ]; then
                docker-compose -f "$compose_file_alt" logs -f
            else
                log_error "Unknown component or no docker-compose found: $component"
                return 1
            fi
            ;;
    esac
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
    echo "  add <services...>         Add services (e.g., add user-ms document-ms)"
    echo "  list                      List available and installed services"
    echo "  update                    Pull latest for all cloned repos"
    echo "  checkout [branch]         Checkout branch for all repos (default: main)"
    echo "  cleanup                   Delete local branches merged into main"
    echo ""
    echo "Migration Commands:"
    echo "  migrate [--mockdata] [--clean]   Run database migrations"
    echo ""
    echo "Docker Commands:"
    echo "  docker start <component>  Start infra/services/all/postgres/rabbitmq/minio"
    echo "  docker stop <component>   Stop component(s)"
    echo "  docker restart <component> Restart component(s)"
    echo "  docker rebuild <component> Rebuild and restart"
    echo "  docker logs <component>   View logs"
    echo "  docker status             Show running containers"
    echo "  docker clean              Stop all and remove volumes"
    echo ""
    echo "Examples:"
    echo "  ./setup.sh init"
    echo "  ./setup.sh add user-ms document-ms"
    echo "  ./setup.sh docker start infra"
    echo "  ./setup.sh docker start services"
    echo "  ./setup.sh migrate --mockdata"
    echo "  ./setup.sh checkout main"
    echo ""
}

# -----------------------------------------------------------------------------
# Utilities
# -----------------------------------------------------------------------------
clone_repo() {
    local repo_name=$1
    local repo_path="$SERVICES_DIR/$repo_name"
    
    if [ -d "$repo_path" ]; then
        log_warn "$repo_name already exists, skipping..."
        return
    fi
    
    log_info "Cloning $repo_name..."
    git clone "$GITHUB_BASE/$repo_name.git" "$repo_path"
    log_success "Cloned $repo_name"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    case "${1:-help}" in
        init)       shift; cmd_init "$@" ;;
        add)        shift; cmd_add "$@" ;;
        list)       cmd_list ;;
        update)     cmd_update ;;
        checkout)   shift; cmd_checkout "$@" ;;
        cleanup)    cmd_cleanup ;;
        migrate)    shift; cmd_migrate "$@" ;;
        docker)     shift; cmd_docker "$@" ;;
        help|--help|-h) cmd_help ;;
        *)          log_error "Unknown command: $1"; cmd_help; exit 1 ;;
    esac
}

main "$@"
