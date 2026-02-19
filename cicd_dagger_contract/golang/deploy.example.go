package main

import (
	"context"

	"dagger/goserv/internal/dagger"

	"dagger.io/dagger/dag"
)

// Deploy installs the Helm chart from a Helm repository to a Kubernetes cluster
// +cache = "never"
func (m *Goserv) Deploy(
	ctx context.Context,
	// Source directory containing the project
	source *dagger.Directory,
	// +optional
	// AWS configuration file content
	awsconfig *dagger.Secret,
	// +optional
	// Kubernetes config file content
	kubeconfig *dagger.Secret,
	// +optional
	// Helm chart repository URL (default: oci://ttl.sh)
	helmRepository string,
	// +optional
	// Container repository URL (default: ttl.sh)
	containerRepository string,
	// +optional
	// Build as release candidate (appends -rc to version tag)
	releaseCandidate bool,
) (string, error) {
	// Print message
	output, err := dag.Container().
		From("alpine:latest").
		WithExec([]string{"echo", "this is the Deploy function"}).
		Stdout(ctx)

	if err != nil {
		return "", err
	}

	return output, nil
}
