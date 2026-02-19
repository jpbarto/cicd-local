"""Deploy module for Goserv"""

import dagger
from dagger import dag, function, object_type
from typing import Optional


@object_type
class Deploy:
    @function
    async def deploy(
        self,
        source: dagger.Directory,
        awsconfig: Optional[dagger.Secret] = None,
        kubeconfig: Optional[dagger.Secret] = None,
        helm_repository: Optional[str] = "oci://ttl.sh",
        container_repository: Optional[str] = "ttl.sh",
        release_candidate: Optional[bool] = False,
    ) -> str:
        """Deploy installs the Helm chart from a Helm repository to a Kubernetes cluster
        
        Note: This function should have cache = "never" configuration
        
        Args:
            source: Source directory containing the project
            awsconfig: AWS configuration file content
            kubeconfig: Kubernetes config file content
            helm_repository: Helm chart repository URL (default: oci://ttl.sh)
            container_repository: Container repository URL (default: ttl.sh)
            release_candidate: Build as release candidate (appends -rc to version tag)
        
        Returns:
            Deployment output string
        """
        # Print message
        output = await (
            dag.container()
            .from_("alpine:latest")
            .with_exec(["echo", "this is the Deploy function"])
            .stdout()
        )

        return output
