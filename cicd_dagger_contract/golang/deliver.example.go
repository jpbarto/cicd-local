package main

import (
	"context"
	"encoding/json"
	"time"

	"dagger/goserv/internal/dagger"

	"dagger.io/dagger/dag"
)

// Deliver publishes the goserv container and Helm chart to repositories.
// Repository URLs are sourced from injected secrets (see cicd/internal/cicd/secrets.go).
func (m *Goserv) Deliver(
	ctx context.Context,
	// Source directory containing the project
	source *dagger.Directory,
	// +optional
	// Build output from the Build function (if not provided, will build from source)
	buildArtifact *dagger.File,
	// +optional
	// Build as release candidate (appends -rc to version tag)
	releaseCandidate bool,
) (*dagger.File, error) {
	// Perform delivery operations (container push, chart publish)
	// Use cicd.ContainerPush() and cicd.HelmPush() from cicd/internal/cicd
	// to push artifacts - repository URLs are injected at runtime.
	// ... delivery logic here ...

	// Create delivery context
	deliveryContext := map[string]interface{}{
		"timestamp":        time.Now().Format(time.RFC3339),
		"releaseCandidate": releaseCandidate,
	}

	contextJSON, err := json.MarshalIndent(deliveryContext, "", "  ")
	if err != nil {
		return nil, err
	}

	// Return as file
	return dag.Directory().
		WithNewFile("delivery-context.json", string(contextJSON)).
		File("delivery-context.json"), nil
}
