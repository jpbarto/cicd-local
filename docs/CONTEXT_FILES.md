# Context Files

## Overview

The cicd-local contract uses context files to pass information between pipeline functions. These context files enable loosely-coupled communication without hardcoding assumptions about deployment targets, artifact locations, or validation results.

**Important**: The format and contents of context files are **not strictly specified** by the contract. While JSON is the recommended format and sample structures are provided below, Dagger functions may use any format they choose. There are no required fields - the context file format is determined by the needs of your specific implementation.

## Context Types

### 1. Delivery Context (from Deliver function)
- **Returns**: `File` containing published artifact metadata
- **Export Path**: `./output/deliver/deliveryContext` (no file extension)
- **Used by**: Deploy function
- **Recommended Format**: JSON with artifact references

### 2. Deployment Context (from Deploy function)
- **Returns**: `File` containing deployment metadata
- **Export Path**: `./output/deploy/deploymentContext` (no file extension)
- **Used by**: Validate and IntegrationTest functions
- **Recommended Format**: JSON with endpoint and release information

### 3. Validation Context (from Validate function)
- **Returns**: `File` containing validation results and metadata
- **Export Path**: `./output/validate/validationContext` (no file extension)
- **Used by**: IntegrationTest function
- **Recommended Format**: JSON with health check results

## Contract Changes

### Deliver Function
- **Returns**: `File` containing delivery context (previously returned `string`)
- **Suggested Contents**: Published artifact references, versions, repository URLs

### Deploy Function
- **Returns**: `File` containing deployment context
- **Suggested Contents**: Endpoint URL, release name, namespace, versions

### Validate Function
- **Returns**: `File` containing validation context (previously returned `string`)
- **New Parameter**: `deploymentContext` (required) - File from Deploy function
- **Suggested Contents**: Validation status, health check results, endpoint

### IntegrationTest Function
- **New Parameter**: `kubeconfig` (required) - Kubernetes configuration for access
- **New Parameter**: `awsconfig` (optional) - AWS configuration
- **New Parameter**: `deploymentContext` (optional) - File from Deploy function
- **New Parameter**: `validationContext` (optional) - File from Validate function
- **Removed**: `targetUrl` parameter (use deploymentContext endpoint instead)

## Recommended JSON Formats

The following JSON structures are **recommendations only**. Your implementation may use different formats, different fields, or even non-JSON formats as needed.

### Delivery Context Format (Recommended)

The Deliver function should return a JSON file with published artifact information:

```json
{
  "timestamp": "2024-02-19T10:30:00Z",
  "imageReference": "ttl.sh/myapp:1.2.3",
  "chartReference": "oci://ttl.sh/charts/myapp:1.2.3",
  "version": "1.2.3",
  "containerRepository": "ttl.sh",
  "helmRepository": "oci://ttl.sh",
  "releaseCandidate": false
}
```

**Common Fields** (all optional):
- `timestamp` (string): ISO 8601 timestamp
- `imageReference` (string): Full container image reference
- `chartReference` (string): Full Helm chart reference
- `version` (string): Published version
- `containerRepository` (string): Container registry URL
- `helmRepository` (string): Helm repository URL
- `releaseCandidate` (boolean): Whether this is a release candidate

### Deployment Context Format (Recommended)

Example JSON structure for deployment information:

```json
{
  "timestamp": "2024-02-19T10:35:00Z",
  "endpoint": "http://myapp.namespace.svc.cluster.local:8080",
  "releaseName": "myapp",
  "namespace": "production",
  "chartVersion": "1.2.3",
  "imageReference": "ttl.sh/myapp:1.2.3"
}
```

**Common Fields** (all optional):
- `timestamp` (string): ISO 8601 timestamp
- `endpoint` (string): Primary URL where the application is accessible
- `releaseName` (string): Helm release name or deployment identifier
- `namespace` (string): Kubernetes namespace
- `chartVersion` (string): Deployed Helm chart version
- `imageReference` (string): Container image reference used

### Validation Context Format (Recommended)

Example JSON structure for validation results:

```json
{
```json
{
  "timestamp": "2024-02-19T10:36:00Z",
  "releaseName": "myapp",
  "endpoint": "http://myapp.namespace.svc.cluster.local:8080",
  "status": "healthy",
  "healthChecks": ["pod-ready", "service-available"],
  "readinessChecks": ["http-200", "metrics-available"]
}
```

**Common Fields** (all optional):
- `timestamp` (string): ISO 8601 timestamp
- `releaseName` (string): Name of the deployment/release
- `endpoint` (string): Application endpoint URL
- `status` (string): Overall validation status (e.g., "healthy", "degraded", "failed")
- `healthChecks` (array): List of health checks performed
- `readinessChecks` (array): List of readiness checks performed

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
3. **Deploy** → exports deploymentContext (File)
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

       Deploy (creates deploymentContext)
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

2. **Deploy with Kubeconfig:**
```bash
# Deploy and capture deployment context
dagger -m cicd call deploy \
    --source=. \
    --kubeconfig=file://~/.kube/config \
    --helm-repository=oci://ttl.sh \
    --container-repository=ttl.sh \
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
# Fix permissions on all context files
chmod 644 ./output/deliver/deliveryContext
chmod 644 ./output/deploy/deploymentContext
chmod 644 ./output/validate/validationContext

# Or regenerate with correct permissions
rm -rf ./output && ./local_deploy_pipeline.sh
```

## Best Practices

### Context File Creation

1. **Choose an appropriate format** for your needs:
   - JSON is recommended for broad compatibility and ease of parsing
   - Plain text, YAML, or custom formats are also acceptable
   - Consider what your consuming functions need to parse

2. **Include helpful metadata** when using structured formats:
   - Timestamps for debugging and traceability
   - Version information for compatibility checking
   - Status indicators for decision-making

3. **Use consistent naming** within your implementation:
   - If using JSON, keep field names consistent across contexts
   - Document custom fields in your project README

4. **Keep context files focused**:
   - Include information needed by downstream functions
   - Avoid including sensitive data (use Secrets for credentials)
   - Consider file size - keep contexts reasonably small

### Context File Consumption

1. **Handle missing contexts gracefully**:
   - Context parameters are typically optional
   - Provide reasonable defaults when contexts aren't available
   - Document what happens when contexts are omitted

2. **Validate format before parsing**:
   - Check for file existence before reading
   - Handle parsing errors appropriately
   - Provide clear error messages for format issues

**Example:**
```go
if deploymentContext != nil {
    contextContent, err := deploymentContext.Contents(ctx)
    if err != nil {
        return "", fmt.Errorf("failed to read deployment context: %w", err)
    }
    var context map[string]interface{}
    if err := json.Unmarshal([]byte(contextContent), &context); err != nil {
        return "", fmt.Errorf("invalid deployment context format: %w", err)
    }
    targetUrl = context["endpoint"].(string)
}
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
