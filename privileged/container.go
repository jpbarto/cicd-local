package cicd

import (
	"context"
	"fmt"
	"strings"
	"time"

	"dagger.io/dagger"
)

// craneImage is the container image used to publish OCI image tarballs.
// crane (github.com/google/go-containerregistry) can push a tarball directly
// to a registry without requiring a Docker daemon.
const craneImage = "gcr.io/go-containerregistry/crane:latest"

// ContainerPush publishes an OCI image tarball to the injected container
// registry (sourced from CONTAINER_REPOSITORY_URL in local_cicd.env).
//
// The tarball is the export format produced by `docker save`, `crane export`,
// or Dagger's Container.Export(). The caller provides the image name and
// primary tag; the function constructs the full registry reference, pushes
// the image, and then re-tags it with any additional tags (e.g. "latest" or
// a floating "major.minor" tag).
//
// Parameters:
//   - ctx: Context for the operation
//   - client: Dagger client instance
//   - imageExport: OCI image tarball file (e.g. produced by Container.Export())
//   - imageName: Repository/image name without registry prefix (e.g. "myapp")
//   - imageTag: Primary tag (e.g. "1.2.3")
//   - additionalTags: Extra tags to apply after the push (e.g. []string{"latest", "1.2"}).
//     Pass nil or an empty slice to skip additional tagging.
//
// Returns the primary published image reference in the form:
//
//	<registryURL>/<imageName>:<imageTag>
//
// Example usage:
//
//	imageRef, err := cicd.ContainerPush(ctx, client, exportedFile, "myapp", version, []string{"latest"})
//	if err != nil {
//	    return "", fmt.Errorf("container push failed: %w", err)
//	}
func ContainerPush(
	ctx context.Context,
	client *dagger.Client,
	imageExport *dagger.File,
	imageName string,
	imageTag string,
	additionalTags []string,
) (string, error) {
	if imageExport == nil {
		return "", fmt.Errorf("image export file is required")
	}
	if imageName == "" {
		return "", fmt.Errorf("image name is required")
	}
	if imageTag == "" {
		return "", fmt.Errorf("image tag is required")
	}

	registryURL, err := GetContainerRepositoryURL()
	if err != nil {
		return "", err
	}

	registry := strings.TrimRight(registryURL, "/")

	// Build the primary destination reference
	primaryRef := fmt.Sprintf("%s/%s:%s", registry, imageName, imageTag)

	// Use a single container instance so crane is only pulled once.
	// The crane image runs as uid/gid 65532 (distroless nonroot). WithFile
	// defaults to root ownership, so we set the file world-readable (0444)
	// to avoid "permission denied" when crane tries to open the tarball.
	// base := client.Container().
	// 	From(craneImage).
	// 	WithFile("/export.tar", imageExport, dagger.ContainerWithFileOpts{
	// 		Permissions: 0444,
	// 	})
	ctr := client.Container().Import(imageExport)

	// Push the tarball to the primary tag
	published, err := ctr.
		WithEnvVariable("CACHE_BUST", time.Now().String()).
		Publish(ctx, primaryRef)
	if err != nil {
		return "", fmt.Errorf("container push failed for %s: %w", primaryRef, err)
	}

	// Apply additional tags by copying the manifest within the registry
	// (crane tag is a cheap registry-side operation; no re-upload needed)
	for _, tag := range additionalTags {
		if tag == "" {
			continue
		}
		additionalRef := fmt.Sprintf("%s/%s:%s", registry, imageName, tag)
		_, err = ctr.
			WithEnvVariable("CACHE_BUST", time.Now().String()).
			Publish(ctx, additionalRef)
		if err != nil {
			return "", fmt.Errorf("container tag failed for %s: %w", additionalRef, err)
		}
	}

	return published, nil
}
