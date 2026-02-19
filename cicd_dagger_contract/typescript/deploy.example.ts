/**
 * Deploy module for Goserv
 */

import { dag, Container, Directory, Secret, object, func } from "@dagger.io/dagger"

@object()
export class Deploy {
  /**
   * Deploy installs the Helm chart from a Helm repository to a Kubernetes cluster
   * Note: This function should have cache = "never" configuration
   *
   * @param source Source directory containing the project
   * @param awsconfig AWS configuration file content
   * @param kubeconfig Kubernetes config file content
   * @param helmRepository Helm chart repository URL (default: oci://ttl.sh)
   * @param containerRepository Container repository URL (default: ttl.sh)
   * @param releaseCandidate Build as release candidate (appends -rc to version tag)
   * @returns Deployment output string
   */
  @func()
  async deploy(
    source: Directory,
    awsconfig?: Secret,
    kubeconfig?: Secret,
    helmRepository: string = "oci://ttl.sh",
    containerRepository: string = "ttl.sh",
    releaseCandidate: boolean = false
  ): Promise<string> {
    // Print message
    const output = await dag
      .container()
      .from("alpine:latest")
      .withExec(["echo", "this is the Deploy function"])
      .stdout()

    return output
  }
}
