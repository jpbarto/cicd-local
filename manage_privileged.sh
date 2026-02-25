#!/bin/bash

################################################################################
# Privileged Functions Manager
#
# Manages injection and cleanup of privileged functions into project cicd directories.
# These functions provide access to sensitive operations without requiring projects
# to store privileged code in their repositories.
#
# Usage:
#   source manage_privileged.sh
#   inject_privileged_functions /path/to/project
#   cleanup_privileged_functions /path/to/project
################################################################################

# Get the directory where cicd-local is installed
get_cicd_local_dir() {
    local script_path="${BASH_SOURCE[0]}"
    while [ -L "$script_path" ]; do
        local dir="$(cd -P "$(dirname "$script_path")" && pwd)"
        script_path="$(readlink "$script_path")"
        [[ $script_path != /* ]] && script_path="$dir/$script_path"
    done
    echo "$(cd -P "$(dirname "$script_path")" && pwd)"
}

CICD_LOCAL_DIR="$(get_cicd_local_dir)"
PRIVILEGED_SOURCE="${CICD_LOCAL_DIR}/privileged"

# Inject privileged functions into a project's cicd directory
# This copies the privileged function files and injects runtime secrets
# from the environment (kubeconfig, contexts, etc.) into secrets.go
inject_privileged_functions() {
    local project_dir="${1:-$(pwd)}"
    local cicd_dir="${project_dir}/cicd"
    local privileged_dest="${cicd_dir}/privileged"
    
    # Check if cicd directory exists
    if [ ! -d "${cicd_dir}" ]; then
        echo "Warning: cicd directory not found at ${cicd_dir}"
        return 1
    fi
    
    # Check if privileged source exists
    if [ ! -d "${PRIVILEGED_SOURCE}" ]; then
        echo "Warning: privileged source directory not found at ${PRIVILEGED_SOURCE}"
        return 1
    fi
    
    # Create privileged destination directory
    mkdir -p "${privileged_dest}"
    
    # Copy privileged functions
    cp -r "${PRIVILEGED_SOURCE}"/* "${privileged_dest}/" 2>/dev/null || {
        echo "Warning: Failed to copy privileged functions"
        return 1
    }
    
    # Inject runtime secrets into secrets.go
    inject_secrets_into_privileged "${privileged_dest}"
    
    # Add to .gitignore if it exists
    local gitignore="${cicd_dir}/.gitignore"
    if [ -f "${gitignore}" ]; then
        if ! grep -q "^privileged/$" "${gitignore}" 2>/dev/null; then
            echo "privileged/" >> "${gitignore}"
        fi
    else
        echo "privileged/" > "${gitignore}"
    fi
    
    # Also add to project root .gitignore
    local root_gitignore="${project_dir}/.gitignore"
    if [ -f "${root_gitignore}" ]; then
        if ! grep -q "^cicd/privileged/$" "${root_gitignore}" 2>/dev/null; then
            echo "cicd/privileged/" >> "${root_gitignore}"
        fi
    fi
    
    return 0
}

# Cleanup privileged functions from a project's cicd directory
cleanup_privileged_functions() {
    local project_dir="${1:-$(pwd)}"
    local privileged_dest="${project_dir}/cicd/privileged"
    
    # Check if we should keep privileged functions (for debugging)
    if [ "${CICD_LOCAL_KEEP_PRIVILEGED}" = "true" ]; then
        echo "Info: Keeping privileged functions (CICD_LOCAL_KEEP_PRIVILEGED=true)"
        return 0
    fi
    
    # Remove privileged directory if it exists
    if [ -d "${privileged_dest}" ]; then
        rm -rf "${privileged_dest}"
    fi
    
    return 0
}

# Check if privileged functions are available
has_privileged_functions() {
    [ -d "${PRIVILEGED_SOURCE}" ] && [ -n "$(ls -A "${PRIVILEGED_SOURCE}" 2>/dev/null)" ]
}

# Verify privileged functions were injected successfully
verify_privileged_injection() {
    local project_dir="${1:-$(pwd)}"
    local privileged_dest="${project_dir}/cicd/privileged"
    
    [ -d "${privileged_dest}" ] && [ -f "${privileged_dest}/kubectl.go" ] && [ -f "${privileged_dest}/secrets.go" ]
}

# Inject runtime secrets into privileged functions
# This replaces placeholder values in secrets.go with actual secrets from the environment
inject_secrets_into_privileged() {
    local privileged_dest="$1"
    local secrets_file="${privileged_dest}/secrets.go"
    
    if [ ! -f "${secrets_file}" ]; then
        echo "Warning: secrets.go not found at ${secrets_file}"
        return 1
    fi
    
    # Get kubeconfig content
    local kubeconfig_content=""
    if [ -n "${KUBECONFIG}" ] && [ -f "${KUBECONFIG}" ]; then
        kubeconfig_content="$(cat "${KUBECONFIG}")"
    elif [ -f "${HOME}/.kube/config" ]; then
        kubeconfig_content="$(cat "${HOME}/.kube/config")"
    else
        echo "Warning: No kubeconfig found at KUBECONFIG or ~/.kube/config"
    fi
    
    # Get kubectl context (can be empty)
    local kubectl_context="${KUBECTL_CONTEXT:-}"
    
    # Get helm timeout (default 5m)
    local helm_timeout="${HELM_TIMEOUT:-5m}"
    
    # Escape special characters for sed
    # Note: We need to handle multi-line kubeconfig content
    if [ -n "${kubeconfig_content}" ]; then
        # Use Python for reliable multi-line replacement
        # Python is available on macOS/Linux and handles escaping properly
        python3 -c '
import sys
import re

# Read the secrets file
with open("'"${secrets_file}"'", "r") as f:
    content = f.read()

# Read kubeconfig from stdin
kubeconfig = sys.stdin.read()

# Escape backticks and backslashes for Go string literal
kubeconfig_escaped = kubeconfig.replace("\\", "\\\\").replace("`", "\\`")

# Replace the placeholder
content = content.replace("__INJECTED_KUBECONFIG__", kubeconfig_escaped)

# Write back
with open("'"${secrets_file}"'", "w") as f:
    f.write(content)
' <<< "${kubeconfig_content}"
    fi
    
    # Replace kubectl context
    sed -i.bak "s/__INJECTED_KUBECTL_CONTEXT__/${kubectl_context}/g" "${secrets_file}"
    
    # Replace helm timeout
    sed -i.bak "s/__INJECTED_HELM_TIMEOUT__/${helm_timeout}/g" "${secrets_file}"
    
    # Remove backup file
    rm -f "${secrets_file}.bak"
    
    return 0
}
