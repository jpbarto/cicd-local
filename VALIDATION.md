# Contract Validation Guide

The cicd-local validation tool ensures that your project's Dagger functions conform to the standardized contract, enabling seamless integration with cicd-local pipelines.

## Quick Start

```bash
# Navigate to your project
cd /path/to/your/project

# Validate your Dagger functions
cicd-local validate
```

## What Gets Validated

The validator checks your project's `cicd/` directory for six required functions:

1. **Build** - Builds multi-architecture Docker images
2. **UnitTest** - Runs unit tests against built containers
3. **IntegrationTest** - Runs integration tests against deployed applications
4. **Deliver** - Publishes containers and Helm charts to repositories
5. **Deploy** - Deploys applications to Kubernetes clusters
6. **Validate** - Validates deployment health and correctness

For each function, the validator verifies:
- ✅ Function exists in your code
- ✅ Parameter names match the contract
- ✅ Parameter types match the contract

## Supported Languages

The validator automatically detects your Dagger module language and applies the appropriate contract:

### Go (Golang)
- **Detection**: `main.go` or `dagger.gen.go` files
- **Contract**: See `cicd_dagger_contract/golang/`
- **Naming**: PascalCase (e.g., `Build`, `UnitTest`)

### Python
- **Detection**: `pyproject.toml` or `src/__init__.py` files
- **Contract**: See `cicd_dagger_contract/python/`
- **Naming**: snake_case (e.g., `build`, `unit_test`)

### Java
- **Detection**: `pom.xml` or `build.gradle` files
- **Contract**: See `cicd_dagger_contract/java/`
- **Naming**: camelCase (e.g., `build`, `unitTest`)

### TypeScript
- **Detection**: `package.json` or `tsconfig.json` files
- **Contract**: See `cicd_dagger_contract/typescript/`
- **Naming**: camelCase (e.g., `build`, `unitTest`)

## Contract Requirements

### Required Functions and Signatures

#### 1. Build
**Purpose**: Build multi-architecture Docker images

**Go**:
```go
func (m *YourModule) Build(
    ctx context.Context,
    source *dagger.Directory,
    releaseCandidate bool,
) (*dagger.File, error)
```

**Python**:
```python
@function
async def build(
    self,
    source: dagger.Directory,
    release_candidate: bool = False,
) -> dagger.File:
```

**Java**:
```java
public File build(
    Directory source,
    boolean releaseCandidate
) throws Exception
```

**TypeScript**:
```typescript
@func()
async build(
    source: Directory,
    releaseCandidate: boolean = false
): Promise<File>
```

#### 2. UnitTest
**Purpose**: Run unit tests

**Parameters** (language-specific naming):
- `source`: Source directory
- `buildArtifact` / `build_artifact`: Optional pre-built image

#### 3. IntegrationTest
**Purpose**: Run integration tests against deployed instance

**Parameters**:
- `source`: Source directory
- `targetHost` / `target_host`: Host where app is deployed
- `targetPort` / `target_port`: Port where app is listening

#### 4. Deliver
**Purpose**: Publish containers and Helm charts

**Parameters**:
- `source`: Source directory
- `containerRepository` / `container_repository`: Container registry URL
- `helmRepository` / `helm_repository`: Helm chart repository URL
- `buildArtifact` / `build_artifact`: Optional pre-built image
- `releaseCandidate` / `release_candidate`: Release candidate flag

#### 5. Deploy
**Purpose**: Deploy to Kubernetes

**Parameters**:
- `source`: Source directory
- `kubeconfig`: Kubernetes config secret
- `helmRepository` / `helm_repository`: Helm chart repository
- `releaseName` / `release_name`: Helm release name
- `namespace`: Kubernetes namespace
- `releaseCandidate` / `release_candidate`: Release candidate flag

#### 6. Validate
**Purpose**: Validate deployment health

**Parameters**:
- `source`: Source directory
- `kubeconfig`: Kubernetes config secret
- `releaseName` / `release_name`: Helm release name
- `namespace`: Kubernetes namespace
- `expectedVersion` / `expected_version`: Expected version
- `releaseCandidate` / `release_candidate`: Release candidate flag

## Validation Output

### Success Example
```
✓ CICD directory found
✓ Detected language: golang
✓ Function 'Build' signature matches contract
✓ Function 'UnitTest' signature matches contract
✓ Function 'IntegrationTest' signature matches contract
✓ Function 'Deliver' signature matches contract
✓ Function 'Deploy' signature matches contract
✓ Function 'Validate' signature matches contract

Total Checks:  6
Passed:        6
Failed:        0

✓ All function signatures conform to the cicd-local contract!
```

### Failure Example
```
✓ CICD directory found
✓ Detected language: python
✓ Function 'build' signature matches contract
✗ Function 'unit_test' not found in Python files
✗   Parameter 'source' with type 'dagger.Directory' not found or incorrect in deliver
✓ Function 'integration_test' signature matches contract
✓ Function 'deploy' signature matches contract
✓ Function 'validate' signature matches contract

Total Checks:  6
Passed:        4
Failed:        2

✗ Some function signatures do not conform to the contract
```

## Common Issues and Solutions

### Issue: Function not found
**Error**: `Function 'Build' not found in Go files`

**Solution**: Ensure the function is defined with the exact name (case-sensitive):
- Go: `Build` (PascalCase)
- Python: `build` (snake_case)
- Java: `build` (camelCase)
- TypeScript: `build` (camelCase)

### Issue: Parameter type mismatch
**Error**: `Parameter 'source' with type 'dagger.Directory' not found or incorrect`

**Solution**: Check that:
1. Parameter name matches exactly (including case)
2. Type annotation is correct for your language
3. Import statements include necessary Dagger types

### Issue: Language not detected
**Error**: `Unable to detect Dagger module language`

**Solution**: Ensure your `cicd/` directory contains language-specific files:
- Go: `main.go` or `dagger.gen.go`
- Python: `pyproject.toml` or `src/__init__.py`
- Java: `pom.xml` or `build.gradle`
- TypeScript: `package.json` or `tsconfig.json`

## Integration with CI/CD

### Pre-commit Hook
Add validation to your pre-commit hooks:

```bash
#!/bin/bash
# .git/hooks/pre-commit

if ! cicd-local validate; then
    echo "❌ Dagger contract validation failed"
    echo "Fix the errors above before committing"
    exit 1
fi
```

### GitHub Actions
```yaml
name: Validate Dagger Contract
on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install cicd-local
        run: |
          git clone https://github.com/your-org/cicd-local.git ~/cicd-local
          echo "$HOME/cicd-local" >> $GITHUB_PATH
      
      - name: Validate contract
        run: cicd-local validate
```

### GitLab CI
```yaml
validate:contract:
  stage: validate
  script:
    - git clone https://gitlab.com/your-org/cicd-local.git ~/cicd-local
    - export PATH="$HOME/cicd-local:$PATH"
    - cicd-local validate
```

## Reference Implementations

Browse the example implementations in `cicd_dagger_contract/` for your language:

```bash
# View Go examples
ls cicd_dagger_contract/golang/

# View Python examples
ls cicd_dagger_contract/python/

# View Java examples
ls cicd_dagger_contract/java/

# View TypeScript examples
ls cicd_dagger_contract/typescript/
```

Each directory contains:
- `main.example.*` - Basic module structure
- `build.example.*` - Build function example
- `test.example.*` - UnitTest and IntegrationTest examples
- `deliver.example.*` - Deliver function example
- `deploy.example.*` - Deploy function example
- `validate.example.*` - Validate function example

## Next Steps

After successful validation:

1. **Run local pipelines**:
   ```bash
   cicd-local ci --pipeline-trigger=commit
   ```

2. **Test integration**:
   ```bash
   cicd-local iat
   ```

3. **Deploy locally**:
   ```bash
   cicd-local deploy
   ```

For more information, see:
- [Main README](../README.md) - Full cicd-local documentation
- [Contract Specification](../cicd_dagger_contract/README.md) - Detailed contract documentation
- Pipeline scripts in the root directory for usage examples
