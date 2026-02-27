/**
 * Deliver module for Goserv
 */

import { dag, Container, Directory, File, object, func } from "@dagger.io/dagger"

@object()
export class Deliver {
  /**
   * Deliver publishes the goserv container and Helm chart to repositories.
   * Repository URLs are sourced from injected secrets (see cicd/internal/cicd/secrets.go).
   *
   * @param source Source directory containing the project
   * @param buildArtifact Build output from the Build function (if not provided, will build from source)
   * @param releaseCandidate Build as release candidate (appends -rc to version tag)
   * @returns File containing delivery context
   */
  @func()
  async deliver(
    source: Directory,
    buildArtifact?: File,
    releaseCandidate: boolean = false
  ): Promise<File> {
    // Perform delivery operations (container push, chart publish)
    // Use cicd.ContainerPush() and cicd.HelmPush() from cicd/internal/cicd
    // to push artifacts - repository URLs are injected at runtime.
    // ... delivery logic here ...

    // Create delivery context
    const deliveryContext = {
      timestamp: new Date().toISOString(),
      releaseCandidate,
    }

    const contextJson = JSON.stringify(deliveryContext, null, 2)

    // Return as file
    return dag
      .directory()
      .withNewFile("delivery-context.json", contextJson)
      .file("delivery-context.json")
  }
}
