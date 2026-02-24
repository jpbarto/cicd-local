# cicd-local

Local CI/CD pipeline toolkit for validating, building, testing, and deploying applications using Dagger.

## Overview

`cicd-local` provides a standardized set of pipeline scripts that work with Dagger CI/CD functions. It enables developers to:

- ✅ **Validate** Dagger functions against a standardized contract
- 🏗️ **Build** multi-architecture container images locally
- 🧪 **Test** applications with unit and integration tests
- 📦 **Deliver** artifacts to container and Helm repositories
- 🚀 **Deploy** to local or remote Kubernetes clusters
- 🔄 **Simulate** complete CI/CD pipelines before committing

## Quick Start

### Prerequisites

- [Dagger](https://dagger.io) - CI/CD pipeline engine
- [Docker](https://docker.com) or [Colima](https://github.com/abiosoft/colima) - Container runtime
- [kubectl](https://kubernetes.io/docs/tasks/tools/) - Kubernetes CLI
- Git - Version control

### Installation

```bash
# Clone repository
git clone https://github.com/your-org/cicd-local.git ~/cicd-local

# Add to PATH
echo 'export PATH="$HOME/cicd-local:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Verify installation
cicd-local --help
```

### Setup Kubernetes (Colima)

```bash
# Install Colima (macOS/Linux)
brew install colima

# Start local cluster
colima start acme-local --cpu 4 --memory 8 --disk 50 --kubernetes

# Verify cluster
kubectl get nodes
```

## Usage

### Initialize New Project

Quickly set up a new project with Dagger CI/CD:

```bash
# Navigate to your project
cd ~/dev/my-project

# Initialize with your preferred language
cicd-local init go
cicd-local init python my-app-name
cicd-local init java
cicd-local init typescript
```

This creates a `cicd/` directory with:
- Initialized Dagger module
- Example function implementations
- Ready-to-customize contract code

### Validate Contract

Ensure your Dagger functions conform to the cicd-local contract:

```bash
cicd-local validate
```

### Run CI Pipeline

Build and test your application:

```bash
# Commit pipeline (build + test)
cicd-local ci

# PR merge pipeline (build + test + deliver)
cicd-local ci --pipeline-trigger=pr-merge
```

### Deploy and Test

Deploy to local Kubernetes and run integration tests:

```bash
# Full integration testing
cicd-local iat

# Just deployment
cicd-local deploy
```

### Blue-Green Testing

Validate deployment rollback scenarios:

```bash
cicd-local staging
```

## Available Commands

| Command | Description |
|---------|-------------|
| `init` | Initialize Dagger CI/CD module in a project |
| `validate` | Validate Dagger functions against contract |
| `ci` | Build and test (optionally deliver artifacts) |
| `deliver` | Publish container images and Helm charts |
| `deploy` | Deploy to Kubernetes cluster |
| `iat` | Integration and acceptance testing |
| `staging` | Blue-green deployment testing |

Run any command with `--help` for detailed usage:

```bash
cicd-local ci --help
```

## Project Requirements

Your project must have:

1. **VERSION file** in root directory containing semantic version:
   ```
   1.2.3
   ```

2. **cicd/ directory** with Dagger module implementing six required functions:
   - `Build` - Build multi-architecture container images
   - `UnitTest` - Run unit tests
   - `IntegrationTest` - Run integration tests
   - `Deliver` - Publish artifacts to repositories
   - `Deploy` - Deploy to Kubernetes
   - `Validate` - Validate deployment health

3. **Contract compliance** - Verify with `cicd-local validate`

## Supported Languages

- **Go** (Golang)
- **Python**
- **Java**
- **TypeScript**

Example implementations provided in `cicd_dagger_contract/` directory.

## Common Workflows

### New Project Setup

```bash
# 1. Create or navigate to project
mkdir ~/dev/my-app && cd ~/dev/my-app

# 2. Initialize Dagger CI/CD module
cicd-local init python my-app

# 3. Customize the generated functions in cicd/
# 4. Validate implementation
cicd-local validate

# 5. Test the pipeline
cicd-local ci
```

### Local Development

```bash
# 1. Make code changes
# 2. Test locally
cicd-local ci

# 3. If tests pass, deliver artifacts
cicd-local ci --pipeline-trigger=pr-merge

# 4. Deploy and run integration tests
cicd-local iat

# 5. Validate blue-green deployment
cicd-local staging
```

### Quick Iteration

```bash
# Fast build and test cycle
cicd-local ci

# Skip tests for faster builds
cicd-local ci --skip-tests
```

### Custom Repositories

```bash
# Use your own registries
cicd-local ci --pipeline-trigger=pr-merge \
  --container-repository=ghcr.io/myorg \
  --helm-repository=oci://ghcr.io/myorg

cicd-local deploy \
  --container-repository=ghcr.io/myorg \
  --helm-repository=oci://ghcr.io/myorg
```

## Configuration

Create `local_cicd.env` in your project or export environment variables:

```bash
# Container and Helm repositories
CONTAINER_REPOSITORY_URL="ttl.sh"
HELM_REPOSITORY_URL="oci://ttl.sh"

# Kubernetes configuration
COLIMA_PROFILE="acme-local"
RELEASE_NAME="goserv"
NAMESPACE="goserv"
```

## Privileged Functions

`cicd-local` provides reusable privileged functions for infrastructure deployment operations. These functions are **automatically copied** to your project during initialization and available for use in your Dagger code.

### Available Functions

- **Kubernetes Operations** - Apply manifests, get resources, port forwarding with kubectl
- **Helm Operations** - Install and upgrade Helm releases
- **Terraform Operations** - Plan and apply infrastructure changes
- **Secret Management** - Load kubeconfig and secrets from secure storage

### Automatic Setup

Privileged functions are:
1. ✅ **Copied during init** - Available immediately in `cicd/privileged/` for development
2. 🔄 **Auto-injected at runtime** - Updated before pipeline execution if needed
3. 📦 **Ready to import** - No import errors in your IDE during development

### Usage in Your Code

Import and use privileged functions in your Dagger code:

```go
import "github.com/your-org/your-project/cicd/privileged"

func (m *Cicd) Deploy(ctx context.Context, source *dagger.Directory) (string, error) {
    client, _ := dagger.Connect(ctx)
    defer client.Close()
    
    // Load kubeconfig
    kubeconfig, _ := privileged.LoadKubeconfig(ctx, client, "")
    
    // Apply Kubernetes manifests
    output, err := privileged.KubectlApply(
        ctx, client, 
        source.Directory("k8s"),
        "production",
        kubeconfig,
    )
    return output, err
}
```

### Environment Variables

Configure operations using environment variables:

```bash
# Kubernetes/Helm operations
export KUBECONFIG="~/.kube/config"      # Path to kubeconfig
export KUBECTL_CONTEXT="prod-cluster"   # Kubernetes context
export HELM_TIMEOUT="10m"               # Helm operation timeout

# Terraform/AWS operations
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_REGION="us-east-1"
export TF_VAR_environment="production"  # Terraform variables

# Keep privileged functions for debugging (optional)
export CICD_LOCAL_KEEP_PRIVILEGED=true
```

### Secret Storage

Store sensitive values in `~/.cicd-local/secrets/`:

```bash
# Create secret file
mkdir -p ~/.cicd-local/secrets
echo "my-secret-value" > ~/.cicd-local/secrets/api-token
chmod 600 ~/.cicd-local/secrets/api-token

# Load in Dagger code
token, err := privileged.LoadSecretFile("api-token")
```

See `privileged/README.md` for complete documentation and examples.

## Pipeline Outputs

All pipeline executions generate outputs in the `output/` directory:

### Artifacts
- `output/build/buildArtifact` - Built container image (OCI tarball)
- `output/deliver/deliveryContext` - Published artifact metadata (from Deliver)
- `output/deploy/deploymentContext` - Deployment metadata (from Deploy)
- `output/validate/validationContext` - Validation results (from Validate)

### Stage Logs
Each Dagger function execution is logged:
- `output/build/pipeline_{pipeline}_build.log`
- `output/deliver/pipeline_{pipeline}_deliver.log`
- `output/deploy/pipeline_{pipeline}_deploy.log`
- `output/validate/pipeline_{pipeline}_validate.log`
- `output/validate/pipeline_iat_integration-test.log`

Log files capture complete console output including errors, making debugging easier.

## Documentation

- **[USER_GUIDE.md](docs/USER_GUIDE.md)** - Complete usage guide with all commands, options, and workflows
- **[CONTRACT_VALIDATION.md](docs/CONTRACT_VALIDATION.md)** - Detailed validation guide with examples for all languages
- **[CONTRACT_REFERENCE.md](docs/CONTRACT_REFERENCE.md)** - Complete contract specification and function signatures
- **[CONTEXT_FILES.md](docs/CONTEXT_FILES.md)** - Context files guide (deliveryContext, deploymentContext, validationContext)

## Example Implementations

Reference implementations for all supported languages:

```
cicd_dagger_contract/
├── golang/          # Go examples
├── python/          # Python examples
├── java/            # Java examples
└── typescript/      # TypeScript examples
```

Each directory contains complete examples for all six required functions.

## Troubleshooting

### Colima Not Running

```bash
colima list
colima start acme-local
```

### Validation Fails

```bash
# Review detailed errors
cicd-local validate

# Compare with examples
ls cicd_dagger_contract/golang/
```

### Port Conflicts

```bash
# Check port usage
lsof -i :8080

# Kill blocking process
kill <PID>
```

See [USER_GUIDE.md](docs/USER_GUIDE.md) for comprehensive troubleshooting.

## Architecture

```
cicd-local/
├── cicd-local                    # Main dispatcher
├── local_ci_pipeline.sh          # CI pipeline
├── local_deliver_pipeline.sh     # Artifact delivery
├── local_deploy_pipeline.sh      # Deployment
├── local_iat_pipeline.sh         # Integration testing
├── local_staging_pipeline.sh     # Blue-green testing
├── validate_contract.sh          # Contract validation
├── contract.json                 # Contract specification
├── docs/                         # Documentation
│   ├── USER_GUIDE.md
│   ├── CONTRACT_VALIDATION.md
│   ├── CONTRACT_REFERENCE.md
│   └── DEPLOYMENT_CONTEXT.md
└── cicd_dagger_contract/         # Example implementations
    ├── golang/
    ├── python/
    ├── java/
    └── typescript/
```

## Contributing

Contributions welcome! Please ensure:

1. Contract changes are backward compatible
2. All four language examples are updated
3. Documentation is updated
4. Tests pass with `cicd-local validate`

## License

[Add your license information here]

## Getting Started

1. **Install cicd-local**: Follow [installation](#installation) instructions
2. **Setup Kubernetes**: Configure [Colima](#setup-kubernetes-colima)
3. **Validate project**: Run `cicd-local validate`
4. **Read documentation**: Start with [USER_GUIDE.md](docs/USER_GUIDE.md)
5. **Run pipelines**: Try `cicd-local ci` and `cicd-local iat`

## Support

- **Documentation**: See `docs/` directory
- **Examples**: Browse `cicd_dagger_contract/` for your language
- **Issues**: Check validation output and troubleshooting guide
- **Debug**: Run with `dagger run --debug` for detailed logs

## Features

- ✅ Contract-based validation for consistency
- 🔧 Multi-language support (Go, Python, Java, TypeScript)
- 🏗️ Multi-architecture image builds
- 🧪 Integrated testing (unit, integration, acceptance)
- 📦 Artifact management (containers, Helm charts)
- 🚀 Kubernetes deployment with validation
- 🔄 Blue-green deployment testing
- 🔗 Deployment context for inter-function communication
- 📊 Detailed validation reporting
- 🎯 Local-first development workflow

---

**Ready to get started?** Read the [User Guide](docs/USER_GUIDE.md) for comprehensive documentation.
