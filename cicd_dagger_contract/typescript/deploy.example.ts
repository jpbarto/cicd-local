/**
 * Deploy module for Goserv
 */

import { dag, Container, Directory, File, Secret, object, func } from "@dagger.io/dagger"

@object()
export class Deploy {
  /**
   * Deploy installs the Helm chart from a Helm repository to a Kubernetes cluster
   * Note: This function should have cache = "never" configuration
   *
   * @param source Source directory containing the project
   * @param kubeconfig Kubernetes config file content
   * @param awsconfig AWS configuration file content
   * @param helmRepository Helm chart repository URL (default: oci://ttl.sh)
   * @param containerRepository Container repository URL (default: ttl.sh)
   * @param deliveryContext Delivery context from Deliver function
   * @param releaseCandidate Build as release candidate (appends -rc to version tag)
   * @returns File containing deployment context
   */
  @func()
  async deploy(
    source: Directory,
    kubeconfig?: File,
    awsconfig?: Secret,
    helmRepository: string = "oci://ttl.sh",
    containerRepository: string = "ttl.sh",
    deliveryContext?: File,
    releaseCandidate: boolean = false
  ): Promise<File> {
    // Extract info from delivery context if provided
    let imageRef: string | undefined
    let chartRef: string | undefined
    if (deliveryContext) {
      const contextContent = await deliveryContext.contents()
      const delContext = JSON.parse(contextContent)
      imageRef = delContext.imageReference
      chartRef = delContext.chartReference
    }

    // Perform deployment (helm install/upgrade)
    // ... deployment logic here ...

    // Create deployment context
    const deploymentContext = {
      timestamp: new Date().toISOString(),
      endpoint: "http://goserv.default.svc.cluster.local:8080",
      releaseName: "goserv",
      namespace: "default",
      chartVersion: "0.1.0",
      imageReference: imageRef,
    }

    const contextJson = JSON.stringify(deploymentContext, null, 2)

    // Return as file
    return dag
      .directory()
      .withNewFile("deployment-context.json", contextJson)
      .file("deployment-context.json")
  }
}
