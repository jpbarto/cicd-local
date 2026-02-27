#!/bin/bash

################################################################################
# Local Deliver Pipeline Script
#
# This script simulates a delivery pipeline that builds and publishes artifacts
# to container and Helm chart repositories. This is typically run after code has
# been validated through CI testing.
#
# Prerequisites:
#   - Dagger CLI installed
#   - Access to container repository (e.g., ttl.sh, Docker Hub, etc.)
#   - Access to Helm chart repository (OCI-compatible)
#
# Usage:
#   ./local_deliver_pipeline.sh [OPTIONS]
#
# Options:
#   --release-candidate, -rc       Build as release candidate (appends -rc to version)
#   --container-repository <url>   Container repository URL (default: ttl.sh)
#   --helm-repository <url>        Helm OCI repository URL (default: oci://ttl.sh)
#   --skip-build                   Skip build step (use existing tarball)
#   --help, -h                     Show this help message
#
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load privileged functions management
source "${SCRIPT_DIR}/manage_privileged.sh"

# Load environment variables from local_cicd.env in the script's directory
if [ -f "$SCRIPT_DIR/local_cicd.env" ]; then
    export $(grep -v '^#' "$SCRIPT_DIR/local_cicd.env" | xargs)
fi

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default configuration
RELEASE_CANDIDATE=false
SKIP_BUILD=false
SOURCE_DIR="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CONTAINER_REPOSITORY_URL="${CONTAINER_REPOSITORY_URL:-ttl.sh}"
HELM_REPOSITORY_URL="${HELM_REPOSITORY_URL:-oci://ttl.sh}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --release-candidate|-rc)
            RELEASE_CANDIDATE=true
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --container-repository=*)
            CONTAINER_REPOSITORY_URL="${1#*=}"
            shift
            ;;
        --container-repository)
            CONTAINER_REPOSITORY_URL="$2"
            shift 2
            ;;
        --helm-repository=*)
            HELM_REPOSITORY_URL="${1#*=}"
            shift
            ;;
        --helm-repository)
            HELM_REPOSITORY_URL="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --release-candidate, -rc       Build as release candidate (appends -rc to version)"
            echo "  --skip-build                   Skip build step (use existing tarball)"
            echo "  --container-repository <url>   Container repository URL (default: ttl.sh)"
            echo "  --helm-repository <url>        Helm OCI repository URL (default: oci://ttl.sh)"
            echo "  --help, -h                     Show this help message"
            echo ""
            echo "Description:"
            echo "  This pipeline builds multi-architecture container images and delivers"
            echo "  them along with Helm charts to the specified repositories."
            echo ""
            echo "Examples:"
            echo "  # Build and deliver with default repositories"
            echo "  ./local_deliver_pipeline.sh"
            echo ""
            echo "  # Build and deliver release candidate"
            echo "  ./local_deliver_pipeline.sh --release-candidate"
            echo ""
            echo "  # Deliver using existing build artifact"
            echo "  ./local_deliver_pipeline.sh --skip-build"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run with --help for usage information"
            exit 1
            ;;
    esac
done

# Function to print section headers
print_section() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error messages
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to print info messages
print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Function to print step headers
print_step() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

################################################################################
# Main Pipeline
################################################################################

print_section "Delivery Pipeline Starting"
print_info "Source directory: $SOURCE_DIR"
print_info "Release candidate: $RELEASE_CANDIDATE"
print_info "Skip build: $SKIP_BUILD"
print_info "Container repository: $CONTAINER_REPOSITORY_URL"
print_info "Helm repository: $HELM_REPOSITORY_URL"

# Read VERSION file
if [ -f "$SOURCE_DIR/VERSION" ]; then
    VERSION=$(cat "$SOURCE_DIR/VERSION" | tr -d '[:space:]')
    if [ "$RELEASE_CANDIDATE" = true ]; then
        VERSION="${VERSION}-rc"
    fi
    print_info "Version: $VERSION"
else
    print_error "VERSION file not found"
    exit 1
fi

################################################################################
# Inject Privileged Functions
################################################################################

# Privileged functions are required for the Deliver step.
print_info "Injecting privileged functions (required for Deliver)..."
if ! inject_privileged_functions "$SOURCE_DIR"; then
    print_error "Failed to inject privileged functions — cannot run Deliver without them"
    exit 1
fi
print_success "Privileged functions injected"
trap "cleanup_privileged_functions '$SOURCE_DIR'" EXIT

################################################################################
# Step 1: Build
################################################################################

if [ "$SKIP_BUILD" = false ]; then
    print_step "Step 1: Build repository artifacts"
    
    BUILD_CMD="dagger -m cicd call build --source=$SOURCE_DIR"
    
    if [ "$RELEASE_CANDIDATE" = true ]; then
        BUILD_CMD="$BUILD_CMD --release-candidate=true"
    fi
    
    BUILD_CMD="$BUILD_CMD export --path=./output/build/buildArtifact"
    
    print_info "Running: $BUILD_CMD"
    echo ""
    
    # Create build directory if it doesn't exist
    mkdir -p ./build
    
    LOG_FILE="./output/build/pipeline_deliver_build.log"
    mkdir -p ./output/build
    print_info "Logging output to: $LOG_FILE"
    
    if eval "$BUILD_CMD" 2>&1 | tee "$LOG_FILE"; then
        print_success "Build completed successfully"
        print_info "Build artifact exported to: ./output/build/buildArtifact"
    else
        print_error "Build failed"
        exit 1
    fi
else
    print_warning "Step 1: Skipping build (--skip-build flag set)"
    
    # Verify tarball exists
    if [ ! -f "./output/build/buildArtifact" ]; then
        print_error "Build artifact not found: ./output/build/buildArtifact"
        echo ""
        echo "Please run without --skip-build to create the artifact first."
        exit 1
    fi
    print_info "Using existing build artifact: ./output/build/buildArtifact"
fi

################################################################################
# Step 2: Deliver
################################################################################

print_step "Step 2: Deliver Artifacts to Repositories"

# Create delivery output directory
mkdir -p ./output/deliver

DELIVER_CMD="dagger -m cicd call deliver --source=$SOURCE_DIR"
DELIVER_CMD="$DELIVER_CMD --build-artifact=./output/build/buildArtifact"

if [ "$RELEASE_CANDIDATE" = true ]; then
    DELIVER_CMD="$DELIVER_CMD --release-candidate=true"
fi

# Export delivery context to file
DELIVER_CMD="$DELIVER_CMD export --path=./output/deliver/deliveryContext"

print_info "Running: $DELIVER_CMD"
echo ""

LOG_FILE="./output/deliver/pipeline_deliver_deliver.log"
print_info "Logging output to: $LOG_FILE"

if eval "$DELIVER_CMD" 2>&1 | tee "$LOG_FILE"; then
    print_success "Artifacts delivered successfully"
    print_info "Delivery context saved to: ./output/deliver/deliveryContext"
else
    print_error "Delivery failed"
    exit 1
fi

################################################################################
# Pipeline Summary
################################################################################

print_section "Delivery Pipeline Complete"

print_success "All artifacts published successfully!"
echo ""
print_info "Published Artifacts:"
echo "  • Container Image: $CONTAINER_REPOSITORY_URL:$VERSION"
echo "    - Architecture: linux/amd64, linux/arm64"
echo "  • Helm Chart: $HELM_REPOSITORY_URL/charts/goserv:$VERSION"
echo ""
print_info "Next Steps:"
echo "  • Deploy to staging:"
echo "    ./cicd/local_staging_pipeline.sh"
echo ""
echo "  • Deploy to production:"
echo "    dagger -m cicd call deploy \\"
echo "      --source=. \\"
echo "      --helm-repository=oci://ttl.sh \\"
echo "      --container-repository=ttl.sh \\"
echo "      --release-candidate=true \\"
echo "      export --path=./output/deploy/deploymentContext"
echo ""
print_info "Verify Artifacts:"
echo "  • Pull container image:"
echo "    docker pull $CONTAINER_REPOSITORY_URL:$VERSION"
echo ""
echo "  • Inspect Helm chart:"
echo "    helm show chart $HELM_REPOSITORY_URL/charts/goserv --version $VERSION"
echo ""

exit 0
