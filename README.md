# CICD Local

A collection of shell scripts for running CI/CD pipelines locally using Dagger. This project enables developers to test and validate CI/CD workflows on their local machines before pushing to remote CI/CD systems.

## Overview

The `cicd-local` dispatcher script provides a unified interface for executing various pipeline stages locally:

- **CI Pipeline** - Build and test code changes
- **Deliver Pipeline** - Publish container images and Helm charts to repositories
- **Deploy Pipeline** - Deploy applications to Kubernetes clusters
- **IAT Pipeline** - Integration and Acceptance Testing with full deployment validation
- **Staging Pipeline** - Blue-green deployment testing and rollback validation

## Prerequisites

### Required Tools

- **Dagger CLI** - For executing pipeline functions
  ```bash
  # macOS
  brew install dagger/tap/dagger
  
  # Or use curl
  curl -L https://dl.dagger.io/dagger/install.sh | sh
  ```

- **Docker or Colima** - Container runtime (Colima recommended for local Kubernetes)
  ```bash
  brew install colima
  ```

- **kubectl** - Kubernetes command-line tool (for deploy/IAT/staging pipelines)
  ```bash
  brew install kubectl
  ```

### Optional Configuration

Create a `local_cicd.env` file in the cicd-local directory to set default environment variables:

```bash
# Container and Helm repository URLs
CONTAINER_REPOSITORY_URL=ttl.sh
HELM_REPOSITORY_URL=oci://ttl.sh

# Kubernetes configuration
COLIMA_PROFILE=acme-local
RELEASE_NAME=goserv
NAMESPACE=goserv
```

### For Kubernetes Pipelines (IAT, Deploy, Staging)

Create and start a Colima profile with Kubernetes:

```bash
colima start acme-local --cpu 4 --memory 8 --disk 50 --kubernetes
```

## Installation

1. Clone or download this repository to a location on your system:
   ```bash
   git clone <repository-url> ~/cicd-local
   ```

2. Make the cicd-local script executable:
   ```bash
   chmod +x ~/cicd-local/cicd-local
   ```

3. Add the cicd-local directory to your PATH:
   ```bash
   # Add to ~/.bashrc or ~/.zshrc
   export PATH="$HOME/cicd-local:$PATH"
   ```

4. Reload your shell configuration:
   ```bash
   source ~/.bashrc  # or ~/.zshrc
   ```

## Usage

### Basic Command Structure

```bash
cicd-local <command> [OPTIONS]
```

The `cicd-local` command should be run from your project's root directory. It will execute the specified command on your current project.

### Available Commands

#### Validate Contract

Validates that your project's Dagger functions conform to the cicd-local contract specification. This ensures your CI/CD functions are compatible with the cicd-local pipelines.

```bash
# Validate current directory
cicd-local validate

# Validate specific project
cicd-local validate /path/to/project

# Run from project directory
cd myproject && cicd-local validate
```

The validation checks:
- **Function Existence**: All required functions are present (Build, UnitTest, IntegrationTest, Deliver, Deploy, Validate)
- **Function Signatures**: Parameter names match the contract
- **Parameter Types**: Parameter types are correct for the detected language (Go, Python, Java, TypeScript)

**Supported Languages:**
- Go (Golang)
- Python
- Java
- TypeScript

**Exit Codes:**
- `0` - All validations passed
- `1` - Validation failures or errors

#### CI Pipeline

Builds container images and runs unit tests. Use this to validate code changes locally before committing.

```bash
# Basic commit pipeline (build + test)
cicd-local ci

# PR merge pipeline (build + test + deliver)
cicd-local ci --pipeline-trigger=pr-merge

# Skip tests during build
cicd-local ci --skip-tests

# Specify custom repositories
cicd-local ci --container-repository=myregistry.io --helm-repository=oci://myregistry.io
```

**Options:**
- `--pipeline-trigger <type>` - Pipeline trigger: `commit` (default) or `pr-merge`
- `--skip-tests` - Skip unit tests
- `--container-repository <url>` - Container repository URL (default: ttl.sh)
- `--helm-repository <url>` - Helm OCI repository URL (default: oci://ttl.sh)
- `--help, -h` - Show help message

#### Deliver Pipeline

Builds and publishes container images and Helm charts to repositories.

```bash
# Deliver artifacts
cicd-local deliver

# Deliver release candidate
cicd-local deliver --release-candidate

# Skip build and use existing tarball
cicd-local deliver --skip-build

# Custom repositories
cicd-local deliver --container-repository=myregistry.io --helm-repository=oci://myregistry.io
```

**Options:**
- `--release-candidate, -rc` - Build as release candidate (appends -rc to version)
- `--container-repository <url>` - Container repository URL (default: ttl.sh)
- `--helm-repository <url>` - Helm OCI repository URL (default: oci://ttl.sh)
- `--skip-build` - Skip build step (use existing tarball)
- `--help, -h` - Show help message

#### Deploy Pipeline

Deploys the application to a Kubernetes cluster and validates the deployment.

```bash
# Deploy application
cicd-local deploy

# Deploy release candidate
cicd-local deploy --release-candidate

# Deploy to custom namespace
cicd-local deploy --namespace=staging --release-name=myapp

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
- `--help, -h` - Show help message

#### IAT (Integration and Acceptance Testing) Pipeline

Ensures local Kubernetes environment is running, deploys the application, and executes integration tests.

```bash
# Full IAT pipeline
cicd-local iat

# Skip deployment (use existing deployment)
cicd-local iat --skip-deploy
```

**Options:**
- `--skip-deploy` - Skip deployment step (use existing deployment)
- `--help, -h` - Show help message

**Note:** IAT pipeline always uses release candidate (-rc) builds.

#### Staging Pipeline

Performs blue-green deployment testing by deploying current version, previous version, and current version again. Validates rollback scenarios.

```bash
# Run staging validation
cicd-local staging
```

**Options:**
- `--help, -h` - Show help message

**Note:** Staging pipeline always uses release candidate (-rc) builds and requires at least one git tag in the repository.

## Common Workflows

### Local Development Workflow

```bash
# 1. Make code changes
# 2. Test locally
cicd-local ci

# 3. If tests pass, deliver artifacts
cicd-local ci --pipeline-trigger=pr-merge

# 4. Deploy and test integration
cicd-local iat

# 5. Validate blue-green deployment
cicd-local staging
```

### Quick Build and Test

```bash
# Build and test current changes
cicd-local ci
```

### Full Pipeline Simulation

```bash
# Run complete CI/CD pipeline
cicd-local ci --pipeline-trigger=pr-merge
cicd-local iat
cicd-local staging
```

## Project Structure

```
cicd-local/
├── cicd-local                    # Main dispatcher script
├── local_ci_pipeline.sh          # CI pipeline (build + test)
├── local_deliver_pipeline.sh     # Artifact delivery pipeline
├── local_deploy_pipeline.sh      # Deployment pipeline
├── local_iat_pipeline.sh         # Integration testing pipeline
├── local_staging_pipeline.sh     # Staging/rollback testing pipeline
├── local_cicd.env                # Environment configuration (optional)
└── README.md                     # This file
```

## Environment Variables

The following environment variables can be set in `local_cicd.env` or exported in your shell:

- `CONTAINER_REPOSITORY_URL` - Default container repository (default: ttl.sh)
- `HELM_REPOSITORY_URL` - Default Helm repository (default: oci://ttl.sh)
- `COLIMA_PROFILE` - Colima profile name (default: acme-local)
- `RELEASE_NAME` - Kubernetes release name (default: goserv)
- `NAMESPACE` - Kubernetes namespace (default: goserv)

## Troubleshooting

### Colima Not Running

If you see errors about Colima not running:

```bash
# Check Colima status
colima list

# Start Colima profile
colima start acme-local
```

### Kubectl Context Issues

If kubectl cannot connect to the cluster:

```bash
# List available contexts
kubectl config get-contexts

# Switch to correct context
kubectl config use-context colima-acme-local
```

### Build Artifacts Not Found

If delivery pipeline cannot find build artifacts:

```bash
# Run CI pipeline first to build artifacts
cicd-local ci --pipeline-trigger=pr-merge
```

### Port Forward Fails

If IAT pipeline fails to establish port forward:

```bash
# Check if port is already in use
lsof -i :8080

# Kill process using the port
kill <PID>
```

## Requirements

- Your project must have a `VERSION` file in the root directory
- Your project must have Dagger modules in a `cicd` directory
- Dagger modules must implement the expected functions (build, unit-test, deliver, deploy, validate, integration-test)

## Dagger Contract Validation

To ensure your project's Dagger functions are compatible with cicd-local pipelines, use the contract validation tool:

```bash
cicd-local validate
```

The validator checks that your Dagger functions conform to the standardized contract for:
- Function names and signatures
- Parameter names and types
- Return types

Supported languages: Go, Python, Java, TypeScript

For detailed information about contract validation, see [VALIDATION.md](VALIDATION.md).

For the complete contract specification and example implementations, see [cicd_dagger_contract/README.md](cicd_dagger_contract/README.md).

## Additional Resources

- **[VALIDATION.md](VALIDATION.md)** - Detailed guide for contract validation
- **[cicd_dagger_contract/README.md](cicd_dagger_contract/README.md)** - Complete contract specification
- **[cicd_dagger_contract/golang/](cicd_dagger_contract/golang/)** - Go implementation examples
- **[cicd_dagger_contract/python/](cicd_dagger_contract/python/)** - Python implementation examples
- **[cicd_dagger_contract/java/](cicd_dagger_contract/java/)** - Java implementation examples
- **[cicd_dagger_contract/typescript/](cicd_dagger_contract/typescript/)** - TypeScript implementation examples

## License

[Add your license information here]

## Contributing

[Add contribution guidelines here]
