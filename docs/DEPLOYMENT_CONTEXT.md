# Deployment Context

## Overview

The Deployment Context is a mechanism for the `Deploy` function to pass runtime information to downstream functions (`IntegrationTest` and `Validate`) without hardcoding assumptions about deployment targets.

## Contract Changes

### Deploy Function
- **Returns**: `File` (JSON format) containing deployment metadata
- **Export**: Pipeline scripts export this to `./output/deploy/context.json`

### IntegrationTest Function
- **New Parameter**: `deploymentContext` (optional) - File containing deployment metadata
- **Behavior**: Can use context to determine target URL or use explicit `targetUrl` parameter

### Validate Function
- **New Parameter**: `deploymentContext` (optional) - File containing deployment metadata
- **Behavior**: Can extract additional validation targets from context

## Deployment Context JSON Format

The Deploy function should return a JSON file with the following structure:

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
    "customField": "value"
  }
}
```

### Required Fields
- `endpoint` (string): Primary URL where the application is accessible

### Optional Fields
- `healthCheckUrl` (string): Health check endpoint
- `namespace` (string): Kubernetes namespace (if applicable)
- `releaseName` (string): Helm release name or deployment identifier
- `version` (string): Deployed version
- `metadata` (object): Additional deployment-specific information

## Implementation Guide

### 1. Implementing Deploy Function

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

### 2. Using Deployment Context in IntegrationTest

**Go Example:**
```go
func (m *MyApp) IntegrationTest(
    ctx context.Context,
    source *dagger.Directory,
    targetUrl string,
    deploymentContext *dagger.File,
) (string, error) {
    // If deployment context provided, extract endpoint
    if deploymentContext != nil && targetUrl == "" {
        contextContent, _ := deploymentContext.Contents(ctx)
        var context map[string]interface{}
        json.Unmarshal([]byte(contextContent), &context)
        targetUrl = context["endpoint"].(string)
    }
    
    // Use targetUrl for integration tests...
    return runTests(ctx, source, targetUrl)
}
```

**Python Example:**
```python
async def integration_test(
    self,
    source: dagger.Directory,
    target_url: Optional[str] = None,
    deployment_context: Optional[dagger.File] = None,
) -> str:
    # If deployment context provided and no explicit URL, extract endpoint
    if deployment_context and not target_url:
        context_content = await deployment_context.contents()
        context = json.loads(context_content)
        target_url = context.get("endpoint")
    
    # Use target_url for integration tests...
    return await run_tests(source, target_url)
```

### 3. Pipeline Integration

The pipeline scripts automatically:
1. Export Deploy output to `./output/deploy/context.json`
2. Pass context file to IntegrationTest and Validate functions
3. Extract target URL from context if needed

**Manual Usage:**
```bash
# Deploy and capture context
dagger -m cicd call deploy \
    --source=. \
    --kubeconfig=file:~/.kube/config \
    --helm-repository=oci://ttl.sh \
    --container-repository=ttl.sh \
    export --path=./output/deploy/context.json

# Use context in IntegrationTest
dagger -m cicd call integration-test \
    --source=. \
    --deployment-context=file:./output/deploy/context.json

# Or with explicit URL override
dagger -m cicd call integration-test \
    --source=. \
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

1. **Always include `endpoint`** field as the primary application URL
2. **Use absolute URLs** when possible (include protocol)
3. **Include health check URLs** for automated validation
4. **Add version information** for debugging
5. **Document custom metadata fields** in your project README
6. **Test context generation** with pipeline scripts
7. **Provide sensible defaults** in downstream functions when context is missing
