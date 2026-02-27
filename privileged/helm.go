package cicd

import (
	"context"
	"fmt"
	"os"
	"strings"

	"dagger.io/dagger"
)

// HelmInstall installs or upgrades a Helm chart.
// This function performs a Helm install/upgrade operation with the provided configuration.
//
// Parameters:
//   - ctx: Context for the operation
//   - client: Dagger client instance
//   - releaseName: Name of the Helm release
//   - chartPath: Directory containing the Helm chart or chart reference (e.g., "stable/nginx")
//   - namespace: Kubernetes namespace to install into
//   - valuesFile: Optional directory containing values.yaml file (can be nil)
//   - kubeconfig: Dagger secret containing kubeconfig content
//
// Environment variables:
//   - HELM_TIMEOUT: Timeout for helm operations (default: 5m)
//   - KUBECTL_CONTEXT: Kubernetes context to use (optional)
//
// Returns the helm install output as a string.
//
// Example usage:
//
//	kubeconfigSecret, err := privileged.LoadKubeconfig(ctx, client, "")
//	output, err := privileged.HelmInstall(ctx, client, "myapp", chartDir, "default", valuesDir, kubeconfigSecret)
//	if err != nil {
//	    return "", fmt.Errorf("helm install failed: %w", err)
//	}
func HelmInstall(
	ctx context.Context,
	client *dagger.Client,
	releaseName string,
	chartPath *dagger.Directory,
	namespace string,
	valuesFile *dagger.Directory,
	kubeconfig *dagger.Secret,
) (string, error) {
	if releaseName == "" {
		return "", fmt.Errorf("release name is required")
	}
	if chartPath == nil {
		return "", fmt.Errorf("chart path is required")
	}
	if namespace == "" {
		return "", fmt.Errorf("namespace is required")
	}
	if kubeconfig == nil {
		return "", fmt.Errorf("kubeconfig secret is required")
	}

	// Start with Helm container
	container := client.Container().
		From("alpine/helm:latest").
		WithMountedDirectory("/chart", chartPath).
		WithMountedSecret("/root/.kube/config", kubeconfig)

	// Add values file if provided
	if valuesFile != nil {
		container = container.WithMountedDirectory("/values", valuesFile)
	}

	// Build helm command
	args := []string{
		"helm", "upgrade", "--install",
		releaseName, "/chart",
		"-n", namespace,
		"--create-namespace",
	}

	// Add values file if provided
	if valuesFile != nil {
		args = append(args, "-f", "/values/values.yaml")
	}

	// Add timeout if specified
	if timeout := os.Getenv("HELM_TIMEOUT"); timeout != "" {
		args = append(args, "--timeout", timeout)
	} else {
		args = append(args, "--timeout", "5m")
	}

	// Add context if specified
	if kubectlContext := os.Getenv("KUBECTL_CONTEXT"); kubectlContext != "" {
		args = append(args, "--kube-context", kubectlContext)
	}

	// Execute helm install/upgrade
	output, err := container.WithExec(args).Stdout(ctx)
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

// HelmUpgrade upgrades an existing Helm release.
// This function performs a Helm upgrade operation for an already installed release.
//
// Parameters:
//   - ctx: Context for the operation
//   - client: Dagger client instance
//   - releaseName: Name of the Helm release to upgrade
//   - chartReference: Chart reference (can be a repo/chart or local path)
//   - namespace: Kubernetes namespace containing the release
//   - kubeconfig: Dagger secret containing kubeconfig content
//
// Environment variables:
//   - HELM_TIMEOUT: Timeout for helm operations (default: 5m)
//   - KUBECTL_CONTEXT: Kubernetes context to use (optional)
//
// Returns the helm upgrade output as a string.
//
// Example usage:
//
//	kubeconfigSecret, err := privileged.LoadKubeconfig(ctx, client, "")
//	output, err := privileged.HelmUpgrade(ctx, client, "myapp", "bitnami/nginx", "production", kubeconfigSecret)
//	if err != nil {
//	    return "", fmt.Errorf("helm upgrade failed: %w", err)
//	}
func HelmUpgrade(
	ctx context.Context,
	client *dagger.Client,
	releaseName string,
	chartReference string,
	namespace string,
	kubeconfig *dagger.Secret,
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
	if kubeconfig == nil {
		return "", fmt.Errorf("kubeconfig secret is required")
	}

	// Start with Helm container
	container := client.Container().
		From("alpine/helm:latest").
		WithMountedSecret("/root/.kube/config", kubeconfig)

	// Build helm upgrade command
	args := []string{
		"helm", "upgrade",
		releaseName, chartReference,
		"-n", namespace,
	}

	// Add timeout if specified
	if timeout := os.Getenv("HELM_TIMEOUT"); timeout != "" {
		args = append(args, "--timeout", timeout)
	} else {
		args = append(args, "--timeout", "5m")
	}

	// Add context if specified
	if kubectlContext := os.Getenv("KUBECTL_CONTEXT"); kubectlContext != "" {
		args = append(args, "--kube-context", kubectlContext)
	}

	// Execute helm upgrade
	output, err := container.WithExec(args).Stdout(ctx)
	if err != nil {
		return "", fmt.Errorf("helm upgrade failed: %w", err)
	}

	return output, nil
}

// splitLines splits a string into lines, stripping empty trailing lines.
func splitLines(s string) []string {
	return strings.Split(strings.TrimRight(s, "\n"), "\n")
}
