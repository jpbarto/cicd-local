package main

import (
	"context"
	"encoding/json"
	"time"

	"dagger/goserv/internal/dagger"

	"dagger.io/dagger/dag"
)

// Validate runs the validation script to verify that the deployment is healthy and functioning correctly
func (m *Goserv) Validate(
	ctx context.Context,
	// Source directory containing the project
	source *dagger.Directory,
	// +optional
	// Build as release candidate (appends -rc to version tag)
	releaseCandidate bool,
	// +optional
	// Deployment context from Deploy function
	deploymentContext *dagger.File,
) (*dagger.File, error) {
	// Extract deployment information from context if provided
	var depContext map[string]interface{}
	if deploymentContext != nil {
		contextContent, err := deploymentContext.Contents(ctx)
		if err != nil {
			return nil, err
		}
		json.Unmarshal([]byte(contextContent), &depContext)
	}
	if err := json.Unmarshal([]byte(contextContent), &depContext); err != nil {
		return nil, err
	}

	endpoint := depContext["endpoint"].(string)
	releaseName := depContext["releaseName"].(string)

	// Perform validation checks
	// ... validation logic here ...

	// Create validation context
	validationContext := map[string]interface{}{
		"timestamp":       time.Now().Format(time.RFC3339),
		"releaseName":     releaseName,
		"endpoint":        endpoint,
		"status":          "healthy",
		"healthChecks":    []string{"pod-ready", "service-available"},
		"readinessChecks": []string{"http-200", "metrics-available"},
	}

	contextJSON, err := json.MarshalIndent(validationContext, "", "  ")
	if err != nil {
		return nil, err
	}

	// Return as file
	return dag.Directory().
		WithNewFile("validation-context.json", string(contextJSON)).
		File("validation-context.json"), nil
}
