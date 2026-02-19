/**
 * Build module for Goserv
 */

import { dag, Container, Directory, File, object, func } from "@dagger.io/dagger"

@object()
export class Build {
  /**
   * Build builds a multi-architecture Docker image and exports it as an OCI tarball
   *
   * @param source Source directory containing the project
   * @param releaseCandidate Whether to build as release candidate (appends -rc to version)
   * @returns File containing the build artifact
   */
  @func()
  async build(
    source: Directory,
    releaseCandidate: boolean = false
  ): Promise<File> {
    // Print message and return
    const output = await dag
      .container()
      .from("alpine:latest")
      .withExec(["echo", "This is the Build function"])
      .stdout()

    // Print to show the message
    console.log(output)

    // Return a dummy file since the function signature requires File
    return dag.container().from("alpine:latest").file("/etc/hostname")
  }
}
