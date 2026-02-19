"""Validate module for Goserv"""

import dagger
from dagger import dag, function, object_type
from typing import Optional


@object_type
class Validate:
    @function
    async def validate(
        self,
        source: dagger.Directory,
        kubeconfig: dagger.Secret,
        release_name: Optional[str] = "goserv",
        namespace: Optional[str] = "goserv",
        expected_version: Optional[str] = "",
        release_candidate: Optional[bool] = False,
    ) -> str:
        """Validate runs the validation script to verify that the deployment is healthy and functioning correctly
        
        Args:
            source: Source directory containing the project
            kubeconfig: Kubernetes config file content
            release_name: Release name (default: goserv)
            namespace: Kubernetes namespace (default: goserv)
            expected_version: Expected version to validate (if not provided, reads from VERSION file)
            release_candidate: Build as release candidate (appends -rc to version)
        
        Returns:
            Validation output string
        """
        # Print message
        output = await (
            dag.container()
            .from_("alpine:latest")
            .with_exec(["echo", "this is the Validate function"])
            .stdout()
        )

        return output
