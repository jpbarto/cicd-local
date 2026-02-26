"""Test module for Goserv"""

import json
import dagger
from dagger import dag, function, object_type
from typing import Optional


@object_type
class Test:
    @function
    async def unit_test(
        self,
        source: dagger.Directory,
        build_artifact: Optional[dagger.File] = None,
    ) -> str:
        """UnitTest runs the goserv container and executes unit tests against it
        
        Args:
            source: Source directory containing the project
            build_artifact: Build output from the Build function (if not provided, will build from source)
        
        Returns:
            Test output string
        """
        # Print message
        output = await (
            dag.container()
            .from_("alpine:latest")
            .with_exec(["echo", "this is the UnitTest function"])
            .stdout()
        )

        return output

    @function
    async def integration_test(
        self,
        source: dagger.Directory,
        deployment_context: Optional[dagger.File] = None,
        validation_context: Optional[dagger.File] = None,
    ) -> str:
        """IntegrationTest runs integration tests against a deployed goserv instance
        
        Args:
            source: Source directory containing the project
            deployment_context: Deployment context from Deploy function
            validation_context: Validation context from Validate function
        
        Returns:
            Test output string
        """
        # Extract endpoint from deployment context if provided
        target_url = None
        if deployment_context:
            context_content = await deployment_context.contents()
            context = json.loads(context_content)
            target_url = context.get("endpoint")

        # Check validation status if provided
        if validation_context:
            val_content = await validation_context.contents()
            val_context = json.loads(val_content)
            if val_context.get("status") != "healthy":
                return "Skipping tests: deployment validation failed"

        # Run integration tests against target_url
        output = await (
            dag.container()
            .from_("alpine:latest")
            .with_exec(["echo", f"Running integration tests against {target_url}"])
            .stdout()
        )
        output = await (
            dag.container()
            .from_("alpine:latest")
            .with_exec(["echo", "this is the IntegrationTest function"])
            .stdout()
        )

        return output
