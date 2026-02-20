"""Deploy module for Goserv"""

import json
from datetime import datetime
import dagger
from dagger import dag, function, object_type
from typing import Optional


@object_type
class Deploy:
    @function
    async def deploy(
        self,
        source: dagger.Directory,
        kubeconfig: Optional[dagger.File] = None,
        awsconfig: Optional[dagger.Secret] = None,
        helm_repository: Optional[str] = "oci://ttl.sh",
        container_repository: Optional[str] = "ttl.sh",
        release_candidate: Optional[bool] = False,
    ) -> dagger.File:
        """Deploy installs the Helm chart from a Helm repository to a Kubernetes cluster
        
        Note: This function should have cache = "never" configuration
        
        Args:
            source: Source directory containing the project
            kubeconfig: Kubernetes config file content
            awsconfig: AWS configuration file content
            helm_repository: Helm chart repository URL (default: oci://ttl.sh)
            container_repository: Container repository URL (default: ttl.sh)
            release_candidate: Build as release candidate (appends -rc to version tag)
        
        Returns:
            File containing deployment context
        """
        # Perform deployment (helm install/upgrade)
        # ... deployment logic here ...

        # Create deployment context
        deployment_context = {
            "timestamp": datetime.now().isoformat(),
            "endpoint": "http://goserv.default.svc.cluster.local:8080",
            "releaseName": "goserv",
            "namespace": "default",
            "chartVersion": "0.1.0",
            "imageReference": image_ref,
        }

        context_json = json.dumps(deployment_context, indent=2)

        # Return as file
        return (
            dag.directory()
            .with_new_file("deployment-context.json", context_json)
            .file("deployment-context.json")
        )
