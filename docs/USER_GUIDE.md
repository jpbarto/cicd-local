# cicd-local User Guide

Complete guide for using cicd-local pipelines to build, test, and deploy your applications locally.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Pipeline Commands](#pipeline-commands)
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

## Pipeline Commands

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

# Custom repositories
cicd-local ci \
  --container-repository=ghcr.io/myorg \
  --helm-repository=oci://ghcr.io/myorg
```

**Options:**
- `--pipeline-trigger <type>` - Pipeline trigger: `commit` (default) or `pr-merge`
- `--skip-tests` - Skip unit tests
- `--container-repository <url>` - Container repository URL (default: ttl.sh)
- `--helm-repository <url>` - Helm OCI repository URL (default: oci://ttl.sh)
- `--help, -h` - Show help message

**Pipeline flow:**
- **Commit**: `Build → UnitTest`
- **PR merge**: `Build → UnitTest → Deliver`

**Artifacts:**
- Container image OCI tarball: `./build/<appname>-image.tar`

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

# Custom repositories
cicd-local deliver \
  --container-repository=ghcr.io/myorg \
  --helm-repository=oci://ghcr.io/myorg
```

**Options:**
- `--release-candidate, -rc` - Build as release candidate (appends -rc to version)
- `--container-repository <url>` - Container repository URL (default: ttl.sh)
- `--helm-repository <url>` - Helm OCI repository URL (default: oci://ttl.sh)
- `--skip-build` - Skip build step (use existing tarball)
- `--help, -h` - Show help message

**Pipeline flow:** `Build → Deliver`

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
cicd-local ci --pipeline-trigger=pr-merge \
  --container-repository=$CONTAINER_REPO \
  --helm-repository=$HELM_REPO

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
```

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
