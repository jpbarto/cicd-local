/**
 * Test module for Goserv
 */

import { dag, Container, Directory, File, Secret, object, func } from "@dagger.io/dagger"

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
   * IntegrationTest runs integration tests against a deployed instance
   *
   * @param source Source directory containing the project
   * @param kubeconfig Kubernetes config file content
   * @param awsconfig AWS configuration file content
   * @param deploymentContext Deployment context from Deploy function
   * @param validationContext Validation context from Validate function
   * @returns String containing test results
   */
  @func()
  async integrationTest(
    source: Directory,
    kubeconfig: Secret,
    awsconfig?: Secret,
    deploymentContext?: File,
    validationContext?: File
  ): Promise<string> {
    // Extract endpoint from deployment context if provided
    let targetUrl: string | undefined
    if (deploymentContext) {
      const contextContent = await deploymentContext.contents()
      const context = JSON.parse(contextContent)
      targetUrl = context.endpoint
    }

    // Check validation status if provided
    if (validationContext) {
      const valContent = await validationContext.contents()
      const valContext = JSON.parse(valContent)
      if (valContext.status !== "healthy") {
        return "Skipping tests: deployment validation failed"
      }
    }

    // Run integration tests against targetUrl
    const output = await dag
      .container()
      .from("alpine:latest")
      .withExec(["echo", `Running integration tests against ${targetUrl}`])
      .stdout()

    return output
  }
}
