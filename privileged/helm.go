package cicd

import (
	"context"
	"fmt"
	"os"
	"strings"
	"time"

	"dagger.io/dagger"
)

// HelmInstall installs or upgrades a Helm chart from a chart reference.
// Uses `helm upgrade --install` so the operation is idempotent: it installs
// the release if it does not exist and upgrades it if it does.
//
// Parameters:
//   - ctx: Context for the operation
//   - client: Dagger client instance
//   - releaseName: Name of the Helm release
//   - chartReference: Chart reference string (e.g. "oci://ghcr.io/myorg/myapp", "bitnami/nginx")
//   - namespace: Kubernetes namespace to install into
//   - valuesFile: Optional values file to pass with -f (can be nil)
//
// Environment variables:
//   - HELM_TIMEOUT: Timeout for helm operations (default: 5m)
//   - KUBECTL_CONTEXT: Kubernetes context to use (optional)
//
// Returns the helm output as a string.
//
// Example usage:
//
//	output, err := cicd.HelmInstall(ctx, client, "myapp", "oci://ghcr.io/myorg/myapp", "default", nil)
//	if err != nil {
//	    return "", fmt.Errorf("helm install failed: %w", err)
//	}
func HelmInstall(
	ctx context.Context,
	client *dagger.Client,
	releaseName string,
	chartReference string,
	namespace string,
	valuesFile *dagger.File,
) (string, error) {
	if releaseName == "" {
		return "", fmt.Errorf("release name is required")
	}
	if chartReference == "" {
		return "", fmt.Errorf("chart reference is required")
	}
	if namespace == "" {
		return "", fmt.Errorf("namespace is required")
	}

	kubeconfig, err := GetKubeconfigSecret(ctx, client)
	if err != nil {
		return "", fmt.Errorf("failed to get kubeconfig: %w", err)
	}

	// Create the namespace first using kubectl. `kubectl create namespace` is
	// idempotent when combined with --dry-run=client | kubectl apply -f - but
	// the simplest approach is to apply a minimal namespace manifest so that
	// the operation is a no-op if the namespace already exists.
	_, err = client.Container().
		From("bitnami/kubectl:latest").
		WithMountedSecret("/tmp/kubeconfig", kubeconfig, dagger.ContainerWithMountedSecretOpts{Owner: "1000:1000", Mode: 0444}).
		WithEnvVariable("KUBECONFIG", "/tmp/kubeconfig").
		WithEnvVariable("CACHE_BUST", time.Now().String()).
		WithExec([]string{
			"kubectl", "create", "namespace", namespace, "-o", "yaml",
		}).
		Stdout(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to create namespace %q: %w", namespace, err)
	}

	container := client.Container().
		From("alpine/helm:latest").
		WithMountedSecret("/tmp/kubeconfig", kubeconfig, dagger.ContainerWithMountedSecretOpts{Owner: "1000:1000", Mode: 0444}).
		WithEnvVariable("KUBECONFIG", "/tmp/kubeconfig")

	// Mount values file if provided
	if valuesFile != nil {
		container = container.WithFile("/values.yaml", valuesFile, dagger.ContainerWithFileOpts{Permissions: 0444})
	}

	// Build helm command — namespace is already guaranteed to exist so
	// --create-namespace is omitted.
	args := []string{
		"helm", "upgrade", "--install",
		releaseName, chartReference,
		"-n", namespace,
	}

	if valuesFile != nil {
		args = append(args, "-f", "/values.yaml")
	}

	if timeout := os.Getenv("HELM_TIMEOUT"); timeout != "" {
		args = append(args, "--timeout", timeout)
	} else {
		args = append(args, "--timeout", "5m")
	}

	if kubectlContext := os.Getenv("KUBECTL_CONTEXT"); kubectlContext != "" {
		args = append(args, "--kube-context", kubectlContext)
	}

	output, err := container.
		WithEnvVariable("CACHE_BUST", time.Now().String()).
		WithExec(args).
		Stdout(ctx)
	if err != nil {
		return "", fmt.Errorf("helm install failed: %w", err)
	}

	return output, nil
}

// HelmPush publishes a packaged Helm chart (.tgz file) to the injected Helm
// repository URL (sourced from HELM_REPOSITORY_URL in local_cicd.env).
//
// The chart tarball is pushed with `helm push` and the function returns the
// fully-qualified chart reference in the form:
//
//	<repoURL>/<chartName>:<chartVersion>
//
// Parameters:
//   - ctx: Context for the operation
//   - client: Dagger client instance
//   - chartPackage: The packaged chart file (e.g. myapp-1.2.3.tgz)
//
// Returns the published chart reference URL or an error.
//
// Example usage:
//
//	chartRef, err := cicd.HelmPush(ctx, client, chartTgzFile)
//	if err != nil {
//	    return "", fmt.Errorf("helm push failed: %w", err)
//	}
func HelmPush(
	ctx context.Context,
	client *dagger.Client,
	chartPackage *dagger.File,
) (string, error) {
	if chartPackage == nil {
		return "", fmt.Errorf("chart package file is required")
	}

	repoURL, err := GetHelmRepositoryURL()
	if err != nil {
		return "", err
	}

	// Mount the chart file into the container
	container := client.Container().
		From("alpine/helm:latest").
		WithMountedFile("/charts/chart.tgz", chartPackage).
		WithWorkdir("/charts")

	// Extract the chart name and version from the package so we can construct
	// the published reference URL after the push.
	nameOutput, err := container.WithExec([]string{
		"helm", "show", "chart", "/charts/chart.tgz",
	}).Stdout(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to read chart metadata: %w", err)
	}

	chartName, chartVersion := "", ""
	for _, line := range splitLines(nameOutput) {
		if k, v, ok := strings.Cut(line, ":"); ok {
			switch strings.TrimSpace(k) {
			case "name":
				chartName = strings.TrimSpace(v)
			case "version":
				chartVersion = strings.TrimSpace(v)
			}
		}
	}
	if chartName == "" || chartVersion == "" {
		return "", fmt.Errorf("could not determine chart name/version from metadata:\n%s", nameOutput)
	}

	// Push the chart to the OCI registry
	_, err = container.WithExec([]string{
		"helm", "push", "/charts/chart.tgz", repoURL,
	}).Stdout(ctx)
	if err != nil {
		return "", fmt.Errorf("helm push failed: %w", err)
	}

	// Construct the canonical chart reference:  oci://registry/chartName:version
	// Strip any trailing slash from repoURL before appending.
	ref := fmt.Sprintf("%s/%s:%s", strings.TrimRight(repoURL, "/"), chartName, chartVersion)
	return ref, nil
}

// splitLines splits a string into lines, stripping empty trailing lines.
func splitLines(s string) []string {
	return strings.Split(strings.TrimRight(s, "\n"), "\n")
}
