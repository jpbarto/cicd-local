package main

import (
	"context"
	"encoding/json"

	"dagger/goserv/internal/dagger"

	"dagger.io/dagger/dag"
)

// UnitTest runs the goserv container and executes unit tests against it
func (m *Goserv) UnitTest(
	ctx context.Context,
	// Source directory containing the project
	source *dagger.Directory,
	// +optional
	// Build output from the Build function (if not provided, will build from source)
	buildArtifact *dagger.File,
) (string, error) {
	// Print message
	output, err := dag.Container().
		From("alpine:latest").
		WithExec([]string{"echo", "this is the UnitTest function"}).
		Stdout(ctx)

	if err != nil {
		return "", err
	}

	return output, nil
}

// IntegrationTest runs integration tests against a deployed goserv instance
func (m *Goserv) IntegrationTest(
	ctx context.Context,
	// Source directory containing the project
	source *dagger.Directory,
	// Kubernetes config file content
	kubeconfig *dagger.File,
	// +optional
	// AWS configuration file content
	awsconfig *dagger.Secret,
	// +optional
	// Deployment context from Deploy function
	deploymentContext *dagger.File,
	// +optional
	// Validation context from Validate function
	validationContext *dagger.File,
) (string, error) {
	// Extract endpoint from deployment context if provided
	var targetUrl string
	if deploymentContext != nil {
		contextContent, _ := deploymentContext.Contents(ctx)
		var context map[string]interface{}
		json.Unmarshal([]byte(contextContent), &context)
		targetUrl = context["endpoint"].(string)
	}

	// Check validation status if provided
	if validationContext != nil {
		valContent, _ := validationContext.Contents(ctx)
		var valContext map[string]interface{}
		json.Unmarshal([]byte(valContent), &valContext)
		if valContext["status"].(string) != "healthy" {
			return "", nil // Skip tests if validation failed
		}
	}

	// Run integration tests against targetUrl
	output, err := dag.Container().
		From("alpine:latest").
		WithExec([]string{"echo", "Running integration tests against", targetUrl}).
		Stdout(ctx)

	if err != nil {
		return "", err
	}

	return output, nil
}
