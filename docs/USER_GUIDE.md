# cicd-local User Guide

Complete guide for using cicd-local pipelines to build, test, and deploy your applications locally.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Getting Started](#getting-started)
- [Pipeline Commands](#pipeline-commands)
  - [init](#init---initialize-project)
  - [validate](#validate---contract-validation)
  - [ci](#ci---continuous-integration)
  - [deliver](#deliver---artifact-publishing)
  - [deploy](#deploy---deployment)
  - [iat](#iat---integration-testing)
  - [staging](#staging---blue-green-testing)
- [Common Workflows](#common-workflows)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)

## Prerequisites

Before using cicd-local, ensure you have:

- **Dagger**: Install from [dagger.io](https://dagger.io)
- **Docker or Colima**: Container runtime
  - Docker Desktop: [docker.com](https://docker.com)
  - Colima: `brew install colima` (macOS, Linux-friendly alternative)
- **kubectl**: Kubernetes CLI (`brew install kubectl`)
- **Git**: For version control operations

### Setting up Colima (Recommended for macOS/Linux)

```bash
# Install Colima
brew install colima

# Create a profile for local testing
colima start acme-local --cpu 4 --memory 8 --disk 50 --kubernetes

# Verify kubectl context
kubectl config current-context  # Should show: colima-acme-local
```

## Installation

### Option 1: Add to PATH (Recommended)

```bash
# Clone the repository
git clone https://github.com/your-org/cicd-local.git ~/cicd-local

# Add to PATH in your shell profile (~/.zshrc or ~/.bashrc)
echo 'export PATH="$HOME/cicd-local:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Verify installation
cicd-local --help
```

### Option 2: Symlink to ~/bin

```bash
# Clone the repository
git clone https://github.com/your-org/cicd-local.git ~/projects/cicd-local

# Create symlink
ln -s ~/projects/cicd-local/cicd-local ~/bin/cicd-local

# Verify installation
cicd-local --help
```

## Getting Started

The fastest way to get started with cicd-local is using the `init` command to scaffold a new Dagger module:

```bash
# Navigate to your project directory
cd ~/dev/my-project

# Initialize Dagger CI/CD module (automatically uses project directory name)
cicd-local init python

# Or specify a custom module name
cicd-local init go my-custom-name
```

This creates:
- `cicd/` directory with Dagger module
- Example implementations customized for your project name
- Privileged functions with placeholder secrets in `cicd/privileged/`
- `VERSION` file (if not present)
- Language-specific boilerplate

**Note**: The example files are automatically customized by replacing legacy "Goserv" references with your actual project name. For example, if your project is named "MyApp", class names become `MyApp`, import paths become `dagger/myapp/internal/dagger`, and service endpoints become `myapp.default.svc.cluster.local`.

After initialization, customize the generated functions to match your project's needs.

## Pipeline Commands

### init - Initialize Project

Initializes a Dagger CI/CD module in your project with example implementations.

**Usage:**
```bash
# Initialize with language (uses project directory name as module name)
cicd-local init <language>

# Initialize with custom module name
cicd-local init <language> <name>

# Examples
cicd-local init go
cicd-local init python my-app
cicd-local init java my-service
cicd-local init typescript
```

**Supported Languages:**
- `go` or `golang` - Go/Golang
- `python` or `py` - Python
- `java` - Java
- `typescript` or `ts` - TypeScript

**What it does:**
1. Creates `cicd/` directory in current project
2. Runs `dagger init --sdk=<language> --name=<name>`
3. Copies example implementations from `cicd_dagger_contract/<language>/`
4. **Replaces "Goserv" references** with your project name in all example files:
   - Class/type names: `Goserv` → `YourProjectName`
   - Import paths: `dagger/goserv/` → `dagger/yourprojectname/`
   - Service endpoints: `goserv.default.svc` → `yourprojectname.default.svc`
   - Release names: `"goserv"` → `"yourprojectname"`
5. Strips `.example` suffix from copied files
6. Copies privileged functions with placeholder secrets to `cicd/privileged/`
7. Creates `VERSION` file with `0.1.0` if not present
8. Preserves any existing generated Dagger files

**Safety features:**
- Backs up existing `cicd/` directory before reinitializing
- Prompts for confirmation before overwriting
- Skips copying files that already exist
- Checks for Dagger CLI installation

**Next steps after init:**
```bash
# 1. Review generated code
ls -la cicd/

# 2. Customize the functions
# Edit the files in cicd/ to match your project

# 3. Validate your implementation
cicd-local validate

# 4. Test locally
cicd-local ci
```

### validate - Contract Validation

Validates that your Dagger functions conform to the cicd-local contract.

**Usage:**
```bash
# Validate current directory
cicd-local validate

# Validate specific project
cicd-local validate /path/to/project
```

**What it checks:**
- Function existence (Build, UnitTest, IntegrationTest, Deliver, Deploy, Validate)
- Function signatures (parameter names and types)
- Language detection (Go, Python, Java, TypeScript)

**Exit codes:**
- `0` - All validations passed
- `1` - Validation failures

See [CONTRACT_VALIDATION.md](CONTRACT_VALIDATION.md) for detailed validation guide.

### ci - Continuous Integration

Builds container images and runs unit tests.

**Usage:**
```bash
# Basic commit pipeline (build + test)
cicd-local ci

# PR merge pipeline (build + test + deliver)
cicd-local ci --pipeline-trigger=pr-merge

# Skip unit tests
cicd-local ci --skip-tests

```

**Options:**
- `--pipeline-trigger <type>` - Pipeline trigger: `commit` (default) or `pr-merge`
- `--skip-tests` - Skip unit tests
- `--help, -h` - Show help message

**Pipeline flow:**
- **Commit**: `Build → UnitTest`
- **PR merge**: `Build → UnitTest → Deliver`

**Outputs:**
- Build artifact: `./output/build/buildArtifact`
- Delivery context: `./output/deliver/deliveryContext` (pr-merge only)
- Stage logs: `./output/build/pipeline_ci_*.log`, `./output/deliver/pipeline_ci_deliver.log`

### deliver - Artifact Publishing

Publishes container images and Helm charts to repositories.

**Usage:**
```bash
# Build and deliver
cicd-local deliver

# Deliver release candidate
cicd-local deliver --release-candidate

# Skip build (use existing tarball)
cicd-local deliver --skip-build

```

**Options:**
- `--release-candidate, -rc` - Build as release candidate (appends -rc to version)
- `--skip-build` - Skip build step (use existing tarball)
- `--help, -h` - Show help message

**Pipeline flow:** `Build → Deliver`

**Outputs:**
- Build artifact: `./output/build/buildArtifact`
- Delivery context: `./output/deliver/deliveryContext`
- Stage logs: `./output/build/pipeline_deliver_build.log`, `./output/deliver/pipeline_deliver_deliver.log`

**Published artifacts:**
- Multi-architecture container images
- Helm charts (OCI format)

### deploy - Deployment

Deploys application to Kubernetes cluster and validates deployment.

**Usage:**
```bash
# Deploy application
cicd-local deploy

# Deploy release candidate
cicd-local deploy --release-candidate

# Custom namespace and release name
cicd-local deploy \
  --namespace=staging \
  --release-name=myapp-staging

# Skip validation
cicd-local deploy --skip-validation

# Use different Colima profile
cicd-local deploy --colima-profile=my-cluster
```

**Options:**
- `--release-candidate, -rc` - Deploy release candidate version
- `--release-name <name>` - Helm release name (default: goserv)
- `--namespace <name>` - Kubernetes namespace (default: goserv)
- `--colima-profile <name>` - Colima profile to use (default: acme-local)
- `--skip-validation` - Skip validation step after deployment
- `--container-repository <url>` - Container repository URL (default: ttl.sh)
- `--helm-repository <url>` - Helm repository URL (default: oci://ttl.sh)
- `--help, -h` - Show help message

**Pipeline flow:** `Deploy → Validate`

**Deployment context:**
- Deploy function exports metadata to `./output/deploy/context.json`
- Contains endpoint URL, namespace, release name, version
- Passed to Validate function automatically

See [CONTEXT_FILES.md](CONTEXT_FILES.md) for advanced usage.

### iat - Integration Testing

Full integration and acceptance testing pipeline with deployment.

**Usage:**
```bash
# Full IAT pipeline
cicd-local iat

# Skip deployment (use existing)
cicd-local iat --skip-deploy
```

**Options:**
- `--skip-deploy` - Skip deployment step (use existing deployment)
- `--help, -h` - Show help message

**Pipeline flow:** `Deploy → Validate → IntegrationTest`

**Key features:**
- Always uses release candidate builds
- Automatically sets up kubectl port-forward
- Tests against `host.docker.internal` for container-to-local communication

### staging - Blue-Green Testing

Validates blue-green deployment scenarios and rollback capabilities.

**Usage:**
```bash
# Run staging validation
cicd-local staging
```

**Options:**
- `--help, -h` - Show help message

**Pipeline flow (3 phases):**
1. **Phase 1 (Green)**: Deploy current-rc → Validate
2. **Phase 2 (Blue)**: Deploy previous-release → Validate (rollback test)
3. **Phase 3 (Green)**: Deploy current-rc → Validate (re-deployment test)

**Requirements:**
- At least one git tag in repository (for previous version)
- Clean git working directory

## Common Workflows

### Local Development Workflow

Complete development cycle with local testing:

```bash
# 1. Make code changes in your project

# 2. Test changes locally
cicd-local ci

# 3. If tests pass, deliver artifacts
cicd-local ci --pipeline-trigger=pr-merge

# 4. Deploy and run integration tests
cicd-local iat

# 5. Validate blue-green deployment
cicd-local staging
```

### Quick Build and Test

Rapid iteration during development:

```bash
# Build and test current changes
cicd-local ci

# Or skip tests for faster builds
cicd-local ci --skip-tests
```

### Full Pipeline Simulation

Simulate complete CI/CD pipeline:

```bash
# Complete pipeline
cicd-local ci --pipeline-trigger=pr-merge
cicd-local iat
cicd-local staging
```

### Custom Repository Testing

Test with your own registries:

```bash
# Set repositories
export CONTAINER_REPO="ghcr.io/myorg"
export HELM_REPO="oci://ghcr.io/myorg"

# Run pipelines
cicd-local ci --pipeline-trigger=pr-merge

cicd-local deploy \
  --container-repository=$CONTAINER_REPO \
  --helm-repository=$HELM_REPO
```

## Configuration

### Environment Variables

Create `local_cicd.env` in your project or export in shell:

```bash
# Container and Helm repositories
CONTAINER_REPOSITORY_URL="ttl.sh"
HELM_REPOSITORY_URL="oci://ttl.sh"

# Kubernetes configuration
COLIMA_PROFILE="acme-local"
RELEASE_NAME="goserv"
NAMESPACE="goserv"

# Privileged functions (optional)
CICD_LOCAL_KEEP_PRIVILEGED=false  # Set to true to keep privileged functions after pipeline execution
```

### Authentication and Secrets

#### Container Registry Credentials

For authenticated registry access, set environment variables:

```bash
export CONTAINER_REGISTRY="ghcr.io"
export CONTAINER_REGISTRY_USER="username"
export CONTAINER_REGISTRY_PASSWORD="ghp_your_token"
```

#### AWS Credentials

For AWS operations:

```bash
export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
export AWS_SESSION_TOKEN="..."  # Optional
```

#### Secret Files

Store sensitive values in `~/.cicd-local/secrets/`:

```bash
mkdir -p ~/.cicd-local/secrets
echo "my-secret-value" > ~/.cicd-local/secrets/api-token
chmod 600 ~/.cicd-local/secrets/api-token
```

### Privileged Functions

`cicd-local` provides privileged functions for infrastructure deployment operations. These are reusable functions for Kubernetes, Helm, Terraform, and secret management that use **runtime secret injection** for security.

#### Security Model

Privileged functions use a template-and-inject pattern:

1. **Development Time**: `cicd-local init` copies functions with placeholder secrets (`__INJECTED_KUBECONFIG__`)
2. **Runtime**: Before `dagger call`, credentials are injected from your environment:
   - Kubeconfig from `~/.kube/config` or `$KUBECONFIG`
   - Context from `$KUBECTL_CONTEXT`
   - Helm timeout from `$HELM_TIMEOUT`
3. **Execution**: User-defined Dagger code calls privileged functions (which have injected secrets)
4. **Cleanup**: Privileged functions optionally removed after execution

This ensures:
- ✅ IDE has valid Go code during development (no import errors)
- ✅ Secrets never stored in project repositories
- ✅ User-defined Dagger code cannot access secrets directly
- ✅ Credentials only exist during pipeline execution

#### Using Privileged Functions

Import in your Dagger code:

```go
import "github.com/your-org/your-project/cicd/privileged"

func (m *Cicd) Deploy(ctx context.Context, source *dagger.Directory) (string, error) {
    client, err := dagger.Connect(ctx)
    if err != nil {
        return "", err
    }
    defer client.Close()
    
    // Load injected kubeconfig (no path needed)
    kubeconfig, err := privileged.LoadKubeconfig(ctx, client)
    if err != nil {
        return "", err
    }
    
    // Apply Kubernetes manifests
    output, err := privileged.KubectlApply(
        ctx, client,
        source.Directory("k8s"),
        "production",
        kubeconfig,
    )
    if err != nil {
        return "", fmt.Errorf("kubectl apply failed: %w", err)
    }
    
    return output, nil
}
```

#### Available Functions

**Kubernetes Operations:**
- `KubectlApply(ctx, client, manifestsDir, namespace, kubeconfig)` - Apply manifests
- `KubectlGet(ctx, client, namespace, resourceName, kubeconfig)` - Get resource as JSON
- `KubectlPortForward(ctx, client, namespace, resourceName, ports, kubeconfig)` - Port forward service

**Helm Operations:**
- `HelmInstall(ctx, client, releaseName, chartPath, namespace, valuesFile, kubeconfig)` - Install/upgrade chart
- `HelmUpgrade(ctx, client, releaseName, chartReference, namespace, kubeconfig)` - Upgrade release

**Terraform Operations:**
- `TerraformPlan(ctx, client, terraformDir, varFile)` - Run terraform plan
- `TerraformApply(ctx, client, terraformDir, varFile, autoApprove)` - Apply infrastructure

**Secret Management:**
- `LoadKubeconfig(ctx, client)` - Load injected kubeconfig as Dagger secret
- `GetKubectlContext()` - Get injected kubectl context
- `GetHelmTimeout()` - Get injected helm timeout
- `LoadSecretFile(name)` - Load secret from `~/.cicd-local/secrets/{name}`
- `LoadSecretAsDaggerSecret(client, name)` - Load secret as Dagger secret
- `GetEnvOrSecret(envVar, secretName)` - Try env var first, fallback to secret file

#### Debugging Privileged Functions

To inspect or debug privileged functions:

```bash
# Keep functions after pipeline execution
export CICD_LOCAL_KEEP_PRIVILEGED=true

# Run pipeline
cicd-local ci

# Functions remain in project/cicd/privileged/ for inspection
```

See `privileged/README.md` in the cicd-local installation directory for complete documentation.

### Project Requirements

Your project must have:

1. **VERSION file** in root directory:
   ```
   1.2.3
   ```

2. **cicd/ directory** with Dagger modules implementing required functions:
   - Build
   - UnitTest
   - IntegrationTest
   - Deliver
   - Deploy
   - Validate

3. **Conform to contract**: Run `cicd-local validate` to check compliance

See [CONTRACT_REFERENCE.md](CONTRACT_REFERENCE.md) for complete contract specification.

## Pipeline Outputs

All pipeline executions create organized outputs in your project's `output/` directory:

### Directory Structure

```
output/
├── build/
│   ├── buildArtifact                      # Built container image (OCI tarball)
│   ├── pipeline_ci_build.log              # CI pipeline build logs
│   ├── pipeline_ci_unit-test.log          # CI pipeline test logs
│   └── pipeline_deliver_build.log         # Deliver pipeline build logs
├── deliver/
│   ├── deliveryContext                    # Published artifact metadata
│   ├── pipeline_ci_deliver.log            # CI pipeline deliver logs
│   └── pipeline_deliver_deliver.log       # Deliver pipeline logs
├── deploy/
│   ├── deploymentContext                  # Deployment metadata
│   ├── pipeline_deploy_deploy.log         # Deploy pipeline logs
│   ├── pipeline_iat_deploy.log            # IAT pipeline deploy logs
│   └── pipeline_staging_deploy.log        # Staging pipeline deploy logs
└── validate/
    ├── validationContext                  # Validation results
    ├── pipeline_deploy_validate.log       # Deploy pipeline validation logs
    ├── pipeline_iat_validate.log          # IAT pipeline validation logs
    ├── pipeline_iat_integration-test.log  # Integration test logs
    └── pipeline_staging_validate.log      # Staging pipeline validation logs
```

### Artifacts

**Context Files** - JSON files containing metadata passed between pipeline stages:
- `deliveryContext` - Published artifact references, versions, repository URLs
- `deploymentContext` - Deployment endpoint, release name, namespace, versions
- `validationContext` - Health check results, validation status

See [CONTEXT_FILES.md](CONTEXT_FILES.md) for detailed format specifications.

**Build Artifacts:**
- `buildArtifact` - Multi-architecture container image in OCI tarball format

### Stage Logs

Every Dagger function execution captures complete console output to stage-specific log files:

**Log File Naming:** `pipeline_{pipeline-name}_{stage-name}.log`

**Examples:**
- `pipeline_ci_build.log` - Build stage from CI pipeline
- `pipeline_iat_validate.log` - Validate stage from IAT pipeline
- `pipeline_staging_deploy.log` - Deploy stage from Staging pipeline

**What's Logged:**
- Complete stdout and stderr from Dagger execution
- Build output, test results, deployment progress
- Error messages and stack traces
- Timestamps and execution details

**Benefits:**
- Debug failures without re-running pipelines
- Compare outputs across pipeline runs
- Share logs with team members
- Audit pipeline execution history

**Tip:** Use `tail -f output/build/pipeline_ci_build.log` to monitor pipeline execution in real-time from another terminal.

## Troubleshooting

### Colima Not Running

**Error:** Pipeline fails with Colima connection errors

**Solution:**
```bash
# Check Colima status
colima list

# Start Colima profile
colima start acme-local

# Verify Kubernetes is running
kubectl get nodes
```

### Kubectl Context Issues

**Error:** Cannot connect to Kubernetes cluster

**Solution:**
```bash
# List available contexts
kubectl config get-contexts

# Switch to correct context
kubectl config use-context colima-acme-local

# Verify connection
kubectl get pods
```

### Build Artifacts Not Found

**Error:** Delivery pipeline cannot find `./build/<app>-image.tar`

**Solution:**
```bash
# Run CI pipeline first to build artifacts
cicd-local ci --pipeline-trigger=pr-merge

# Then run deliver
cicd-local deliver --skip-build
```

### Port Forward Fails

**Error:** IAT pipeline fails to establish port forward

**Solution:**
```bash
# Check if port is already in use
lsof -i :8080

# Kill process using the port
kill <PID>

# Or use a different port (modify integration test configuration)
```

### Validation Fails

**Error:** `cicd-local validate` reports contract violations

**Solution:**
1. Review validation output for specific errors
2. Check [CONTRACT_VALIDATION.md](CONTRACT_VALIDATION.md) for examples
3. Compare with reference implementations in `cicd_dagger_contract/`
4. Fix function signatures to match contract
5. Re-run validation

### Dagger Cache Issues

**Error:** Stale cached results or unexpected behavior

**Solution:**
```bash
# Clear Dagger cache
dagger run --cleanup

# Or reset completely
rm -rf ~/.dagger
```

### Git Tag Required for Staging

**Error:** Staging pipeline fails with "no tags found"

**Solution:**
```bash
# Create an initial tag
git tag -a v0.1.0 -m "Initial version"

# Run staging again
cicd-local staging
```

## Next Steps

- **[CONTRACT_VALIDATION.md](CONTRACT_VALIDATION.md)** - Learn about contract validation
- **[CONTRACT_REFERENCE.md](CONTRACT_REFERENCE.md)** - Complete contract specification
- **[CONTEXT_FILES.md](CONTEXT_FILES.md)** - Context files for inter-function communication
- **Example implementations** in `cicd_dagger_contract/` directory

## Getting Help

1. Check this guide for common issues
2. Review contract validation output
3. Compare with example implementations
4. Check Dagger logs: `dagger run --debug`

## Project Structure

```
cicd-local/
├── cicd-local                    # Main dispatcher script
├── local_ci_pipeline.sh          # CI pipeline
├── local_deliver_pipeline.sh     # Artifact delivery
├── local_deploy_pipeline.sh      # Deployment
├── local_iat_pipeline.sh         # Integration testing
├── local_staging_pipeline.sh     # Blue-green testing
├── local_cicd.env                # Environment config (optional)
├── docs/
│   ├── USER_GUIDE.md            # This file
│   ├── CONTRACT_VALIDATION.md   # Validation guide
│   ├── CONTRACT_REFERENCE.md    # Contract specification
│   └── CONTEXT_FILES.md         # Context files guide
└── cicd_dagger_contract/         # Example implementations
    ├── golang/
    ├── python/
    ├── java/
    └── typescript/
```
