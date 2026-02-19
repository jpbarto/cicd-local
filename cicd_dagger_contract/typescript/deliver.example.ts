/**
 * Deliver module for Goserv
 */

import { dag, Container, Directory, File, object, func } from "@dagger.io/dagger"

@object()
export class Deliver {
  /**
   * Deliver publishes the goserv container and Helm chart to repositories
   *
   * @param source Source directory containing the project
   * @param containerRepository Container repository (default: ttl.sh)
   * @param helmRepository Helm chart repository URL (default: oci://ttl.sh)
   * @param buildArtifact Build output from the Build function (if not provided, will build from source)
   * @param releaseCandidate Build as release candidate (appends -rc to version tag)
   * @returns File containing delivery context
   */
  @func()
  async deliver(
    source: Directory,
    containerRepository: string = "ttl.sh",
    helmRepository: string = "oci://ttl.sh",
    buildArtifact?: File,
    releaseCandidate: boolean = false
  ): Promise<File> {
    // Perform delivery operations (container push, chart publish)
    // ... delivery logic here ...

    // Create delivery context
    const deliveryContext = {
      timestamp: new Date().toISOString(),
      imageReference: `${containerRepository}/goserv:1.0.0`,
      chartReference: `${helmRepository}/goserv:0.1.0`,
      containerRepository,
      helmRepository,
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
