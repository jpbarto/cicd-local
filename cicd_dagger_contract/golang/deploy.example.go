package main

import (
	"context"
	"encoding/json"
	"time"

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
	// Kubernetes config file content
	kubeconfig *dagger.Secret,
	// +optional
	// AWS configuration file content
	awsconfig *dagger.Secret,
	// +optional
	// Helm chart repository URL (default: oci://ttl.sh)
	helmRepository string,
	// +optional
	// Container repository URL (default: ttl.sh)
	containerRepository string,
	// +optional
	// Build as release candidate (appends -rc to version tag)
	releaseCandidate bool,
) (*dagger.File, error) {
	// Perform deployment (helm install/upgrade)
	// ... deployment logic here ...

	// Create deployment context
	deploymentContext := map[string]interface{}{
		"timestamp":      time.Now().Format(time.RFC3339),
		"endpoint":       "http://goserv.default.svc.cluster.local:8080",
		"releaseName":    "goserv",
		"namespace":      "default",
		"chartVersion":   "0.1.0",
		"imageReference": imageRef,
	}

	contextJSON, err := json.MarshalIndent(deploymentContext, "", "  ")
	if err != nil {
		return nil, err
	}

	// Return as file
	return dag.Directory().
		WithNewFile("deployment-context.json", string(contextJSON)).
		File("deployment-context.json"), nil
}
