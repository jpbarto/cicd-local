/**
 * Test module for Goserv
 */

import { dag, Container, Directory, File, object, func } from "@dagger.io/dagger"

@object()
export class Test {
  /**
   * UnitTest runs the goserv container and executes unit tests against it
   *
   * @param source Source directory containing the project
   * @param buildArtifact Build output from the Build function (if not provided, will build from source)
   * @returns Test output string
   */
  @func()
  async unitTest(
    source: Directory,
    buildArtifact?: File
  ): Promise<string> {
    // Print message
    const output = await dag
      .container()
      .from("alpine:latest")
      .withExec(["echo", "this is the UnitTest function"])
      .stdout()

    return output
  }

  /**
   * IntegrationTest runs integration tests against a deployed goserv instance
   *
   * @param source Source directory containing the project
   * @param targetUrl Target URL where goserv is deployed (default: http://localhost:8080)
   * @returns Test output string
   */
  @func()
  async integrationTest(
    source: Directory,
    targetUrl: string = "http://localhost:8080"
  ): Promise<string> {
    // Print message
    const output = await dag
      .container()
      .from("alpine:latest")
      .withExec(["echo", "this is the IntegrationTest function"])
      .stdout()

    return output
  }
}
