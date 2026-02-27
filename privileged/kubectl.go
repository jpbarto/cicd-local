package cicd

import (
	"context"
	"fmt"
	"os"

	"dagger.io/dagger"
)

// KubectlApply applies Kubernetes manifests using kubectl.
// This function executes kubectl apply with the provided manifests directory.
//
// Parameters:
//   - ctx: Context for the operation
//   - client: Dagger client instance
//   - manifestsDir: Directory containing Kubernetes YAML manifests
//   - namespace: Kubernetes namespace to apply to (optional, uses manifest default if empty)
//
// Environment variables:
//   - KUBECTL_CONTEXT: Kubernetes context to use (optional)
//
// Returns the kubectl apply output as a string.
//
// Example usage:
//
//	output, err := cicd.KubectlApply(ctx, client, manifestsDir, "default")
//	if err != nil {
//	    return "", fmt.Errorf("kubectl apply failed: %w", err)
//	}
func KubectlApply(
	ctx context.Context,
	client *dagger.Client,
	manifestsDir *dagger.Directory,
	namespace string,
) (string, error) {
	if manifestsDir == nil {
		return "", fmt.Errorf("manifests directory is required")
	}

	kubeconfig, err := GetKubeconfigSecret(ctx, client)
	if err != nil {
		return "", fmt.Errorf("failed to get kubeconfig: %w", err)
	}

	// Start with kubectl container
	container := client.Container().
		From("bitnami/kubectl:latest").
		WithMountedDirectory("/manifests", manifestsDir).
		WithMountedSecret("/root/.kube/config", kubeconfig)

	// Build kubectl command
	args := []string{"kubectl", "apply", "-f", "/manifests"}

	// Add namespace if specified
	if namespace != "" {
		args = append(args, "-n", namespace)
	}

	// Add context if specified in environment
	if kubectlContext := os.Getenv("KUBECTL_CONTEXT"); kubectlContext != "" {
		args = append(args, "--context", kubectlContext)
	}

	// Execute kubectl apply
	output, err := container.WithExec(args).Stdout(ctx)
	if err != nil {
		return "", fmt.Errorf("kubectl apply failed: %w", err)
	}

	return output, nil
}

// KubectlGet retrieves a Kubernetes resource and returns it as JSON.
// This function executes kubectl get with the specified resource and namespace.
//
// Parameters:
//   - ctx: Context for the operation
//   - client: Dagger client instance
//   - namespace: Kubernetes namespace containing the resource
//   - resourceName: Resource to get (e.g., "pod/mypod", "deployment/myapp", "service/mysvc")
//
// Environment variables:
//   - KUBECTL_CONTEXT: Kubernetes context to use (optional)
//
// Returns the resource as JSON string.
//
// Example usage:
//
//	podJSON, err := cicd.KubectlGet(ctx, client, "default", "pod/mypod")
//	if err != nil {
//	    return "", fmt.Errorf("kubectl get failed: %w", err)
//	}
func KubectlGet(
	ctx context.Context,
	client *dagger.Client,
	namespace string,
	resourceName string,
) (string, error) {
	if namespace == "" {
		return "", fmt.Errorf("namespace is required")
	}
	if resourceName == "" {
		return "", fmt.Errorf("resource name is required")
	}

	kubeconfig, err := GetKubeconfigSecret(ctx, client)
	if err != nil {
		return "", fmt.Errorf("failed to get kubeconfig: %w", err)
	}

	// Start with kubectl container
	container := client.Container().
		From("bitnami/kubectl:latest").
		WithMountedSecret("/root/.kube/config", kubeconfig)

	// Build kubectl command with JSON output
	args := []string{"kubectl", "get", resourceName, "-n", namespace, "-o", "json"}

	// Add context if specified in environment
	if kubectlContext := os.Getenv("KUBECTL_CONTEXT"); kubectlContext != "" {
		args = append(args, "--context", kubectlContext)
	}

	// Execute kubectl get
	output, err := container.WithExec(args).Stdout(ctx)
	if err != nil {
		return "", fmt.Errorf("kubectl get failed: %w", err)
	}

	return output, nil
}

// KubectlPortForward creates a port-forwarding tunnel to a Kubernetes resource.
// This function returns a Service that can be used by other Dagger functions to connect
// to the forwarded port. The port forwarding runs in the background as a service.
//
// Parameters:
//   - ctx: Context for the operation
//   - client: Dagger client instance
//   - namespace: Kubernetes namespace containing the resource
//   - resourceName: Resource to forward to (e.g., "pod/mypod", "deployment/myapp", "service/mysvc")
//   - ports: Port mapping in format "localPort:remotePort" (e.g., "8080:80", "3000:3000")
//
// Environment variables:
//   - KUBECTL_CONTEXT: Kubernetes context to use (optional)
//
// Returns a Dagger Service that forwards the specified ports.
//
// Example usage:
//
//	portForwardSvc, err := cicd.KubectlPortForward(ctx, client, "default", "pod/mypod", "8080:80")
//	if err != nil {
//	    return err
//	}
//	// Use the service in another container
//	testContainer := client.Container().
//	    From("curlimages/curl:latest").
//	    WithServiceBinding("app", portForwardSvc).
//	    WithExec([]string{"curl", "http://app:8080/health"})
func KubectlPortForward(
	ctx context.Context,
	client *dagger.Client,
	namespace string,
	resourceName string,
	ports string,
) (*dagger.Service, error) {
	if namespace == "" {
		return nil, fmt.Errorf("namespace is required")
	}
	if resourceName == "" {
		return nil, fmt.Errorf("resource name is required")
	}
	if ports == "" {
		return nil, fmt.Errorf("ports are required (format: localPort:remotePort)")
	}

	kubeconfig, err := GetKubeconfigSecret(ctx, client)
	if err != nil {
		return nil, fmt.Errorf("failed to get kubeconfig: %w", err)
	}

	// Start with kubectl container
	container := client.Container().
		From("bitnami/kubectl:latest").
		WithMountedSecret("/root/.kube/config", kubeconfig)

	// Build kubectl port-forward command
	args := []string{
		"kubectl", "port-forward",
		resourceName,
		ports,
		"-n", namespace,
		"--address", "0.0.0.0", // Listen on all interfaces so Dagger can access it
	}

	// Add context if specified in environment
	if kubectlContext := os.Getenv("KUBECTL_CONTEXT"); kubectlContext != "" {
		args = append(args, "--context", kubectlContext)
	}

	// Extract the local port from the ports string (e.g., "8080:80" -> 8080)
	localPort := ports
	for i, c := range ports {
		if c == ':' {
			localPort = ports[:i]
			break
		}
	}

	// Create and return the service
	// The service will run kubectl port-forward in the background
	service := container.
		WithExec(args).
		WithExposedPort(parsePort(localPort)).
		AsService()

	return service, nil
}

// parsePort converts a port string to an integer for WithExposedPort
func parsePort(portStr string) int {
	port := 0
	for _, c := range portStr {
		if c >= '0' && c <= '9' {
			port = port*10 + int(c-'0')
		}
	}
	if port == 0 {
		return 8080 // default fallback
	}
	return port
}

// KubectlLogs retrieves log lines from a pod. The kubeconfig is sourced
// automatically from the injected secrets.
//
// Parameters:
//   - ctx: Context for the operation
//   - client: Dagger client instance
//   - namespace: Kubernetes namespace containing the pod
//   - podName: Name of the pod (e.g. "myapp-7d6b9f-xkj2p")
//   - lines: Maximum number of log lines to return (passed as --tail)
//
// Environment variables:
//   - KUBECTL_CONTEXT: Kubernetes context to use (optional)
//
// Returns the log output as a string or an error.
//
// Example usage:
//
//	logs, err := cicd.KubectlLogs(ctx, client, "default", "myapp-7d6b9f-xkj2p", 100)
//	if err != nil {
//	    return "", fmt.Errorf("kubectl logs failed: %w", err)
//	}
func KubectlLogs(
	ctx context.Context,
	client *dagger.Client,
	namespace string,
	podName string,
	lines int,
) (string, error) {
	if namespace == "" {
		return "", fmt.Errorf("namespace is required")
	}
	if podName == "" {
		return "", fmt.Errorf("pod name is required")
	}
	if lines <= 0 {
		return "", fmt.Errorf("lines must be greater than 0")
	}

	kubeconfig, err := GetKubeconfigSecret(ctx, client)
	if err != nil {
		return "", fmt.Errorf("failed to get kubeconfig: %w", err)
	}

	args := []string{
		"kubectl", "logs",
		podName,
		"-n", namespace,
		"--tail", fmt.Sprintf("%d", lines),
	}

	if kubectlContext := os.Getenv("KUBECTL_CONTEXT"); kubectlContext != "" {
		args = append(args, "--context", kubectlContext)
	}

	output, err := client.Container().
		From("bitnami/kubectl:latest").
		WithMountedSecret("/root/.kube/config", kubeconfig).
		WithExec(args).
		Stdout(ctx)
	if err != nil {
		return "", fmt.Errorf("kubectl logs failed for pod %q in namespace %q: %w", podName, namespace, err)
	}

	return output, nil
}
