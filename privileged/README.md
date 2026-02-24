# Privileged Functions for cicd-local

This package provides privileged functions for infrastructure deployment operations that require elevated access or sensitive credentials. These functions are automatically injected into your project during pipeline execution and cleaned up afterward.

## Overview

The privileged package includes functions for:

- **Kubernetes Deployments** - Apply manifests using kubectl
- **Helm Charts** - Install/upgrade Helm releases  
- **Terraform Infrastructure** - Plan and apply Terraform configurations
- **Secret Management** - Load secrets and kubeconfig files

## Security Model

Privileged functions are:

1. ✅ **Copied during initialization** - Available in `cicd/privileged/` for development
2. 🔄 **Updated at runtime** - Refreshed before each pipeline execution
3. 📦 **Safe to commit** - Functions contain no sensitive credentials or secrets
4. 🧹 **Optionally cleaned** - Can be removed after execution with CICD_LOCAL_KEEP_PRIVILEGED=false

## Available Functions

### Kubernetes Operations

#### KubectlApply

Applies Kubernetes manifests using kubectl.

**Function Signature:**

```go
func KubectlApply(
    ctx context.Context,
    client *dagger.Client,
    manifestsDir *dagger.Directory,
    namespace string,
    kubeconfig *dagger.Secret,
) (string, error)
```

**Parameters:**

- `manifestsDir` - Directory containing Kubernetes YAML manifests
- `namespace` - Kubernetes namespace to apply to (optional, uses manifest default if empty)
- `kubeconfig` - Dagger secret containing kubeconfig content

**Environment Variables:**

- `KUBECTL_CONTEXT` - Kubernetes context to use (optional)

**Example:**

```go
import "github.com/your-org/your-project/cicd/privileged"

func (m *Cicd) Deploy(ctx context.Context, source *dagger.Directory) (string, error) {
    client, _ := dagger.Connect(ctx)
    defer client.Close()
    
    // Load kubeconfig
    kubeconfigSecret, err := privileged.LoadKubeconfig(ctx, client, "")
    if err != nil {
        return "", err
    }
    
    // Apply manifests
    output, err := privileged.KubectlApply(
        ctx,
        client,
        source.Directory("k8s"),
        "production",
        kubeconfigSecret,
    )
    if err != nil {
        return "", fmt.Errorf("kubectl apply failed: %w", err)
    }
    
    return output, nil
}
```

#### KubectlGet

Retrieves a Kubernetes resource and returns it as JSON.

**Function Signature:**

```go
func KubectlGet(
    ctx context.Context,
    client *dagger.Client,
    namespace string,
    resourceName string,
    kubeconfig *dagger.Secret,
) (string, error)
```

**Parameters:**

- `namespace` - Kubernetes namespace containing the resource
- `resourceName` - Resource to get (e.g., "pod/mypod", "deployment/myapp", "service/mysvc")
- `kubeconfig` - Dagger secret containing kubeconfig content

**Environment Variables:**

- `KUBECTL_CONTEXT` - Kubernetes context to use (optional)

**Example:**

```go
import "github.com/your-org/your-project/cicd/privileged"

func (m *Cicd) CheckDeployment(ctx context.Context) (string, error) {
    client, _ := dagger.Connect(ctx)
    defer client.Close()
    
    // Load kubeconfig
    kubeconfigSecret, err := privileged.LoadKubeconfig(ctx, client, "")
    if err != nil {
        return "", err
    }
    
    // Get deployment as JSON
    deploymentJSON, err := privileged.KubectlGet(
        ctx,
        client,
        "production",
        "deployment/myapp",
        kubeconfigSecret,
    )
    if err != nil {
        return "", fmt.Errorf("kubectl get failed: %w", err)
    }
    
    return deploymentJSON, nil
}
```

#### KubectlPortForward

Creates a port-forwarding tunnel to a Kubernetes resource as a background service.

**Function Signature:**

```go
func KubectlPortForward(
    ctx context.Context,
    client *dagger.Client,
    namespace string,
    resourceName string,
    ports string,
    kubeconfig *dagger.Secret,
) (*dagger.Service, error)
```

**Parameters:**

- `namespace` - Kubernetes namespace containing the resource
- `resourceName` - Resource to forward to (e.g., "pod/mypod", "service/mysvc")
- `ports` - Port mapping in format "localPort:remotePort" (e.g., "8080:80")
- `kubeconfig` - Dagger secret containing kubeconfig content

**Environment Variables:**

- `KUBECTL_CONTEXT` - Kubernetes context to use (optional)

**Example:**

```go
import "github.com/your-org/your-project/cicd/privileged"

func (m *Cicd) IntegrationTest(ctx context.Context) (string, error) {
    client, _ := dagger.Connect(ctx)
    defer client.Close()
    
    // Load kubeconfig
    kubeconfigSecret, err := privileged.LoadKubeconfig(ctx, client, "")
    if err != nil {
        return "", err
    }
    
    // Start port forwarding as a service
    portForwardSvc, err := privileged.KubectlPortForward(
        ctx,
        client,
        "production",
        "pod/myapp-xyz123",
        "8080:80",
        kubeconfigSecret,
    )
    if err != nil {
        return "", err
    }
    
    // Run tests against the forwarded port
    testResult, err := client.Container().
        From("curlimages/curl:latest").
        WithServiceBinding("app", portForwardSvc).
        WithExec([]string{"curl", "http://app:8080/health"}).
        Stdout(ctx)
    
    return testResult, err
}
```

### Helm Operations

#### HelmInstall

Installs or upgrades a Helm chart.

```go
func HelmInstall(
    ctx context.Context,
    client *dagger.Client,
    releaseName string,
    chartPath *dagger.Directory,
    namespace string,
    valuesFile *dagger.Directory,
    kubeconfig *dagger.Secret,
) (string, error)
```

**Parameters:**

- `releaseName` - Name of the Helm release
- `chartPath` - Directory containing the Helm chart
- `namespace` - Kubernetes namespace to install into
- `valuesFile` - Optional directory containing values.yaml file (can be nil)
- `kubeconfig` - Dagger secret containing kubeconfig content

**Environment Variables:**

- `HELM_TIMEOUT` - Timeout for helm operations (default: 5m)
- `KUBECTL_CONTEXT` - Kubernetes context to use (optional)

**Example:**

```go
import "github.com/your-org/your-project/cicd/privileged"

func (m *Cicd) Deploy(ctx context.Context, source *dagger.Directory) (string, error) {
    client, _ := dagger.Connect(ctx)
    defer client.Close()
    
    // Load kubeconfig
    kubeconfigSecret, err := privileged.LoadKubeconfig(ctx, client, "")
    if err != nil {
        return "", err
    }
    
    // Install Helm chart
    output, err := privileged.HelmInstall(
        ctx,
        client,
        "myapp",
        source.Directory("helm/myapp"),
        "production",
        source.Directory("helm/values"),
        kubeconfigSecret,
    )
    if err != nil {
        return "", fmt.Errorf("helm install failed: %w", err)
    }
    
    return output, nil
}
```

#### HelmUpgrade

Upgrades an existing Helm release.

**Function Signature:**

```go
func HelmUpgrade(
    ctx context.Context,
    client *dagger.Client,
    releaseName string,
    chartReference string,
    namespace string,
    kubeconfig *dagger.Secret,
) (string, error)
```

**Parameters:**

- `releaseName` - Name of the Helm release to upgrade
- `chartReference` - Chart reference (e.g., "bitnami/nginx", "stable/mysql")
- `namespace` - Kubernetes namespace containing the release
- `kubeconfig` - Dagger secret containing kubeconfig content

**Environment Variables:**

- `HELM_TIMEOUT` - Timeout for helm operations (default: 5m)
- `KUBECTL_CONTEXT` - Kubernetes context to use (optional)

**Example:**

```go
import "github.com/your-org/your-project/cicd/privileged"

func (m *Cicd) UpgradeApp(ctx context.Context) (string, error) {
    client, _ := dagger.Connect(ctx)
    defer client.Close()
    
    // Load kubeconfig
    kubeconfigSecret, err := privileged.LoadKubeconfig(ctx, client, "")
    if err != nil {
        return "", err
    }
    
    // Upgrade existing release
    output, err := privileged.HelmUpgrade(
        ctx,
        client,
        "myapp",
        "bitnami/nginx:15.0.0",
        "production",
        kubeconfigSecret,
    )
    if err != nil {
        return "", fmt.Errorf("helm upgrade failed: %w", err)
    }
    
    return output, nil
}
```

### Terraform Operations

#### TerraformPlan

Runs terraform plan and returns the plan output.

```go
func TerraformPlan(
    ctx context.Context,
    client *dagger.Client,
    terraformDir *dagger.Directory,
    varFile *dagger.Directory,
) (string, error)
```

**Parameters:**

- `terraformDir` - Directory containing Terraform configuration files
- `varFile` - Optional directory containing terraform.tfvars file (can be nil)

**Environment Variables:**

- `TF_VAR_*` - Terraform variables (e.g., TF_VAR_region=us-east-1)
- `AWS_ACCESS_KEY_ID` - AWS access key (if using AWS provider)
- `AWS_SECRET_ACCESS_KEY` - AWS secret key (if using AWS provider)
- `AWS_SESSION_TOKEN` - AWS session token (optional)
- `AWS_REGION` - AWS region (optional)

**Example:**

```go
import "github.com/your-org/your-project/cicd/privileged"

func (m *Cicd) Plan(ctx context.Context, source *dagger.Directory) (string, error) {
    client, _ := dagger.Connect(ctx)
    defer client.Close()
    
    // Run terraform plan
    planOutput, err := privileged.TerraformPlan(
        ctx,
        client,
        source.Directory("terraform"),
        source.Directory("terraform/vars"),
    )
    if err != nil {
        return "", fmt.Errorf("terraform plan failed: %w", err)
    }
    
    return planOutput, nil
}
```

#### TerraformApply

Runs terraform apply to create/update infrastructure.

```go
func TerraformApply(
    ctx context.Context,
    client *dagger.Client,
    terraformDir *dagger.Directory,
    varFile *dagger.Directory,
    autoApprove bool,
) (string, error)
```

**Parameters:**

- `terraformDir` - Directory containing Terraform configuration files
- `varFile` - Optional directory containing terraform.tfvars file (can be nil)
- `autoApprove` - Whether to auto-approve the apply (skips confirmation)

**Environment Variables:**

- Same as TerraformPlan

**Example:**

```go
import "github.com/your-org/your-project/cicd/privileged"

func (m *Cicd) Deploy(ctx context.Context, source *dagger.Directory) (string, error) {
    client, _ := dagger.Connect(ctx)
    defer client.Close()
    
    // Apply terraform configuration
    applyOutput, err := privileged.TerraformApply(
        ctx,
        client,
        source.Directory("terraform"),
        source.Directory("terraform/vars"),
        true, // auto-approve
    )
    if err != nil {
        return "", fmt.Errorf("terraform apply failed: %w", err)
    }
    
    return applyOutput, nil
}
```

### Secret Management

#### LoadKubeconfig

Loads a kubeconfig file as a Dagger secret.

```go
func LoadKubeconfig(
    ctx context.Context,
    client *dagger.Client,
    kubeconfigPath string,
) (*dagger.Secret, error)
```

**Parameters:**

- `kubeconfigPath` - Optional path to kubeconfig file (uses ~/.kube/config if empty)

**Environment Variables:**

- `KUBECONFIG` - Path to kubeconfig file (overrides default)

#### LoadSecretFile

Reads a secret from `~/.cicd-local/secrets/`.

```go
func LoadSecretFile(secretName string) ([]byte, error)
```

#### LoadSecretAsDaggerSecret

Loads a secret file as a Dagger secret.

```go
func LoadSecretAsDaggerSecret(client *dagger.Client, secretName string) (*dagger.Secret, error)
```

#### GetEnvOrSecret

Attempts to get a value from environment variable first, then falls back to secret file.

```go
func GetEnvOrSecret(envVar, secretName string) (string, error)
```

## Secret Storage

Store sensitive values in `~/.cicd-local/secrets/`:

```bash
# Create secrets directory
mkdir -p ~/.cicd-local/secrets

# Store API token
echo "my-secret-token" > ~/.cicd-local/secrets/api-token
chmod 600 ~/.cicd-local/secrets/api-token

# Store multi-line secret
cat > ~/.cicd-local/secrets/ssh-key <<EOF
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----
EOF
chmod 600 ~/.cicd-local/secrets/ssh-key
```

## Environment Variables

### Kubernetes/Helm Operations

```bash
export KUBECONFIG="~/.kube/config"      # Path to kubeconfig
export KUBECTL_CONTEXT="prod-cluster"   # Kubernetes context
export HELM_TIMEOUT="10m"               # Helm operation timeout
```

### Terraform Operations

```bash
# AWS credentials
export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
export AWS_SESSION_TOKEN="..."  # Optional
export AWS_REGION="us-east-1"

# Terraform variables
export TF_VAR_region="us-east-1"
export TF_VAR_environment="production"
```

### Pipeline Control

```bash
# Keep privileged functions after execution (for debugging)
export CICD_LOCAL_KEEP_PRIVILEGED=true
```

## Complete Example

```go
package main

import (
    "context"
    "fmt"
    "dagger.io/dagger"
    "github.com/your-org/your-project/cicd/privileged"
)

type Cicd struct{}

func (m *Cicd) Deploy(ctx context.Context, source *dagger.Directory) (string, error) {
    client, _ := dagger.Connect(ctx)
    defer client.Close()
    
    // 1. Provision infrastructure
    terraformOutput, err := privileged.TerraformApply(
        ctx, client,
        source.Directory("terraform"),
        source.Directory("terraform/vars"),
        true,
    )
    if err != nil {
        return "", err
    }
    
    // 2. Load kubeconfig
    kubeconfigSecret, err := privileged.LoadKubeconfig(ctx, client, "")
    if err != nil {
        return "", err
    }
    
    // 3. Apply Kubernetes manifests
    kubectlOutput, err := privileged.KubectlApply(
        ctx, client,
        source.Directory("k8s"),
        "production",
        kubeconfigSecret,
    )
    if err != nil {
        return "", err
    }
    
    // 4. Install Helm chart
    helmOutput, err := privileged.HelmInstall(
        ctx, client,
        "myapp",
        source.Directory("helm/myapp"),
        "production",
        nil, // no values file
        kubeconfigSecret,
    )
    if err != nil {
        return "", err
    }
    
    return "Deployment completed", nil
}
```

## Security Best Practices

1. **Never Commit Secrets** - Privileged directory automatically added to .gitignore
2. **Restrict File Permissions** - Use `chmod 600` for all secret files
3. **Use Environment Variables** - Prefer env vars for CI/CD pipelines
4. **Rotate Credentials** - Regularly rotate credentials and update secrets
5. **Minimal Privileges** - Grant only necessary permissions
6. **Audit Access** - Monitor and audit access to secrets

## Container Images

- **kubectl**: `bitnami/kubectl:latest`
- **helm**: `alpine/helm:latest`
- **terraform**: `hashicorp/terraform:latest`

## Debugging

Keep functions after execution:

```bash
export CICD_LOCAL_KEEP_PRIVILEGED=true
cicd-local deploy

# Inspect
ls -la cicd/privileged/
```

## Files

- `kubectl.go` - Kubernetes operations (KubectlApply, KubectlGet, KubectlPortForward)
- `helm.go` - Helm operations (HelmInstall, HelmUpgrade)
- `terraform.go` - Terraform operations (TerraformPlan, TerraformApply)
- `secrets.go` - Secret management (LoadKubeconfig, LoadSecretFile, etc.)
- `README.md` - This documentation
