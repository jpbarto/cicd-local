# Contract Validation Guide

Comprehensive guide for validating Dagger functions against the cicd-local contract.

## Table of Contents

- [Quick Start](#quick-start)
- [What Gets Validated](#what-gets-validated)
- [Supported Languages](#supported-languages)
- [Contract Requirements](#contract-requirements)
- [Validation Output](#validation-output)
- [Common Issues](#common-issues)
- [CI/CD Integration](#cicd-integration)
- [Reference Implementations](#reference-implementations)

## Quick Start

```bash
# Navigate to your project
cd /path/to/your/project

# Validate Dagger functions
cicd-local validate

# Or specify project path
cicd-local validate /path/to/your/project
```

**Requirements:**
- Project must have a `cicd/` directory
- Dagger module must be initialized
- Functions must implement the required signatures

## What Gets Validated

The validator checks six required functions in your `cicd/` directory:

| Function | Purpose |
|----------|---------|
| **Build** | Build multi-architecture Docker images |
| **UnitTest** | Run unit tests against built containers |
| **IntegrationTest** | Run integration tests against deployed apps |
| **Deliver** | Publish containers and Helm charts |
| **Deploy** | Deploy applications to Kubernetes |
| **Validate** | Validate deployment health |

For each function, the validator verifies:
- ✅ Function exists in your code
- ✅ Parameter names match the contract
- ✅ Parameter types match the contract (language-specific)

## Supported Languages

### Go (Golang)
- **Detection**: `main.go` or `dagger.gen.go` files in `cicd/`
- **Naming convention**: PascalCase (e.g., `Build`, `UnitTest`)
- **Example**: `cicd_dagger_contract/golang/`

### Python
- **Detection**: `pyproject.toml` or `src/__init__.py` files in `cicd/`
- **Naming convention**: snake_case (e.g., `build`, `unit_test`)
- **Example**: `cicd_dagger_contract/python/`

### Java
- **Detection**: `pom.xml` or `build.gradle` files in `cicd/`
- **Naming convention**: camelCase (e.g., `build`, `unitTest`)
- **Example**: `cicd_dagger_contract/java/`

### TypeScript
- **Detection**: `package.json` or `tsconfig.json` files in `cicd/`
- **Naming convention**: camelCase (e.g., `build`, `unitTest`)
- **Example**: `cicd_dagger_contract/typescript/`

## Contract Requirements

### 1. Build Function

**Purpose**: Build multi-architecture Docker images

**Go:**
```go
func (m *YourModule) Build(
    ctx context.Context,
    source *dagger.Directory,
    releaseCandidate bool,
) (*dagger.File, error)
```

**Python:**
```python
@function
async def build(
    self,
    source: dagger.Directory,
    release_candidate: bool = False,
) -> dagger.File:
```

**Java:**
```java
public File build(
    Directory source,
    boolean releaseCandidate
) throws Exception
```

**TypeScript:**
```typescript
@func()
async build(
    source: Directory,
    releaseCandidate: boolean = false
): Promise<File>
```

### 2. UnitTest Function

**Purpose**: Run unit tests against built container

**Go:**
```go
func (m *YourModule) UnitTest(
    ctx context.Context,
    source *dagger.Directory,
    buildArtifact *dagger.File,
) (string, error)
```

**Python:**
```python
@function
async def unit_test(
    self,
    source: dagger.Directory,
    build_artifact: Optional[dagger.File] = None,
) -> str:
```

**Java:**
```java
public String unitTest(
    Directory source,
    File buildArtifact
) throws Exception
```

**TypeScript:**
```typescript
@func()
async unitTest(
    source: Directory,
    buildArtifact?: File
): Promise<string>
```

### 3. IntegrationTest Function

**Purpose**: Run integration tests against deployed application

**Go:**
```go
func (m *YourModule) IntegrationTest(
    ctx context.Context,
    source *dagger.Directory,
    deploymentContext *dagger.File,
    validationContext *dagger.File,
) (string, error)
```

**Python:**
```python
@function
async def integration_test(
    self,
    source: dagger.Directory,
    deployment_context: Optional[dagger.File] = None,
    validation_context: Optional[dagger.File] = None,
) -> str:
```

**Java:**
```java
public String integrationTest(
    Directory source,
    File deploymentContext,
    File validationContext
) throws Exception
```

**TypeScript:**
```typescript
@func()
async integrationTest(
    source: Directory,
    deploymentContext?: File,
    validationContext?: File
): Promise<string>
```

### 4. Deliver Function

**Purpose**: Publish containers and Helm charts to repositories

**Go:**
```go
func (m *YourModule) Deliver(
    ctx context.Context,
    source *dagger.Directory,
    buildArtifact *dagger.File,
    releaseCandidate bool,
) (*dagger.File, error)
```

**Python:**
```python
@function
async def deliver(
    self,
    source: dagger.Directory,
    build_artifact: Optional[dagger.File] = None,
    release_candidate: bool = False,
) -> dagger.File:
```

**Java:**
```java
public File deliver(
    Directory source,
    File buildArtifact,
    boolean releaseCandidate
) throws Exception
```

**TypeScript:**
```typescript
@func()
async deliver(
    source: Directory,
    buildArtifact?: File,
    releaseCandidate: boolean = false
): Promise<File>
```

**Note**: Deliver returns a `File` containing delivery context (JSON metadata with published artifact details).

### 5. Deploy Function

**Purpose**: Deploy application to Kubernetes cluster

**Go:**
```go
func (m *YourModule) Deploy(
    ctx context.Context,
    source *dagger.Directory,
    helmRepository string,
    containerRepository string,
    releaseCandidate bool,
) (*dagger.File, error)
```

**Python:**
```python
@function
async def deploy(
    self,
    source: dagger.Directory,
    helm_repository: str = "oci://ttl.sh",
    container_repository: str = "ttl.sh",
    release_candidate: bool = False,
) -> dagger.File:
```

**Java:**
```java
public File deploy(
    Directory source,
    String helmRepository,
    String containerRepository,
    boolean releaseCandidate
) throws Exception
```

**TypeScript:**
```typescript
@func()
async deploy(
    source: Directory,
    helmRepository: string = "oci://ttl.sh",
    containerRepository: string = "ttl.sh",
    releaseCandidate: boolean = false
): Promise<File>
```

**Note**: Deploy returns a `File` containing deployment context (JSON metadata).

### 6. Validate Function

**Purpose**: Validate deployment health and correctness

**Go:**
```go
func (m *YourModule) Validate(
    ctx context.Context,
    source *dagger.Directory,
    releaseCandidate bool,
    deploymentContext *dagger.File,
) (*dagger.File, error)
```

**Python:**
```python
@function
async def validate(
    self,
    source: dagger.Directory,
    release_candidate: bool = False,
    deployment_context: Optional[dagger.File] = None,
) -> dagger.File:
```

**Java:**
```java
public File validate(
    Directory source,
    boolean releaseCandidate,
    File deploymentContext
) throws Exception
```

**TypeScript:**
```typescript
@func()
async validate(
    source: Directory,
    releaseCandidate: boolean = false,
    deploymentContext?: File
): Promise<File>
```

**Note**: Validate returns a `File` containing validation context (JSON metadata with validation results).

## Validation Output

### Success Example

```
========================================
Dagger Contract Validation
========================================

ℹ Project Directory: /Users/user/myproject
ℹ CICD Directory: /Users/user/myproject/cicd

✓ CICD directory found
✓ Detected language: golang

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Validating Function Signatures
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Function 'Build' signature matches contract
✓ Function 'UnitTest' signature matches contract
✓ Function 'IntegrationTest' signature matches contract
✓ Function 'Deliver' signature matches contract
✓ Function 'Deploy' signature matches contract
✓ Function 'Validate' signature matches contract

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Validation Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Total Checks:  6
Passed:        6
Failed:        0

✓ All function signatures conform to the cicd-local contract!

ℹ Your Dagger module is compatible with cicd-local pipelines
```

### Failure Example

```
========================================
Dagger Contract Validation
========================================

ℹ Project Directory: /Users/user/myproject
ℹ CICD Directory: /Users/user/myproject/cicd

✓ CICD directory found
✓ Detected language: python

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Validating Function Signatures
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Function 'build' signature matches contract
✗ Function 'unit_test' not found in Python files
✗   Parameter 'source' with type 'dagger.Directory' not found in deliver
✓ Function 'integration_test' signature matches contract
✓ Function 'deploy' signature matches contract
✓ Function 'validate' signature matches contract

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Validation Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Total Checks:  6
Passed:        4
Failed:        2

✗ Some function signatures do not conform to the contract

ℹ Review the errors above and update your functions to match the contract
```

## Common Issues

### Function Not Found

**Error**: `Function 'Build' not found in Go files`

**Cause**: Function name doesn't match language convention

**Solution**: 
- **Go**: Use PascalCase (`Build`, `UnitTest`)
- **Python**: Use snake_case (`build`, `unit_test`)
- **Java/TypeScript**: Use camelCase (`build`, `unitTest`)

**Example Fix (Python):**
```python
# ❌ Wrong
@function
async def Build(self, source: dagger.Directory) -> dagger.File:
    pass

# ✅ Correct
@function
async def build(self, source: dagger.Directory) -> dagger.File:
    pass
```

### Parameter Type Mismatch

**Error**: `Parameter 'source' with type 'dagger.Directory' not found`

**Cause**: Missing or incorrect type annotation

**Solution**: Verify:
1. Parameter name matches exactly (case-sensitive)
2. Type annotation is correct
3. Imports include necessary Dagger types

**Example Fix (Go):**
```go
// ❌ Wrong - missing type
func (m *App) Build(ctx context.Context, source interface{}) (*dagger.File, error)

// ✅ Correct
func (m *App) Build(ctx context.Context, source *dagger.Directory) (*dagger.File, error)
```

### Parameter Name Incorrect

**Error**: `Parameter 'buildArtifact' not found`

**Cause**: Parameter name doesn't match language convention

**Solution**: Match language-specific naming:
- **Go**: camelCase with uppercase first letter (`buildArtifact`)
- **Python**: snake_case (`build_artifact`)
- **Java/TypeScript**: camelCase (`buildArtifact`)

**Example Fix (Python):**
```python
# ❌ Wrong
@function
async def unit_test(self, source: dagger.Directory, buildArtifact: dagger.File) -> str:
    pass

# ✅ Correct
@function
async def unit_test(self, source: dagger.Directory, build_artifact: dagger.File) -> str:
    pass
```

### Language Not Detected

**Error**: `Unable to detect Dagger module language`

**Cause**: Missing language-specific marker files in `cicd/` directory

**Solution**: Ensure `cicd/` contains:
- **Go**: `main.go` or `dagger.gen.go`
- **Python**: `pyproject.toml` or `src/__init__.py`
- **Java**: `pom.xml` or `build.gradle`
- **TypeScript**: `package.json` or `tsconfig.json`

### Missing Optional Parameter

**Note**: Optional parameters don't cause validation failures

Parameters with default values or marked optional are not required:
- Go: Pointer types (e.g., `*dagger.File`)
- Python: `Optional[Type]` or default values
- Java: Nullable annotations
- TypeScript: `?` suffix on parameter name

### Return Type Mismatch

**Error**: Function signature doesn't match expected return type

**Solution**: Verify return types:
- **Build, Deploy**: Return `File` (deployment context)
- **UnitTest, IntegrationTest, Deliver, Validate**: Return `string`

**Example Fix (Deploy in Go):**
```go
// ❌ Wrong - returns string
func (m *App) Deploy(...) (string, error)

// ✅ Correct - returns File
func (m *App) Deploy(...) (*dagger.File, error)
```

## CI/CD Integration

### Pre-commit Hook

Validate before committing changes:

```bash
#!/bin/bash
# .git/hooks/pre-commit

if ! cicd-local validate; then
    echo "❌ Dagger contract validation failed"
    echo "Fix the errors above before committing"
    exit 1
fi
```

Make executable:
```bash
chmod +x .git/hooks/pre-commit
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
  image: alpine:latest
  before_script:
    - apk add --no-cache git bash
    - git clone https://gitlab.com/your-org/cicd-local.git ~/cicd-local
    - export PATH="$HOME/cicd-local:$PATH"
  script:
    - cicd-local validate
```

### CircleCI

```yaml
version: 2.1

jobs:
  validate:
    docker:
      - image: cimg/base:stable
    steps:
      - checkout
      - run:
          name: Install cicd-local
          command: |
            git clone https://github.com/your-org/cicd-local.git ~/cicd-local
            echo 'export PATH="$HOME/cicd-local:$PATH"' >> $BASH_ENV
      - run:
          name: Validate contract
          command: cicd-local validate

workflows:
  version: 2
  validate:
    jobs:
      - validate
```

## Reference Implementations

Example implementations are provided for all supported languages:

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
- `build.example.*` - Build function
- `test.example.*` - UnitTest and IntegrationTest functions
- `deliver.example.*` - Deliver function
- `deploy.example.*` - Deploy function
- `validate.example.*` - Validate function

## Best Practices

1. **Validate early**: Run validation during development, not just in CI/CD
2. **Use correct naming**: Follow language conventions (PascalCase, snake_case, camelCase)
3. **Type annotations**: Always include proper type annotations for parameters
4. **Import types**: Ensure Dagger types are properly imported
5. **Optional parameters**: Mark optional parameters correctly for your language
6. **Test validation**: Create test projects to verify contract compliance
7. **Keep updated**: Regularly check for contract updates

## Troubleshooting

### Validator Not Finding Functions

1. Verify function is public/exported (language-specific)
2. Check function name matches language convention exactly
3. Ensure function is in correct file (main module file)
4. Verify function has correct decorator/annotation (Python/TypeScript)

### False Positives

If validator reports errors but function seems correct:

1. Check for whitespace in parameter names
2. Verify import statements are correct
3. Look for syntax errors preventing function detection
4. Try running Dagger directly: `dagger functions`

### Validator Crashes

If validator fails unexpectedly:

1. Check `cicd/` directory exists
2. Verify file permissions are correct
3. Ensure no corrupted files in `cicd/`
4. Run with debug: add `-x` to validate_contract.sh

## Next Steps

After successful validation:

1. **Run local pipelines**: `cicd-local ci`
2. **Test integration**: `cicd-local iat`
3. **Deploy locally**: `cicd-local deploy`

## Additional Resources

- **[USER_GUIDE.md](USER_GUIDE.md)** - Complete pipeline usage guide
- **[CONTRACT_REFERENCE.md](CONTRACT_REFERENCE.md)** - Detailed contract specification
- **[CONTEXT_FILES.md](CONTEXT_FILES.md)** - Context files for inter-function communication
- **Example implementations** in `cicd_dagger_contract/` directory

## Getting Help

1. Review validation error messages carefully
2. Compare with reference implementations
3. Check language-specific naming conventions
4. Verify type imports and annotations
5. Test function individually: `dagger call <function-name> --help`
