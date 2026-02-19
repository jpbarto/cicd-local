#!/bin/bash

################################################################################
# Dagger Contract Validation Script
#
# This script validates that a project's Dagger functions conform to the
# cicd-local contract specification defined in cicd_dagger_contract.
#
# Usage:
#   ./validate_contract.sh [PROJECT_DIR]
#
# If PROJECT_DIR is not provided, it will use the parent directory (../)
################################################################################

set -e  # Exit on error
# Note: We don't use set -u here because associative arrays in loops can trigger it

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Project directory to validate (default to parent directory)
PROJECT_DIR="${1:-$(cd "$SCRIPT_DIR/.." && pwd)}"
CICD_DIR="$PROJECT_DIR/cicd"

# Counters for validation results
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Arrays to store validation errors
declare -a ERRORS

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    ERRORS+=("$1")
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

################################################################################
# Contract Definition
################################################################################

# Load contract from JSON file
CONTRACT_FILE="$SCRIPT_DIR/cicd_dagger_contract/contract.json"

# Check if jq is available for JSON parsing
if command -v jq &> /dev/null && [ -f "$CONTRACT_FILE" ]; then
    USE_JSON_CONTRACT=true
else
    if ! command -v jq &> /dev/null; then
        : # jq not available, will use fallback
    fi
    USE_JSON_CONTRACT=false
fi

# Get contract parameters from JSON or fallback to hardcoded values
get_contract_params() {
    local lang="$1"
    local func_name="$2"
    
    if [ "$USE_JSON_CONTRACT" = true ]; then
        # Use jq to extract parameters from JSON
        local params=$(jq -r ".functions.${func_name}.parameters.${lang} // [] | map(\"\(.name):\(.type)\") | join(\",\")" "$CONTRACT_FILE")
        echo "$params"
    else
        # Fallback to hardcoded contracts
        case "$lang" in
            golang) get_golang_contract "$func_name" ;;
            python) get_python_contract "$func_name" ;;
            java) get_java_contract "$func_name" ;;
            typescript) get_typescript_contract "$func_name" ;;
        esac
    fi
}

# Fallback: Define expected function signatures for each language
# Using indexed arrays since macOS bash 3.2 doesn't support associative arrays

get_golang_contract() {
    case "$1" in
        Build) echo "ctx:context.Context,source:*dagger.Directory,releaseCandidate:bool" ;;
        UnitTest) echo "ctx:context.Context,source:*dagger.Directory,buildArtifact:*dagger.File" ;;
        IntegrationTest) echo "ctx:context.Context,source:*dagger.Directory,targetHost:string,targetPort:string" ;;
        Deliver) echo "ctx:context.Context,source:*dagger.Directory,containerRepository:string,helmRepository:string,buildArtifact:*dagger.File,releaseCandidate:bool" ;;
        Deploy) echo "ctx:context.Context,source:*dagger.Directory,kubeconfig:*dagger.Secret,helmRepository:string,releaseName:string,namespace:string,releaseCandidate:bool" ;;
        Validate) echo "ctx:context.Context,source:*dagger.Directory,kubeconfig:*dagger.Secret,releaseName:string,namespace:string,expectedVersion:string,releaseCandidate:bool" ;;
    esac
}

get_python_contract() {
    case "$1" in
        build) echo "source:dagger.Directory,release_candidate:bool" ;;
        unit_test) echo "source:dagger.Directory,build_artifact:dagger.File" ;;
        integration_test) echo "source:dagger.Directory,target_host:str,target_port:str" ;;
        deliver) echo "source:dagger.Directory,container_repository:str,helm_repository:str,build_artifact:dagger.File,release_candidate:bool" ;;
        deploy) echo "source:dagger.Directory,kubeconfig:dagger.Secret,helm_repository:str,release_name:str,namespace:str,release_candidate:bool" ;;
        validate) echo "source:dagger.Directory,kubeconfig:dagger.Secret,release_name:str,namespace:str,expected_version:str,release_candidate:bool" ;;
    esac
}

get_java_contract() {
    case "$1" in
        build) echo "source:Directory,releaseCandidate:boolean" ;;
        unitTest) echo "source:Directory,buildArtifact:File" ;;
        integrationTest) echo "source:Directory,targetHost:String,targetPort:String" ;;
        deliver) echo "source:Directory,containerRepository:String,helmRepository:String,buildArtifact:File,releaseCandidate:boolean" ;;
        deploy) echo "source:Directory,kubeconfig:Secret,helmRepository:String,releaseName:String,namespace:String,releaseCandidate:boolean" ;;
        validate) echo "source:Directory,kubeconfig:Secret,releaseName:String,namespace:String,expectedVersion:String,releaseCandidate:boolean" ;;
    esac
}

get_typescript_contract() {
    case "$1" in
        build) echo "source:Directory,releaseCandidate:boolean" ;;
        unitTest) echo "source:Directory,buildArtifact:File" ;;
        integrationTest) echo "source:Directory,targetHost:string,targetPort:string" ;;
        deliver) echo "source:Directory,containerRepository:string,helmRepository:string,buildArtifact:File,releaseCandidate:boolean" ;;
        deploy) echo "source:Directory,kubeconfig:Secret,helmRepository:string,releaseName:string,namespace:string,releaseCandidate:boolean" ;;
        validate) echo "source:Directory,kubeconfig:Secret,releaseName:string,namespace:string,expectedVersion:string,releaseCandidate:boolean" ;;
    esac
}

get_function_names() {
    case "$1" in
        golang) echo "Build UnitTest IntegrationTest Deliver Deploy Validate" ;;
        python) echo "build unit_test integration_test deliver deploy validate" ;;
        java) echo "build unitTest integrationTest deliver deploy validate" ;;
        typescript) echo "build unitTest integrationTest deliver deploy validate" ;;
    esac
}

################################################################################
# Language Detection
################################################################################

detect_language() {
    local cicd_dir="$1"
    
    if [ -f "$cicd_dir/main.go" ] || [ -f "$cicd_dir/dagger.gen.go" ]; then
        echo "golang"
    elif [ -f "$cicd_dir/pyproject.toml" ] || [ -f "$cicd_dir/src/__init__.py" ]; then
        echo "python"
    elif [ -f "$cicd_dir/pom.xml" ] || [ -f "$cicd_dir/build.gradle" ]; then
        echo "java"
    elif [ -f "$cicd_dir/package.json" ] || [ -f "$cicd_dir/tsconfig.json" ]; then
        echo "typescript"
    else
        echo "unknown"
    fi
}

################################################################################
# Validation Functions by Language
################################################################################

validate_golang_function() {
    local func_name="$1"
    local expected_params="$2"
    local file_content="$3"
    
    # Extract function signature
    local func_signature=$(echo "$file_content" | grep -A 20 "func (m \*[A-Za-z]*) $func_name(" | head -20)
    
    if [ -z "$func_signature" ]; then
        print_error "Function '$func_name' not found in Go files"
        return 1
    fi
    
    # Parse expected parameters
    IFS=',' read -ra PARAMS <<< "$expected_params"
    local all_params_found=true
    
    for param in "${PARAMS[@]}"; do
        IFS=':' read -ra PARAM_PARTS <<< "$param"
        local param_name="${PARAM_PARTS[0]}"
        local param_type="${PARAM_PARTS[1]}"
        
        # Escape special regex characters in type for grep
        local escaped_type=$(echo "$param_type" | sed 's/[*.]/\\&/g')
        
        # Check if parameter exists in signature
        if echo "$func_signature" | grep -qF "$param_name"; then
            : # Parameter found, do nothing
        else
            print_error "  Parameter '$param_name' with type '$param_type' not found or incorrect in $func_name"
            all_params_found=false
        fi
    done
    
    if [ "$all_params_found" = true ]; then
        print_success "Function '$func_name' signature matches contract"
        return 0
    else
        return 1
    fi
}

validate_python_function() {
    local func_name="$1"
    local expected_params="$2"
    local file_content="$3"
    
    # Extract function signature (async def or def)
    local func_signature=$(echo "$file_content" | grep -A 15 "def $func_name(" | head -15)
    
    if [ -z "$func_signature" ]; then
        print_error "Function '$func_name' not found in Python files"
        return 1
    fi
    
    # Parse expected parameters
    IFS=',' read -ra PARAMS <<< "$expected_params"
    local all_params_found=true
    
    for param in "${PARAMS[@]}"; do
        IFS=':' read -ra PARAM_PARTS <<< "$param"
        local param_name="${PARAM_PARTS[0]}"
        local param_type="${PARAM_PARTS[1]}"
        
        # Check if parameter exists in signature (Python uses : for type hints)
        if echo "$func_signature" | grep -qF "$param_name"; then
            : # Parameter found, do nothing
        else
            print_error "  Parameter '$param_name' with type '$param_type' not found or incorrect in $func_name"
            all_params_found=false
        fi
    done
    
    if [ "$all_params_found" = true ]; then
        print_success "Function '$func_name' signature matches contract"
        return 0
    else
        return 1
    fi
}

validate_java_function() {
    local func_name="$1"
    local expected_params="$2"
    local file_content="$3"
    
    # Extract function signature
    local func_signature=$(echo "$file_content" | grep -A 15 "public.*$func_name(" | head -15)
    
    if [ -z "$func_signature" ]; then
        print_error "Function '$func_name' not found in Java files"
        return 1
    fi
    
    # Parse expected parameters
    IFS=',' read -ra PARAMS <<< "$expected_params"
    local all_params_found=true
    
    for param in "${PARAMS[@]}"; do
        IFS=':' read -ra PARAM_PARTS <<< "$param"
        local param_name="${PARAM_PARTS[0]}"
        local param_type="${PARAM_PARTS[1]}"
        
        # Check if parameter exists in signature
        if echo "$func_signature" | grep -qF "$param_name"; then
            : # Parameter found, do nothing
        else
            print_error "  Parameter '$param_name' with type '$param_type' not found or incorrect in $func_name"
            all_params_found=false
        fi
    done
    
    if [ "$all_params_found" = true ]; then
        print_success "Function '$func_name' signature matches contract"
        return 0
    else
        return 1
    fi
}

validate_typescript_function() {
    local func_name="$1"
    local expected_params="$2"
    local file_content="$3"
    
    # Extract function signature
    local func_signature=$(echo "$file_content" | grep -A 15 "$func_name(" | head -15)
    
    if [ -z "$func_signature" ]; then
        print_error "Function '$func_name' not found in TypeScript files"
        return 1
    fi
    
    # Parse expected parameters
    IFS=',' read -ra PARAMS <<< "$expected_params"
    local all_params_found=true
    
    for param in "${PARAMS[@]}"; do
        IFS=':' read -ra PARAM_PARTS <<< "$param"
        local param_name="${PARAM_PARTS[0]}"
        local param_type="${PARAM_PARTS[1]}"
        
        # Check if parameter exists in signature
        if echo "$func_signature" | grep -qF "$param_name"; then
            : # Parameter found, do nothing
        else
            print_error "  Parameter '$param_name' with type '$param_type' not found or incorrect in $func_name"
            all_params_found=false
        fi
    done
    
    if [ "$all_params_found" = true ]; then
        print_success "Function '$func_name' signature matches contract"
        return 0
    else
        return 1
    fi
}

################################################################################
# Main Validation Logic
################################################################################

validate_project() {
    print_header "Dagger Contract Validation"
    
    print_info "Project Directory: $PROJECT_DIR"
    print_info "CICD Directory: $CICD_DIR"
    echo ""
    
    # Check if cicd directory exists
    if [ ! -d "$CICD_DIR" ]; then
        print_error "CICD directory not found: $CICD_DIR"
        print_info "Expected to find a 'cicd' directory containing Dagger functions"
        exit 1
    fi
    
    print_success "CICD directory found"
    
    # Detect language
    LANGUAGE=$(detect_language "$CICD_DIR")
    
    if [ "$LANGUAGE" = "unknown" ]; then
        print_error "Unable to detect Dagger module language"
        print_info "Supported languages: Go, Python, Java, TypeScript"
        exit 1
    fi
    
    print_success "Detected language: $LANGUAGE"
    
    print_section "Validating Function Signatures"
    
    # Get the appropriate contract based on language
    case "$LANGUAGE" in
        golang)
            FILE_PATTERN="*.go"
            VALIDATE_FUNC=validate_golang_function
            ;;
        python)
            FILE_PATTERN="*.py"
            VALIDATE_FUNC=validate_python_function
            ;;
        java)
            FILE_PATTERN="*.java"
            VALIDATE_FUNC=validate_java_function
            ;;
        typescript)
            FILE_PATTERN="*.ts"
            VALIDATE_FUNC=validate_typescript_function
            ;;
    esac
    
    # Read all source files
    FILE_CONTENT=$(find "$CICD_DIR" -name "$FILE_PATTERN" -type f -exec cat {} \; 2>/dev/null || echo "")
    
    if [ -z "$FILE_CONTENT" ]; then
        print_error "No source files found matching pattern: $FILE_PATTERN"
        exit 1
    fi
    
    # Validate each required function
    FUNCTION_NAMES=$(get_function_names "$LANGUAGE")
    for func_name in $FUNCTION_NAMES; do
        expected_params=$(get_contract_params "$LANGUAGE" "$func_name")
        if [ -z "$expected_params" ]; then
            print_warning "No contract definition found for function '$func_name' in language '$LANGUAGE'"
            continue
        fi
        $VALIDATE_FUNC "$func_name" "$expected_params" "$FILE_CONTENT"
    done
    
    # Print summary
    print_section "Validation Summary"
    
    echo -e "Total Checks:  ${BLUE}$TOTAL_CHECKS${NC}"
    echo -e "Passed:        ${GREEN}$PASSED_CHECKS${NC}"
    echo -e "Failed:        ${RED}$FAILED_CHECKS${NC}"
    echo ""
    
    if [ $FAILED_CHECKS -eq 0 ]; then
        print_success "All function signatures conform to the cicd-local contract!"
        echo ""
        print_info "Your Dagger module is compatible with cicd-local pipelines"
        exit 0
    else
        print_error "Some function signatures do not conform to the contract"
        echo ""
        print_info "Please review the errors above and update your Dagger functions"
        print_info "Reference: $SCRIPT_DIR/cicd_dagger_contract/README.md"
        exit 1
    fi
}

################################################################################
# Entry Point
################################################################################

validate_project
