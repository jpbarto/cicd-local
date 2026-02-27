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
        build_artifact: Optional[dagger.File] = None,
        release_candidate: Optional[bool] = False,
    ) -> dagger.File:
        """Deliver publishes the goserv container and Helm chart to repositories.
        Repository URLs are sourced from injected secrets (see cicd/internal/cicd/secrets.go).
        
        Args:
            source: Source directory containing the project
            build_artifact: Build output from the Build function (if not provided, will build from source)
            release_candidate: Build as release candidate (appends -rc to version tag)
        
        Returns:
            File containing delivery context
        """
        # Perform delivery operations (container push, chart publish)
        # Use cicd.container_push() and cicd.helm_push() from cicd/internal/cicd
        # to push artifacts - repository URLs are injected at runtime.
        # ... delivery logic here ...

        # Create delivery context
        delivery_context = {
            "timestamp": datetime.now().isoformat(),
            "releaseCandidate": release_candidate,
        }

        context_json = json.dumps(delivery_context, indent=2)

        # Return as file
        return (
            dag.directory()
            .with_new_file("delivery-context.json", context_json)
            .file("delivery-context.json")
        )
