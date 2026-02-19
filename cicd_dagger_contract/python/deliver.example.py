"""Deliver module for Goserv"""

import dagger
from dagger import dag, function, object_type
from typing import Optional


@object_type
class Deliver:
    @function
    async def deliver(
        self,
        source: dagger.Directory,
        container_repository: Optional[str] = "ttl.sh",
        helm_repository: Optional[str] = "oci://ttl.sh",
        build_artifact: Optional[dagger.File] = None,
        release_candidate: Optional[bool] = False,
    ) -> str:
        """Deliver publishes the goserv container and Helm chart to repositories
        
        Args:
            source: Source directory containing the project
            container_repository: Container repository (default: ttl.sh)
            helm_repository: Helm chart repository URL (default: oci://ttl.sh)
            build_artifact: Build output from the Build function (if not provided, will build from source)
            release_candidate: Build as release candidate (appends -rc to version tag)
        
        Returns:
            Delivery output string
        """
        # Print message
        output = await (
            dag.container()
            .from_("alpine:latest")
            .with_exec(["echo", "this is the Deliver function"])
            .stdout()
        )

        return output
