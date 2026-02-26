# Secret Injection Mechanism

This document explains how `cicd-local` injects secrets into privileged functions at runtime while maintaining security and isolation.

## Problem Statement

Dagger functions run in isolated containers with no access to the local filesystem. This creates a challenge:

1. ❌ **Cannot read `~/.kube/config`** - Dagger containers don't have access to local files
2. ❌ **Cannot pass via `dagger call`** - This would expose secrets to untrusted user-defined Dagger code
3. ✅ **Need privileged functions** - Must have access to secrets to perform infrastructure operations

## Solution: Template and Inject Pattern

We use a **template-and-inject** pattern that provides secrets to privileged functions without exposing them to user code.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ Development Time (cicd-local init)                              │
│                                                                 │
│  1. Copy privileged/*.go → project/cicd/privileged/            │
│     - Files contain placeholders: __INJECTED_KUBECONFIG__      │
│     - IDE sees valid Go code (no import errors)                │
│     - Safe to commit (no secrets)                              │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Runtime (before dagger call)                                    │
│                                                                 │
│  2. manage_privileged.sh injects secrets:                      │
│     - Read ~/.kube/config or $KUBECONFIG                       │
│     - Read $KUBECTL_CONTEXT, $HELM_TIMEOUT                     │
│     - Replace placeholders in secrets.go                        │
│                                                                 │
│  3. Result: secrets.go now contains actual credentials         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Execution (dagger call my-function)                            │
│                                                                 │
│  4. User-defined Dagger function calls:                        │
│     privileged.LoadKubeconfig(ctx, client)                     │
│                                                                 │
│  5. Privileged function returns Dagger secret                  │
│     (user code NEVER sees actual credentials)                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Cleanup (after execution)                                       │
│                                                                 │
│  6. Optional: Remove cicd/privileged/                          │
│     (if CICD_LOCAL_KEEP_PRIVILEGED != true)                    │
└─────────────────────────────────────────────────────────────────┘
```

## Implementation Details

### secrets.go Template

The `privileged/secrets.go` file contains placeholder constants:

```go
const (
    injectedKubeconfig = `__INJECTED_KUBECONFIG__`
    injectedKubectlContext = `__INJECTED_KUBECTL_CONTEXT__`
    injectedHelmTimeout = `__INJECTED_HELM_TIMEOUT__`
)
```

### Injection Process (manage_privileged.sh)

The `inject_secrets_into_privileged()` function:

1. **Reads secrets from environment:**
   - Kubeconfig: `$KUBECONFIG` or `~/.kube/config`
   - Context: `$KUBECTL_CONTEXT` (optional)
   - Helm timeout: `$HELM_TIMEOUT` (default: 5m)

2. **Replaces placeholders using Python:**
   ```python
   # Escape backticks and backslashes for Go string literal
   kubeconfig_escaped = kubeconfig.replace("\\", "\\\\").replace("`", "\\`")
   
   # Replace placeholder
   content = content.replace("__INJECTED_KUBECONFIG__", kubeconfig_escaped)
   ```

3. **Writes modified secrets.go:**
   - Original placeholders replaced with actual values
   - File still valid Go code
   - Contains sensitive credentials (in memory only)

### User Code Usage

User-defined Dagger functions call privileged functions:

```go
// User code - NEVER sees actual credentials
kubeconfig, err := privileged.LoadKubeconfig(ctx, client)

// privileged.LoadKubeconfig internally:
// 1. Reads injectedKubeconfig constant (has real credentials)
// 2. Creates Dagger secret: client.SetSecret("kubeconfig", injectedKubeconfig)
// 3. Returns *dagger.Secret (opaque handle, no access to content)
```

### Security Properties

✅ **Isolation**: User code receives `*dagger.Secret`, not raw credentials

✅ **No Persistence**: Secrets injected in-memory, optionally removed after execution

✅ **No Repository Storage**: Template files (with placeholders) safe to commit

✅ **IDE Compatibility**: Valid Go code during development (placeholders are valid string literals)

## Environment Variables

### Injected into secrets.go

These are read from the environment and injected as Go constants:

- `KUBECONFIG` - Path to kubeconfig file (default: `~/.kube/config`)
- `KUBECTL_CONTEXT` - Kubernetes context to use (optional)
- `HELM_TIMEOUT` - Helm operation timeout (default: `5m`)

### Passed to Containers

These are passed directly to Dagger containers (not injected):

- `AWS_ACCESS_KEY_ID` - For Terraform/AWS operations
- `AWS_SECRET_ACCESS_KEY` - For Terraform/AWS operations
- `AWS_SESSION_TOKEN` - Optional AWS session token
- `AWS_REGION` - AWS region
- `TF_VAR_*` - Terraform variables

## Testing

Run the injection test suite:

```bash
./test_injection.sh
```

This validates:
1. Privileged functions are copied correctly
2. Placeholders are replaced with actual values
3. Injection doesn't break Go syntax
4. Cleanup works properly

## Debugging

### Keep Privileged Functions After Execution

```bash
export CICD_LOCAL_KEEP_PRIVILEGED=true
./local_ci_pipeline.sh
```

Then inspect the injected secrets.go:

```bash
cat my-project/cicd/privileged/secrets.go
```

### Verify Injection

After running a pipeline, check if secrets were injected:

```bash
# Should NOT contain placeholders
grep "__INJECTED_KUBECONFIG__" my-project/cicd/privileged/secrets.go

# Should contain actual values (be careful - contains secrets!)
head -20 my-project/cicd/privileged/secrets.go
```

## Alternative Approaches Considered

### ❌ Pass Secrets via dagger call Arguments

```bash
# BAD - Would expose secrets to untrusted user-defined Dagger code
# NOTE: This is no longer supported by the contract.
# Deploy, Validate, and IntegrationTest do NOT accept --kubeconfig.
dagger call deploy --kubeconfig-file=~/.kube/config
```

**Problem**: User-defined Dagger functions would receive the file content directly.

### ❌ Mount Secret Files into Container

```bash
# BAD - User code could access mounted secrets
container.WithMountedSecret("/secrets/kubeconfig", secret)
```

**Problem**: User code can read `/secrets/kubeconfig` from the container.

### ✅ Template and Inject (Current Solution)

**Advantages**:
- User code only receives opaque `*dagger.Secret` handles
- Secrets exist only during pipeline execution
- IDE has valid code during development
- No secrets in repository

## Future Enhancements

### Multiple Secret Sources

Support additional secret backends:

- HashiCorp Vault integration
- AWS Secrets Manager
- Azure Key Vault
- 1Password CLI

### Dynamic Secret Rotation

Inject short-lived credentials that expire after pipeline execution.

### Secret Audit Logging

Log which secrets were injected (but not their values) for compliance.

## Related Files

- `privileged/secrets.go` - Template file with placeholder constants
- `manage_privileged.sh` - Injection logic (function: `inject_secrets_into_privileged`)
- `test_injection.sh` - Validation test suite
- `local_*_pipeline.sh` - Pipeline scripts that call injection

## Questions?

For more information, see:
- [Privileged Functions README](privileged/README.md)
- [User Guide - Privileged Functions](docs/USER_GUIDE.md#privileged-functions)
