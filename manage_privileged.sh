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

# Inject privileged functions into a project's cicd/internal/cicd directory.
# This copies the privileged function files and injects runtime secrets
# from the environment (kubeconfig, contexts, etc.) into secrets.go
inject_privileged_functions() {
    local project_dir="${1:-$(pwd)}"
    local cicd_dir="${project_dir}/cicd"
    local privileged_dest="${cicd_dir}/internal/cicd"
    
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
    
    # Resolve the dagger module path from cicd/dagger.json and rewrite imports
    inject_dagger_module_path "${cicd_dir}" "${privileged_dest}"

    # Inject runtime secrets into secrets.go
    inject_secrets_into_privileged "${privileged_dest}"
    
    return 0
}

# Cleanup privileged functions from a project's cicd directory
cleanup_privileged_functions() {
    local project_dir="${1:-$(pwd)}"
    local privileged_dest="${project_dir}/cicd/internal/cicd"
    
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
    local privileged_dest="${project_dir}/cicd/internal/cicd"

    [ -d "${privileged_dest}" ] && [ -f "${privileged_dest}/kubectl.go" ] && [ -f "${privileged_dest}/secrets.go" ]
}

# Read the Dagger module name from a cicd/dagger.json file.
# Returns the value of the top-level "name" field.
get_dagger_project_name() {
    local cicd_dir="$1"
    local dagger_json="${cicd_dir}/dagger.json"

    if [ ! -f "${dagger_json}" ]; then
        echo ""
        return 1
    fi

    # Use python3 for reliable JSON parsing (available on macOS and most Linux)
    python3 -c "
import json, sys
with open('${dagger_json}') as f:
    d = json.load(f)
print(d.get('name', ''))
" 2>/dev/null || echo ""
}

# Rewrite the __DAGGER_MODULE_PATH__ placeholder in all copied .go files.
# The correct import path is: dagger/<project-name>/internal/dagger
inject_dagger_module_path() {
    local cicd_dir="$1"
    local privileged_dest="$2"

    local project_name
    project_name="$(get_dagger_project_name "${cicd_dir}")"

    if [ -z "${project_name}" ]; then
        echo "Warning: Could not determine Dagger project name from ${cicd_dir}/dagger.json; privileged functions may not compile"
        return 1
    fi

    local module_path="dagger/${project_name}/internal/dagger"

    # Replace the dagger.io/dagger import with the project-local internal dagger
    # module path in every .go file copied into the privileged directory.
    for go_file in "${privileged_dest}"/*.go; do
        [ -f "${go_file}" ] || continue
        sed -i.bak "s|\"dagger.io/dagger\"|\"${module_path}\"|g" "${go_file}"
        rm -f "${go_file}.bak"
    done

    return 0
}

# Inject runtime secrets into privileged functions.
# Replaces the __INJECTED_KUBECTL_CONTEXT__ placeholder in secrets.go with
# the output of `kubectl config view --minify --raw` (the full minified
# kubeconfig for the current context, suitable for use as a kubeconfig file).
inject_secrets_into_privileged() {
    local privileged_dest="$1"
    local secrets_file="${privileged_dest}/secrets.go"

    if [ ! -f "${secrets_file}" ]; then
        echo "Warning: secrets.go not found at ${secrets_file}"
        return 1
    fi

    # Capture the minified kubeconfig for the current context.
    # This includes the cluster, user credentials, and context in one self-contained blob.
    local kubeconfig_content
    if ! kubeconfig_content="$(kubectl config view --minify --raw 2>/dev/null)"; then
        echo "Warning: 'kubectl config view --minify --raw' failed - kubeconfig will not be injected"
        return 1
    fi

    if [ -z "${kubeconfig_content}" ]; then
        echo "Warning: 'kubectl config view --minify --raw' returned empty output - kubeconfig will not be injected"
        return 1
    fi

    # Use Python for reliable multi-line / special-character replacement.
    # Only the const assignment line is targeted (backtick-quoted raw string literal),
    # leaving sentinel checks like == "__INJECTED_KUBECTL_CONTEXT__" untouched.
    python3 -c '
import sys, re

with open(sys.argv[1], "r") as f:
    content = f.read()

kubeconfig = sys.stdin.read()

# Escape characters that would break a Go raw string literal (backtick-quoted)
kubeconfig_escaped = kubeconfig.replace("\\", "\\\\").replace("`", "\\`")

# Only replace the backtick-quoted placeholder in the const assignment, e.g.:
#   injectedKubectlContext = `__INJECTED_KUBECTL_CONTEXT__`
content = re.sub(
    r"(injectedKubectlContext\s*=\s*)`__INJECTED_KUBECTL_CONTEXT__`",
    r"\1`" + kubeconfig_escaped + r"`",
    content
)

with open(sys.argv[1], "w") as f:
    f.write(content)
' "${secrets_file}" <<< "${kubeconfig_content}"

    # Inject container and helm repository URLs from the environment.
    # These are plain single-line strings so sed is sufficient.
    local container_repo_url="${CONTAINER_REPOSITORY_URL:-}"
    local helm_repo_url="${HELM_REPOSITORY_URL:-}"

    if [ -z "${container_repo_url}" ]; then
        echo "Warning: CONTAINER_REPOSITORY_URL is not set - container repository URL will not be injected"
    else
        sed -i.bak "s|__INJECTED_CONTAINER_REPOSITORY_URL__|${container_repo_url}|g" "${secrets_file}"
        rm -f "${secrets_file}.bak"
    fi

    if [ -z "${helm_repo_url}" ]; then
        echo "Warning: HELM_REPOSITORY_URL is not set - helm repository URL will not be injected"
    else
        sed -i.bak "s|__INJECTED_HELM_REPOSITORY_URL__|${helm_repo_url}|g" "${secrets_file}"
        rm -f "${secrets_file}.bak"
    fi

    return 0
}
