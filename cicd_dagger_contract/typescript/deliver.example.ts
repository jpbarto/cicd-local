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
   * @returns Delivery output string
   */
  @func()
  async deliver(
    source: Directory,
    containerRepository: string = "ttl.sh",
    helmRepository: string = "oci://ttl.sh",
    buildArtifact?: File,
    releaseCandidate: boolean = false
  ): Promise<string> {
    // Print message
    const output = await dag
      .container()
      .from("alpine:latest")
      .withExec(["echo", "this is the Deliver function"])
      .stdout()

    return output
  }
}
