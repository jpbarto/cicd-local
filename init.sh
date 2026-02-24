#!/bin/bash

################################################################################
# Initialize Dagger CI/CD Module Script
#
# This script initializes a Dagger module in a project's cicd/ directory
# and copies example implementations based on the specified language.
#
# Prerequisites:
#   - Dagger CLI installed
#   - Run from project root directory
#
# Usage:
#   cicd-local init <language> [name]
#   cicd-local init go
#   cicd-local init python my-app
#   cicd-local init java my-service
#   cicd-local init typescript
#
# Arguments:
#   language    Programming language (go|python|java|typescript)
#   name        Optional module name (defaults to project directory name)
#
# Example:
#   cd ~/dev/my-project
#   cicd-local init python
#   # Creates ~/dev/my-project/cicd with Python examples
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get the directory where this script is located (cicd-local installation)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Function to show usage
show_usage() {
    cat << EOF
Usage: cicd-local init <language> [name]

Initialize a Dagger CI/CD module in the current project.

Arguments:
  language    Programming language for the Dagger module
              Supported: go, golang, python, java, typescript, ts
  name        Optional module name (defaults to project directory name)

Examples:
  cicd-local init go
  cicd-local init python my-app
  cicd-local init java my-service
  cicd-local init typescript

The script will:
  1. Create a cicd/ directory in the current project
  2. Initialize Dagger with the specified SDK
  3. Copy example contract implementations
  4. Create a VERSION file if it doesn't exist

EOF
}

# Check if language argument is provided
if [ $# -lt 1 ]; then
    print_error "Language argument is required"
    echo ""
    show_usage
    exit 1
fi

# Parse arguments
LANGUAGE="$1"
MODULE_NAME="${2:-}"

# Validate and normalize language
case "${LANGUAGE}" in
    go|golang)
        SDK="go"
        EXAMPLE_DIR="golang"
        ;;
    python|py)
        SDK="python"
        EXAMPLE_DIR="python"
        ;;
    java)
        SDK="java"
        EXAMPLE_DIR="java"
        ;;
    typescript|ts)
        SDK="typescript"
        EXAMPLE_DIR="typescript"
        ;;
    --help|-h)
        show_usage
        exit 0
        ;;
    *)
        print_error "Unsupported language: ${LANGUAGE}"
        echo ""
        echo "Supported languages: go, python, java, typescript"
        exit 1
        ;;
esac

# Get current project directory
PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "${PROJECT_DIR}")"

# Determine module name
if [ -z "${MODULE_NAME}" ]; then
    MODULE_NAME="${PROJECT_NAME}"
    print_info "Using project directory name as module name: ${MODULE_NAME}"
fi

# Define paths
CICD_DIR="${PROJECT_DIR}/cicd"
EXAMPLES_SOURCE="${SCRIPT_DIR}/cicd_dagger_contract/${EXAMPLE_DIR}"
VERSION_FILE="${PROJECT_DIR}/VERSION"

print_section "Initializing Dagger CI/CD Module"

print_info "Project: ${PROJECT_DIR}"
print_info "Module name: ${MODULE_NAME}"
print_info "Language: ${SDK}"
print_info "CI/CD directory: ${CICD_DIR}"

# Check if Dagger is installed
if ! command -v dagger &> /dev/null; then
    print_error "Dagger CLI is not installed"
    echo ""
    echo "Please install Dagger:"
    echo "  curl -L https://dl.dagger.io/dagger/install.sh | sh"
    echo ""
    echo "Or visit: https://docs.dagger.io/install"
    exit 1
fi

print_success "Dagger CLI found: $(dagger version)"

# Check if cicd directory already exists
if [ -d "${CICD_DIR}" ]; then
    print_warning "Directory ${CICD_DIR} already exists"
    read -p "Do you want to reinitialize it? This will backup existing files. (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Initialization cancelled"
        exit 0
    fi
    
    # Backup existing cicd directory
    BACKUP_DIR="${CICD_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    print_info "Backing up existing cicd directory to ${BACKUP_DIR}"
    mv "${CICD_DIR}" "${BACKUP_DIR}"
fi

# Create cicd directory
print_info "Creating cicd directory..."
mkdir -p "${CICD_DIR}"
print_success "Created ${CICD_DIR}"

# Change to cicd directory
cd "${CICD_DIR}"

# Initialize Dagger module
print_section "Initializing Dagger Module"
print_info "Running: dagger init --sdk=${SDK} --name=${MODULE_NAME}"
echo ""

if dagger init --sdk="${SDK}" --name="${MODULE_NAME}"; then
    print_success "Dagger module initialized successfully"
else
    print_error "Failed to initialize Dagger module"
    exit 1
fi

# Copy example files
print_section "Copying Example Implementations"

if [ ! -d "${EXAMPLES_SOURCE}" ]; then
    print_error "Example directory not found: ${EXAMPLES_SOURCE}"
    exit 1
fi

print_info "Copying examples from: ${EXAMPLES_SOURCE}"

# Copy example files to cicd directory
for example_file in "${EXAMPLES_SOURCE}"/*.example.*; do
    if [ -f "${example_file}" ]; then
        filename=$(basename "${example_file}")
        # Remove .example from filename
        target_name="${filename/.example/}"
        
        # Skip copying if target already exists (preserve generated files)
        if [ -f "${target_name}" ]; then
            print_warning "Skipping ${target_name} (already exists)"
        else
            cp "${example_file}" "${target_name}"
            print_success "Copied ${filename} → ${target_name}"
        fi
    fi
done

# Copy privileged functions
print_section "Copying Privileged Functions"

PRIVILEGED_SOURCE="${SCRIPT_DIR}/privileged"
PRIVILEGED_TARGET="${CICD_DIR}/privileged"

if [ -d "${PRIVILEGED_SOURCE}" ]; then
    if [ -d "${PRIVILEGED_TARGET}" ]; then
        print_warning "Privileged directory already exists, skipping copy"
    else
        mkdir -p "${PRIVILEGED_TARGET}"
        cp -r "${PRIVILEGED_SOURCE}"/*.go "${PRIVILEGED_TARGET}/"
        print_success "Copied privileged functions to ${PRIVILEGED_TARGET}"
        print_info "Privileged functions are available for import during development"
    fi
else
    print_warning "Privileged functions directory not found: ${PRIVILEGED_SOURCE}"
fi

# Return to project directory
cd "${PROJECT_DIR}"

# Create VERSION file if it doesn't exist
if [ ! -f "${VERSION_FILE}" ]; then
    print_section "Creating VERSION File"
    echo "0.1.0" > "${VERSION_FILE}"
    print_success "Created VERSION file with initial version: 0.1.0"
else
    print_info "VERSION file already exists: $(cat "${VERSION_FILE}")"
fi

# Final summary
print_section "Initialization Complete"
echo ""
print_success "Dagger CI/CD module initialized successfully!"
echo ""
echo "Next steps:"
echo "  1. Review the example implementations in ${CICD_DIR}"
echo "  2. Customize the functions to match your project's needs"
echo "  3. Test your implementation:"
echo "     ${CYAN}cicd-local validate${NC}"
echo "  4. Run the CI pipeline:"
echo "     ${CYAN}cicd-local ci${NC}"
echo ""
echo "Documentation:"
echo "  - Contract: ${SCRIPT_DIR}/cicd_dagger_contract/contract.json"
echo "  - Reference: ${SCRIPT_DIR}/docs/CONTRACT_REFERENCE.md"
echo "  - Validation: ${SCRIPT_DIR}/docs/CONTRACT_VALIDATION.md"
echo ""
