# Privileged Functions Feature

## Overview

The privileged functions feature provides reusable, secure functions for sensitive operations like authentication and secret management. These functions are automatically injected into projects during pipeline execution and cleaned up afterward.

## Architecture

```
cicd-local/
├── privileged/                    # Source privileged functions
│   ├── auth.go                   # Registry & AWS authentication
│   ├── secrets.go                # Secret file management
│   └── README.md                 # Complete documentation
├── manage_privileged.sh          # Injection/cleanup automation
└── local_*_pipeline.sh           # Pipeline scripts (all updated)

Project (during execution):
└── cicd/
    └── privileged/               # Temporarily injected
        ├── auth.go              # (copied, auto-cleaned)
        └── secrets.go           # (copied, auto-cleaned)
```

## Automatic Workflow

### 1. Injection (Before Dagger Execution)

When any pipeline runs, the following happens automatically:

```bash
# In all pipeline scripts
if has_privileged_functions; then
    inject_privileged_functions "$SOURCE_DIR"
    trap "cleanup_privileged_functions '$SOURCE_DIR'" EXIT
fi
```

**Actions:**
- Copies `privileged/` from cicd-local to `{project}/cicd/privileged/`
- Adds `privileged/` to project's `.gitignore`
- Sets up cleanup trap for script exit

### 2. Usage (During Dagger Execution)

Your Dagger functions can import and use privileged functions:

```go
import "github.com/your-org/your-project/cicd/privileged"

func (m *Cicd) Build(ctx context.Context, source *dagger.Directory) (*dagger.Container, error) {
    // Use privileged authentication
    if privileged.HasRegistryCredentials() {
        if err := privileged.AuthenticateRegistry(ctx); err != nil {
            return nil, err
        }
    }
    
    // Load secrets
    token, err := privileged.LoadSecretFile("api-token")
    if err != nil {
        return nil, err
    }
    
    // Build with authenticated access...
}
```

### 3. Cleanup (After Dagger Execution)

When the pipeline completes (success or failure):

```bash
# Automatically triggered via trap
cleanup_privileged_functions "$SOURCE_DIR"
```

**Actions:**
- Removes `{project}/cicd/privileged/` directory
- Only skipped if `CICD_LOCAL_KEEP_PRIVILEGED=true`

## Available Functions

### Registry Authentication (`auth.go`)

```go
// Check if registry credentials are configured
func HasRegistryCredentials() bool

// Authenticate with container registry
func AuthenticateRegistry(ctx context.Context) error

// Get Dagger secret for registry authentication
func GetRegistrySecret(ctx context.Context, client *dagger.Client) (*dagger.Secret, error)

// Create Docker auth config JSON
func CreateDockerAuthConfig() (string, error)
```

**Environment Variables:**
- `CONTAINER_REGISTRY` - Registry hostname (e.g., "ghcr.io")
- `CONTAINER_REGISTRY_USER` - Username
- `CONTAINER_REGISTRY_PASSWORD` - Password/token

### AWS Credentials (`auth.go`)

```go
// Check if AWS credentials are configured
func HasAWSCredentials() bool

// Get AWS credentials from environment
func GetAWSCredentials() (accessKey, secretKey, sessionToken string, err error)
```

**Environment Variables:**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN` (optional)

### Secret Management (`secrets.go`)

```go
// Get path to secret file in ~/.cicd-local/secrets/
func GetSecretPath(secretName string) (string, error)

// Load secret file contents
func LoadSecretFile(secretName string) ([]byte, error)

// Try environment variable first, fallback to secret file
func GetEnvOrSecret(envVar, secretName string) (string, error)
```

**Storage Location:** `~/.cicd-local/secrets/{secretName}`

## Configuration

### Environment Variables

```bash
# Registry authentication
export CONTAINER_REGISTRY="ghcr.io"
export CONTAINER_REGISTRY_USER="username"
export CONTAINER_REGISTRY_PASSWORD="ghp_token"

# AWS credentials
export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

# Keep privileged functions after execution (debugging)
export CICD_LOCAL_KEEP_PRIVILEGED=true
```

### Secret Files

```bash
# Create secrets directory
mkdir -p ~/.cicd-local/secrets

# Store sensitive values
echo "my-secret-token" > ~/.cicd-local/secrets/api-token
chmod 600 ~/.cicd-local/secrets/api-token

# Store multi-line secrets
cat > ~/.cicd-local/secrets/ssh-key <<EOF
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----
EOF
chmod 600 ~/.cicd-local/secrets/ssh-key
```

## Security Features

### 1. No Credentials in Code
- Functions retrieve credentials from environment or secure storage
- No hardcoded secrets in repository

### 2. Automatic Gitignore
- Privileged functions automatically added to `.gitignore`
- Prevents accidental commits to version control

### 3. Automatic Cleanup
- Functions removed after pipeline execution
- Optional retention for debugging with `CICD_LOCAL_KEEP_PRIVILEGED=true`

### 4. Secure Storage
- Secret files stored in `~/.cicd-local/secrets/` with restrictive permissions
- Recommended: `chmod 600` for all secret files

### 5. Optional Usage
- Projects only use privileged functions if explicitly imported
- No forced dependencies on authentication methods

## Updated Pipeline Scripts

All 5 pipeline scripts now support privileged functions:

1. **local_ci_pipeline.sh** - CI pipeline with build, test, deliver
2. **local_deliver_pipeline.sh** - Artifact delivery
3. **local_deploy_pipeline.sh** - Kubernetes deployment
4. **local_iat_pipeline.sh** - Integration and acceptance testing
5. **local_staging_pipeline.sh** - Blue-green deployment testing

Each script:
- Sources `manage_privileged.sh` at startup
- Injects privileged functions before first Dagger call
- Sets up cleanup trap for automatic removal
- Handles injection failures gracefully

## Debugging

### Keep Functions After Execution

```bash
export CICD_LOCAL_KEEP_PRIVILEGED=true
cicd-local ci

# Functions remain in project/cicd/privileged/ for inspection
ls -la cicd/privileged/
```

### Verify Injection

```bash
# Check if privileged functions are available
if [ -d "cicd/privileged" ]; then
    echo "Privileged functions injected"
    ls -la cicd/privileged/
else
    echo "Privileged functions not present"
fi
```

### Manual Injection/Cleanup

```bash
# Source the management script
source ~/cicd-local/manage_privileged.sh

# Manual injection
inject_privileged_functions .

# Check status
has_privileged_functions && echo "Available"
verify_privileged_injection . && echo "Injected"

# Manual cleanup
cleanup_privileged_functions .
```

## Examples

### Example 1: Authenticated Registry Access

```go
package main

import (
    "context"
    "fmt"
    "dagger.io/dagger"
    "github.com/your-org/your-project/cicd/privileged"
)

func (m *Cicd) Build(ctx context.Context, source *dagger.Directory) (*dagger.Container, error) {
    client, err := dagger.Connect(ctx)
    if err != nil {
        return nil, err
    }
    defer client.Close()
    
    // Build base container
    container := client.Container().From("golang:1.21")
    
    // Add registry authentication if available
    if privileged.HasRegistryCredentials() {
        secret, err := privileged.GetRegistrySecret(ctx, client)
        if err != nil {
            return nil, fmt.Errorf("failed to get registry secret: %w", err)
        }
        
        registry := os.Getenv("CONTAINER_REGISTRY")
        container = container.WithRegistryAuth(registry, 
            os.Getenv("CONTAINER_REGISTRY_USER"), 
            secret)
    }
    
    // Build with authenticated access to private base images
    return container.
        WithDirectory("/src", source).
        WithWorkdir("/src").
        WithExec([]string{"go", "build", "-o", "app"}).
        WithEntrypoint([]string{"./app"}), nil
}
```

### Example 2: Secret File Loading

```go
func (m *Cicd) IntegrationTest(ctx context.Context, source *dagger.Directory) (string, error) {
    // Load API token from secure storage
    apiToken, err := privileged.LoadSecretFile("api-token")
    if err != nil {
        return "", fmt.Errorf("failed to load API token: %w", err)
    }
    
    // Use token in tests
    client, _ := dagger.Connect(ctx)
    defer client.Close()
    
    result, err := client.Container().
        From("golang:1.21").
        WithDirectory("/src", source).
        WithSecretVariable("API_TOKEN", client.SetSecret("api-token", string(apiToken))).
        WithExec([]string{"go", "test", "./..."}).
        Stdout(ctx)
    
    return result, err
}
```

### Example 3: Environment Variable Fallback

```go
func (m *Cicd) Deploy(ctx context.Context, source *dagger.Directory) (string, error) {
    // Try environment variable first, fallback to secret file
    dbPassword, err := privileged.GetEnvOrSecret("DB_PASSWORD", "db-password")
    if err != nil {
        return "", fmt.Errorf("database password not found: %w", err)
    }
    
    // Use in deployment configuration
    client, _ := dagger.Connect(ctx)
    defer client.Close()
    
    secret := client.SetSecret("db-password", dbPassword)
    
    // Deploy with secret...
    return "Deployment successful", nil
}
```

## Troubleshooting

### Issue: Injection Fails

**Symptom:** Warning message "Could not inject privileged functions"

**Causes:**
- cicd-local installation path not found
- No privileged/ directory in cicd-local
- Permission issues

**Solution:**
```bash
# Verify cicd-local installation
which cicd-local

# Check privileged directory exists
ls -la ~/cicd-local/privileged/

# Ensure manage_privileged.sh is executable
chmod +x ~/cicd-local/manage_privileged.sh
```

### Issue: Import Error in Dagger Code

**Symptom:** Go import error for `cicd/privileged`

**Cause:** Privileged functions not injected (or cleaned up before Dagger execution)

**Solution:**
```bash
# Manually inject for testing
source ~/cicd-local/manage_privileged.sh
inject_privileged_functions .

# Keep functions for debugging
export CICD_LOCAL_KEEP_PRIVILEGED=true
cicd-local ci
```

### Issue: Authentication Fails

**Symptom:** Registry or AWS authentication errors

**Solution:**
```bash
# Verify credentials are set
echo $CONTAINER_REGISTRY
echo $CONTAINER_REGISTRY_USER
echo $CONTAINER_REGISTRY_PASSWORD

echo $AWS_ACCESS_KEY_ID
echo $AWS_SECRET_ACCESS_KEY

# Load from local_cicd.env
source ./local_cicd.env
```

### Issue: Secret File Not Found

**Symptom:** Error: "secret file not found"

**Solution:**
```bash
# Check secrets directory
ls -la ~/.cicd-local/secrets/

# Create missing secret
echo "secret-value" > ~/.cicd-local/secrets/my-secret
chmod 600 ~/.cicd-local/secrets/my-secret
```

## Documentation

- **privileged/README.md** - Complete function documentation with examples
- **README.md** - Quick start and overview
- **docs/USER_GUIDE.md** - Comprehensive usage guide
- **manage_privileged.sh** - Implementation (well-commented)

## Implementation Details

### Pipeline Integration Points

All pipeline scripts follow this pattern:

```bash
# 1. Source management functions (after env loading)
source "${SCRIPT_DIR}/manage_privileged.sh"

# 2. Inject before execution (after validation, before Dagger)
if has_privileged_functions; then
    print_info "Injecting privileged functions..."
    if inject_privileged_functions "$SOURCE_DIR"; then
        print_success "Privileged functions injected"
        trap "cleanup_privileged_functions '$SOURCE_DIR'" EXIT
    else
        print_warning "Could not inject privileged functions (continuing anyway)"
    fi
fi

# 3. Cleanup via trap (automatic on exit)
# trap "cleanup_privileged_functions '$SOURCE_DIR'" EXIT
```

### Files Modified

**Created:**
- `privileged/auth.go` - 151 lines
- `privileged/secrets.go` - 58 lines
- `privileged/README.md` - 237 lines
- `manage_privileged.sh` - 98 lines
- `PRIVILEGED_FUNCTIONS.md` - This file

**Modified:**
- `local_ci_pipeline.sh` - Added sourcing + injection
- `local_deliver_pipeline.sh` - Added sourcing + injection
- `local_deploy_pipeline.sh` - Added sourcing + injection
- `local_iat_pipeline.sh` - Added sourcing + injection
- `local_staging_pipeline.sh` - Added sourcing + injection
- `README.md` - Added privileged functions section
- `docs/USER_GUIDE.md` - Added authentication and configuration sections

## Testing

To test the privileged functions feature:

```bash
# 1. Set up test environment
export CONTAINER_REGISTRY="ttl.sh"
export CONTAINER_REGISTRY_USER="test"
export CONTAINER_REGISTRY_PASSWORD="test-token"

# 2. Create test secret
mkdir -p ~/.cicd-local/secrets
echo "test-secret-value" > ~/.cicd-local/secrets/test-secret
chmod 600 ~/.cicd-local/secrets/test-secret

# 3. Initialize test project
mkdir -p /tmp/test-project
cd /tmp/test-project
cicd-local init go test-app

# 4. Add privileged function usage to cicd/main.go
# (Import and use privileged.HasRegistryCredentials() in Build function)

# 5. Run pipeline with debugging
export CICD_LOCAL_KEEP_PRIVILEGED=true
cicd-local ci

# 6. Verify injection
ls -la cicd/privileged/

# 7. Verify .gitignore
grep privileged cicd/.gitignore

# 8. Test cleanup
export CICD_LOCAL_KEEP_PRIVILEGED=false
cicd-local ci
# Verify privileged/ directory is removed
```

## Future Enhancements

Potential improvements for future versions:

1. **Additional Authentication Methods:**
   - GitHub API tokens
   - GitLab authentication
   - Azure DevOps credentials
   - Generic OAuth2 flows

2. **Enhanced Secret Management:**
   - Integration with external secret managers (Vault, AWS Secrets Manager)
   - Encrypted secret storage
   - Secret rotation helpers

3. **Additional Utilities:**
   - Certificate management
   - SSH key handling
   - API client wrappers

4. **Language Support:**
   - Python implementation
   - Java implementation
   - TypeScript implementation

## Summary

The privileged functions feature provides:

✅ Secure, reusable authentication and secret management  
✅ Automatic injection and cleanup  
✅ No credentials in code repositories  
✅ Optional retention for debugging  
✅ Seamless integration with all pipelines  
✅ Comprehensive documentation and examples  

All 5 pipeline scripts are updated and ready to use!
