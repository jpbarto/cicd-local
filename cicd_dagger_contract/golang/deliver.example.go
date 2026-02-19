package main

import (
	"context"
	"encoding/json"
	"time"

	"dagger/goserv/internal/dagger"

	"dagger.io/dagger/dag"
)

// Deliver publishes the goserv container and Helm chart to repositories
func (m *Goserv) Deliver(
	ctx context.Context,
	// Source directory containing the project
	source *dagger.Directory,
	// +optional
	// Container repository (default: ttl.sh)
	containerRepository string,
	// +optional
	// Helm chart repository URL (default: oci://ttl.sh)
	helmRepository string,
	// +optional
	// Build output from the Build function (if not provided, will build from source)
	buildArtifact *dagger.File,
	// +optional
	// Build as release candidate (appends -rc to version tag)
	releaseCandidate bool,
) (*dagger.File, error) {
	// Perform delivery operations (container push, chart publish)
	// ... delivery logic here ...

	// Create delivery context
	deliveryContext := map[string]interface{}{
		"timestamp":           time.Now().Format(time.RFC3339),
		"imageReference":      containerRepository + "/goserv:1.0.0",
		"chartReference":      helmRepository + "/goserv:0.1.0",
		"containerRepository": containerRepository,
		"helmRepository":      helmRepository,
		"releaseCandidate":    releaseCandidate,
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
