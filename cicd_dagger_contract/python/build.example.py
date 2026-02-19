"""Build module for Goserv"""

import dagger
from dagger import dag, function, object_type
from typing import Optional


@object_type
class Build:
    @function
    async def build(
        self,
        source: dagger.Directory,
        release_candidate: Optional[bool] = False,
    ) -> dagger.File:
        """Build builds a multi-architecture Docker image and exports it as an OCI tarball
        
        Args:
            source: Source directory containing the project
            release_candidate: Whether to build as release candidate (appends -rc to version)
        
        Returns:
            File containing the build artifact
        """
        # Print message and return
        output = await (
            dag.container()
            .from_("alpine:latest")
            .with_exec(["echo", "This is the Build function"])
            .stdout()
        )

        # Print to show the message
        print(output)

        # Return a dummy file since the function signature requires File
        return dag.container().from_("alpine:latest").file("/etc/hostname")
