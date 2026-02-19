# Context Files

## Overview

The cicd-local contract uses context files to pass information between pipeline functions. These context files enable loosely-coupled communication without hardcoding assumptions about deployment targets, artifact locations, or validation results.

## Context Types

### 1. Delivery Context (from Deliver function)
- **Returns**: `File` (JSON format) containing published artifact metadata
- **Export**: Pipeline scripts export this to `./output/deliver/deliveryContext`
- **Used by**: Deploy function

### 2. Deployment Context (from Deploy function)
- **Returns**: `File` (JSON format) containing deployment metadata
- **Export**: Pipeline scripts export this to `./output/deploy/context.json`
- **Used by**: Validate and IntegrationTest functions

### 3. Validation Context (from Validate function)
- **Returns**: `File` (JSON format) containing validation results and metadata
- **Export**: Pipeline scripts export this to `./output/validate/validationContext`
- **Used by**: IntegrationTest function

## Contract Changes

### Deliver Function
- **Returns**: `File` containing delivery context (previously returned `string`)
- **Contents**: Published artifact references, versions, repository URLs

### Deploy Function
- **Returns**: `File` containing deployment context
- **New Parameter**: `deliveryContext` (optional) - File from Deliver function
- **Export**: Pipeline scripts export to `./output/deploy/context.json`

### Validate Function
- **Returns**: `File` containing validation context (previously returned `string`)
- **New Parameter**: `deploymentContext` (optional) - File from Deploy function
- **Export**: Pipeline scripts export to `./output/validate/validationContext`

### IntegrationTest Function
- **New Parameter**: `kubeconfig` (required) - Kubernetes configuration for access
- **New Parameter**: `awsconfig` (optional) - AWS configuration
- **New Parameter**: `deploymentContext` (optional) - File from Deploy function
- **New Parameter**: `validationContext` (optional) - File from Validate function
- **Removed**: `targetUrl` parameter (use deploymentContext endpoint instead)

## Context File JSON Formats

### Delivery Context Format

The Deliver function should return a JSON file with published artifact information:

```json
{
  "containerImage": "ttl.sh/myapp:1.2.3",
  "helmChart": "oci://ttl.sh/charts/myapp:1.2.3",
  "version": "1.2.3",
  "architecture": ["linux/amd64", "linux/arm64"],
  "repositories": {
    "container": "ttl.sh",
    "helm": "oci://ttl.sh"
  },
  "metadata": {
    "publishedAt": "2024-02-19T10:30:00Z",
    "releaseCandidate": false
  }
}
```

**Required Fields:**
- `containerImage` (string): Full container image reference
- `helmChart` (string): Full Helm chart reference
- `version` (string): Published version

**Optional Fields:**
- `architecture` (array): List of architectures
- `repositories` (object): Repository URLs
- `metadata` (object): Additional publish-time information

### Deployment Context JSON Format

The Deploy function should return a JSON file with deployment information:

```json
{
  "endpoint": "http://myapp.namespace.svc.cluster.local:8080",
  "healthCheckUrl": "http://myapp.namespace.svc.cluster.local:8080/health",
  "namespace": "production",
  "releaseName": "myapp-v1.2.3",
  "version": "1.2.3",
  "metadata": {
    "serviceName": "myapp",
    "port": 8080,
    "protocol": "http",
    "deployedAt": "2024-02-19T10:35:00Z"
  }
}
```

**Required Fields:**
- `endpoint` (string): Primary URL where the application is accessible

**Optional Fields:**
- `healthCheckUrl` (string): Health check endpoint
- `namespace` (string): Kubernetes namespace
- `releaseName` (string): Helm release name or deployment identifier
- `version` (string): Deployed version
- `metadata` (object): Additional deployment-specific information

### Validation Context JSON Format

The Validate function should return a JSON file with validation results:

```json
{
  "status": "passed",
  "checks": {
    "deployment": "healthy",
    "replicas": "ready",
    "endpoints": "responding",
    "version": "correct"
  },
  "metrics": {
    "podsReady": 3,
    "podsTotal": 3,
    "responseTime": "45ms"
  },
  "metadata": {
    "validatedAt": "2024-02-19T10:36:00Z",
    "validator": "dagger-validate-v1"
  }
}
```

**Required Fields:**
- `status` (string): Overall validation status ("passed", "failed", "warning")

**Optional Fields:**
- `checks` (object): Individual check results
- `metrics` (object): Numeric validation metrics
- `metadata` (object): Additional validation information

## Implementation Guide

### Pipeline Context Flow

The complete pipeline context flow:

```
Build → Deliver → Deploy → Validate → IntegrationTest
  ↓        ↓         ↓         ↓            ↓
 File  →  File  →  File  →  File      (uses all contexts)
        delivery deployment validation
        Context   Context    Context
```

**Context passing:**
1. **Build** → exports buildArtifact (File)
2. **Deliver** → receives buildArtifact → exports deliveryContext (File)
3. **Deploy** → receives deliveryContext → exports deploymentContext (File)
4. **Validate** → receives deploymentContext → exports validationContext (File)
5. **IntegrationTest** → receives deploymentContext + validationContext

### 1. Implementing Deliver Function

**Go Example:**
```go
func (m *MyApp) Deliver(
    ctx context.Context,
    source *dagger.Directory,
    containerRepository string,
    helmRepository string,
    buildArtifact *dagger.File,
    releaseCandidate bool,
) (*dagger.File, error) {
    // Perform delivery (publish artifacts)...
    version := "1.2.3"
    imageRef := fmt.Sprintf("%s/myapp:%s", containerRepository, version)
    chartRef := fmt.Sprintf("%s/charts/myapp:%s", helmRepository, version)
    
    // Create delivery context
    context := map[string]interface{}{
        "containerImage": imageRef,
        "helmChart": chartRef,
        "version": version,
        "architecture": []string{"linux/amd64", "linux/arm64"},
        "repositories": map[string]string{
            "container": containerRepository,
            "helm": helmRepository,
        },
    }
    
    contextJSON, _ := json.Marshal(context)
    
    return dag.Container().
        From("alpine:latest").
        WithNewFile("/delivery-context.json", string(contextJSON)).
        File("/delivery-context.json"), nil
}
```

### 2. Implementing Deploy Function

**Go Example:**
```go
func (m *MyApp) Deploy(
    ctx context.Context,
    source *dagger.Directory,
    awsconfig *dagger.Secret,
    kubeconfig *dagger.Secret,
    helmRepository string,
    containerRepository string,
    releaseCandidate bool,
    deliveryContext *dagger.File,
) (*dagger.File, error) {
    // Perform deployment...
    namespace := "production"
    releaseName := "myapp-v1.2.3"
    
    // Create deployment context
    context := map[string]interface{}{
        "endpoint": fmt.Sprintf("http://%s.%s.svc.cluster.local:8080", releaseName, namespace),
        "healthCheckUrl": fmt.Sprintf("http://%s.%s.svc.cluster.local:8080/health", releaseName, namespace),
        "namespace": namespace,
        "releaseName": releaseName,
        "version": "1.2.3",
        "metadata": map[string]interface{}{
            "serviceName": releaseName,
            "port": 8080,
            "protocol": "http",
        },
    }
    
    contextJSON, _ := json.Marshal(context)
    
    return dag.Container().
        From("alpine:latest").
        WithNewFile("/deployment-context.json", string(contextJSON)).
        File("/deployment-context.json"), nil
}
```

**Python Example:**
```python
async def deploy(
    self,
    source: dagger.Directory,
    awsconfig: Optional[dagger.Secret] = None,
    kubeconfig: Optional[dagger.Secret] = None,
    helm_repository: str = "oci://ttl.sh",
    container_repository: str = "ttl.sh",
    release_candidate: bool = False,
    delivery_context: Optional[dagger.File] = None,
) -> dagger.File:
) -> dagger.File:
    # Perform deployment...
    namespace = "production"
    release_name = "myapp-v1.2.3"
    
    # Create deployment context
    context = {
        "endpoint": f"http://{release_name}.{namespace}.svc.cluster.local:8080",
        "healthCheckUrl": f"http://{release_name}.{namespace}.svc.cluster.local:8080/health",
        "namespace": namespace,
        "releaseName": release_name,
        "version": "1.2.3",
        "metadata": {
            "serviceName": release_name,
            "port": 8080,
            "protocol": "http",
        }
    }
    
    context_json = json.dumps(context)
    
    return await (
        dag.container()
        .from_("alpine:latest")
        .with_new_file("/deployment-context.json", context_json)
        .file("/deployment-context.json")
    )
```

### 2. Implementing Validate Function with Validation Context

The Validate function now returns a File containing validation results that can be used by IntegrationTest.

**Go Example:**
```go
func (m *MyApp) Validate(
    ctx context.Context,
    kubeconfig *dagger.File,
    deploymentContext *dagger.File,
    awsconfig *dagger.Secret,
) (*dagger.File, error) {
    // Extract deployment information
    contextContent, _ := deploymentContext.Contents(ctx)
    var depContext map[string]interface{}
    json.Unmarshal([]byte(contextContent), &depContext)
    
    endpoint := depContext["endpoint"].(string)
    releaseName := depContext["releaseName"].(string)
    
    // Perform validation checks
    results := validateDeployment(ctx, kubeconfig, endpoint, releaseName)
    
    // Create validation context with results
    validationContext := map[string]interface{}{
        "timestamp": time.Now().Format(time.RFC3339),
        "releaseName": releaseName,
        "endpoint": endpoint,
        "healthChecks": results.HealthChecks,
        "readinessChecks": results.ReadinessChecks,
        "status": results.Status,
    }
    
    contextJSON, _ := json.MarshalIndent(validationContext, "", "  ")
    
    // Return as file
    return dag.Directory().
        WithNewFile("validation-context.json", string(contextJSON)).
        File("validation-context.json"), nil
}
```

**Python Example:**
```python
async def validate(
    self,
    kubeconfig: dagger.File,
    deployment_context: dagger.File,
    awsconfig: Optional[dagger.Secret] = None,
) -> dagger.File:
    # Extract deployment information
    context_content = await deployment_context.contents()
    dep_context = json.loads(context_content)
    
    endpoint = dep_context["endpoint"]
    release_name = dep_context["releaseName"]
    
    # Perform validation checks
    results = await validate_deployment(kubeconfig, endpoint, release_name)
    
    # Create validation context with results
    validation_context = {
        "timestamp": datetime.now().isoformat(),
        "releaseName": release_name,
        "endpoint": endpoint,
        "healthChecks": results["health_checks"],
        "readinessChecks": results["readiness_checks"],
        "status": results["status"]
    }
    
    context_json = json.dumps(validation_context, indent=2)
    
    # Return as file
    return (
        dag.directory()
        .with_new_file("validation-context.json", context_json)
        .file("validation-context.json")
    )
```

### 3. Using Validation Context in IntegrationTest

IntegrationTest can now accept both deploymentContext and validationContext to get complete information about the deployment.

**Go Example:**
```go
func (m *MyApp) IntegrationTest(
    ctx context.Context,
    source *dagger.Directory,
    kubeconfig *dagger.File,
    awsconfig *dagger.Secret,
    deploymentContext *dagger.File,
    validationContext *dagger.File,
) (string, error) {
    var targetUrl string
    
    // Extract endpoint from deployment context
    if deploymentContext != nil {
        contextContent, _ := deploymentContext.Contents(ctx)
        var context map[string]interface{}
        json.Unmarshal([]byte(contextContent), &context)
        targetUrl = context["endpoint"].(string)
    }
    
    // Extract validation results if available
    var validationStatus string
    if validationContext != nil {
        valContent, _ := validationContext.Contents(ctx)
        var valContext map[string]interface{}
        json.Unmarshal([]byte(valContent), &valContext)
        validationStatus = valContext["status"].(string)
        
        // Skip tests if validation failed
        if validationStatus != "healthy" {
            return "", fmt.Errorf("Skipping tests: deployment validation failed")
        }
    }
    
    // Run integration tests against targetUrl
    return runIntegrationTests(ctx, source, targetUrl)
}
```

**Python Example:**
```python
async def integration_test(
    self,
    source: dagger.Directory,
    kubeconfig: dagger.File,
    awsconfig: Optional[dagger.Secret] = None,
    deployment_context: Optional[dagger.File] = None,
    validation_context: Optional[dagger.File] = None,
) -> str:
    target_url = None
    
    # Extract endpoint from deployment context
    if deployment_context:
        context_content = await deployment_context.contents()
        context = json.loads(context_content)
        target_url = context.get("endpoint")
    
    # Extract validation results if available
    if validation_context:
        val_content = await validation_context.contents()
        val_context = json.loads(val_content)
        validation_status = val_context.get("status")
        
        # Skip tests if validation failed
        if validation_status != "healthy":
            raise Exception("Skipping tests: deployment validation failed")
    
    # Run integration tests against target_url
    return await run_integration_tests(source, target_url)
```

### 4. Pipeline Integration

The pipeline scripts automatically handle context file flow:

**Context Flow in Pipelines:**
```
Build → Deliver (creates deliveryContext)
          ↓
       Deploy (uses deliveryContext, creates deploymentContext)
          ↓
      Validate (uses deploymentContext, creates validationContext)
          ↓
  IntegrationTest (uses deploymentContext + validationContext)
```

**Directory Structure:**
```
output/
├── deliver/
│   └── deliveryContext      # From Deliver function
├── deploy/
│   └── deploymentContext    # From Deploy function
└── validate/
    └── validationContext    # From Validate function
```

**Manual Dagger Commands:**

1. **Build and Deliver:**
```bash
# Build
dagger -m cicd call build \
    --source=. \
    export --path=./output/build/buildArtifact

# Deliver and capture delivery context
dagger -m cicd call deliver \
    --source=. \
    --build-artifact=file:./output/build/buildArtifact \
    --helm-repository=oci://ttl.sh \
    --container-repository=ttl.sh \
    export --path=./output/deliver/deliveryContext
```

2. **Deploy with Delivery Context:**
```bash
# Deploy and capture deployment context
dagger -m cicd call deploy \
    --source=. \
    --kubeconfig=file:~/.kube/config \
    --helm-repository=oci://ttl.sh \
    --container-repository=ttl.sh \
    --delivery-context=file:./output/deliver/deliveryContext \
    export --path=./output/deploy/deploymentContext
```

3. **Validate with Deployment Context:**
```bash
# Validate and capture validation context
dagger -m cicd call validate \
    --kubeconfig=file:~/.kube/config \
    --deployment-context=file:./output/deploy/deploymentContext \
    export --path=./output/validate/validationContext
```

4. **Integration Test with Both Contexts:**
```bash
# Run integration tests with context files
dagger -m cicd call integration-test \
    --source=. \
    --kubeconfig=file:~/.kube/config \
    --deployment-context=file:./output/deploy/deploymentContext \
    --validation-context=file:./output/validate/validationContext
```

## Troubleshooting

### Context File Not Found

**Problem:** Pipeline can't find context file
```
Error: failed to read file "./output/deliver/deliveryContext": no such file or directory
```

**Solution:** Ensure previous pipeline step completed successfully and exported the context file. Check that:
- Output directory exists
- Export command succeeded
- File path matches expected location

### Invalid JSON in Context File

**Problem:** Context file contains invalid JSON
```
Error: invalid character '}' looking for beginning of object key string
```

**Solution:** 
- Verify your Dagger function creates valid JSON
- Use `json.dumps()` or `json.MarshalIndent()` to ensure proper formatting
- Test context file with: `jq . ./output/deploy/deploymentContext`

### Missing Required Context Information

**Problem:** Context file missing expected fields
```
Error: endpoint not found in deployment context
```

**Solution:**
- Review the JSON format specifications in this document
- Ensure your implementation includes all required fields
- Add defensive checks in consuming functions

### Context File Permissions

**Problem:** Can't read context file due to permissions
```
Error: permission denied reading context file
```

**Solution:**
```bash
# Fix permissions
chmod 644 ./output/*/context.json

# Or regenerate with correct permissions
rm -rf ./output && ./local_deploy_pipeline.sh
```
    --target-url=http://localhost:8080 \
    --deployment-context=file:./output/deploy/context.json
```

## Benefits

1. **Flexibility**: Deploy targets (Kubernetes, Docker, cloud services) can provide relevant information
2. **Decoupling**: IntegrationTest/Validate don't need to know deployment internals
3. **Extensibility**: Add new metadata fields without changing function signatures
4. **Backward Compatibility**: Existing parameter-based calls still work
5. **Convention over Configuration**: Sensible defaults when context not available

## Migration Guide

### For Existing Implementations

1. **Update Deploy function** to return `File` instead of `string`
2. **Generate deployment context JSON** with at minimum `endpoint` field
3. **Add optional deploymentContext parameter** to IntegrationTest/Validate
4. **Read context when provided**, fall back to explicit parameters
5. **Test with pipeline scripts** that automatically handle context passing

### Example Migration

**Before:**
```go
func (m *MyApp) Deploy(...) (string, error) {
    // deployment logic
    return "Deployed successfully", nil
}
```

**After:**
```go
func (m *MyApp) Deploy(...) (*dagger.File, error) {
    // deployment logic
    
    context := map[string]interface{}{
        "endpoint": "http://myapp:8080",
    }
    contextJSON, _ := json.Marshal(context)
    
    return dag.Container().
        From("alpine:latest").
        WithNewFile("/deployment-context.json", string(contextJSON)).
        File("/deployment-context.json"), nil
}
```

## Best Practices

### Context File Creation

1. **Always include required fields** for each context type:
   - deliveryContext: `imageReference`, `chartReference`, `timestamp`
   - deploymentContext: `endpoint`, `releaseName`, `namespace`, `timestamp`
   - validationContext: `status`, `endpoint`, `timestamp`

2. **Use ISO 8601 timestamps** for consistency:
   ```python
   datetime.now().isoformat()  # Python
   ```
   ```go
   time.Now().Format(time.RFC3339)  // Go
   ```

3. **Include version information** for traceability:
   ```json
   {
     "version": "1.2.3",
     "imageTag": "myapp:1.2.3",
     "chartVersion": "0.5.0"
   }
   ```

4. **Use absolute URLs** with protocols:
   ```json
   {
     "endpoint": "https://myapp.example.com",
     "healthCheckUrl": "https://myapp.example.com/health"
   }
   ```

### Context File Consumption

1. **Check for file existence** before reading
2. **Validate JSON structure** after parsing
3. **Provide fallback values** for optional fields
4. **Add defensive error handling** for missing fields

**Example:**
```go
if deploymentContext != nil {
    contextContent, err := deploymentContext.Contents(ctx)
    if err != nil {
        return "", fmt.Errorf("failed to read deployment context: %w", err)
    }
    var context map[string]interface{}
    if err := json.Unmarshal([]byte(contextContent), &context); err != nil {
        return "", fmt.Errorf("invalid deployment context JSON: %w", err)
    }
    targetUrl = context["endpoint"].(string)
}
```

### Pipeline Integration

1. **Create output directories** before exporting:
   ```bash
   mkdir -p ./output/deliver ./output/deploy ./output/validate
   ```

2. **Use consistent paths** across all pipeline scripts:
   - `./output/deliver/deliveryContext`
   - `./output/deploy/deploymentContext`
   - `./output/validate/validationContext`

3. **Check export success** before continuing:
   ```bash
   if [ ! -f "./output/deploy/deploymentContext" ]; then
       echo "Error: Failed to export deployment context"
       exit 1
   fi
   ```

4. **Clean output directory** between runs when needed:
   ```bash
   rm -rf ./output
   ```

## Benefits of Context Files

1. **Loose Coupling**: Functions don't need implementation details of previous steps
2. **Flexibility**: Add new fields without changing function signatures
3. **Traceability**: Context files provide audit trail of deployments
4. **Reusability**: Context files can be saved and replayed for testing
5. **Backward Compatibility**: Optional parameters maintain existing usage patterns

## Related Documentation

- **[User Guide](USER_GUIDE.md)**: Complete pipeline usage examples
- **[Contract Reference](CONTRACT_REFERENCE.md)**: Detailed function specifications
- **[Contract Validation](CONTRACT_VALIDATION.md)**: Implementation examples for all languages
