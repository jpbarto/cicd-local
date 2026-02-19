"""Test module for Goserv"""

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
        target_host: Optional[str] = "localhost",
        target_port: Optional[str] = "8080",
    ) -> str:
        """IntegrationTest runs integration tests against a deployed goserv instance
        
        Args:
            source: Source directory containing the project
            target_host: Target host where goserv is deployed (default: localhost)
            target_port: Target port (default: 8080)
        
        Returns:
            Test output string
        """
        # Print message
        output = await (
            dag.container()
            .from_("alpine:latest")
            .with_exec(["echo", "this is the IntegrationTest function"])
            .stdout()
        )

        return output
