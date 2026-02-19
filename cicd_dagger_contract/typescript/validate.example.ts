/**
 * Validate module for Goserv
 */

import { dag, Container, Directory, Secret, object, func } from "@dagger.io/dagger"

@object()
export class Validate {
  /**
   * Validate runs the validation script to verify that the deployment is healthy and functioning correctly
   *
   * @param source Source directory containing the project
   * @param kubeconfig Kubernetes config file content
   * @param releaseName Release name (default: goserv)
   * @param namespace Kubernetes namespace (default: goserv)
   * @param expectedVersion Expected version to validate (if not provided, reads from VERSION file)
   * @param releaseCandidate Build as release candidate (appends -rc to version)
   * @returns Validation output string
   */
  @func()
  async validate(
    source: Directory,
    kubeconfig: Secret,
    releaseName: string = "goserv",
    namespace: string = "goserv",
    expectedVersion: string = "",
    releaseCandidate: boolean = false
  ): Promise<string> {
    // Print message
    const output = await dag
      .container()
      .from("alpine:latest")
      .withExec(["echo", "this is the Validate function"])
      .stdout()

    return output
  }
}
