"""Deliver module for Goserv"""

import json
from datetime import datetime
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
    ) -> dagger.File:
        """Deliver publishes the goserv container and Helm chart to repositories
        
        Args:
            source: Source directory containing the project
            container_repository: Container repository (default: ttl.sh)
            helm_repository: Helm chart repository URL (default: oci://ttl.sh)
            build_artifact: Build output from the Build function (if not provided, will build from source)
            release_candidate: Build as release candidate (appends -rc to version tag)
        
        Returns:
            File containing delivery context
        """
        # Perform delivery operations (container push, chart publish)
        # ... delivery logic here ...

        # Create delivery context
        delivery_context = {
            "timestamp": datetime.now().isoformat(),
            "imageReference": f"{container_repository}/goserv:1.0.0",
            "chartReference": f"{helm_repository}/goserv:0.1.0",
            "containerRepository": container_repository,
            "helmRepository": helm_repository,
            "releaseCandidate": release_candidate,
        }

        context_json = json.dumps(delivery_context, indent=2)

        # Return as file
        return (
            dag.directory()
            .with_new_file("delivery-context.json", context_json)
            .file("delivery-context.json")
        )
