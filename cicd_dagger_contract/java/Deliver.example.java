package cicd;

import io.dagger.client.Container;
import io.dagger.client.Dagger;
import io.dagger.client.Directory;
import io.dagger.client.File;

public class Deliver {

    /**
     * Deliver publishes the goserv container and Helm chart to repositories
     *
     * @param source Source directory containing the project
     * @param containerRepository Container repository (default: ttl.sh)
     * @param helmRepository Helm chart repository URL (default: oci://ttl.sh)
     * @param buildArtifact Build output from the Build function (if not provided, will build from source)
     * @param releaseCandidate Build as release candidate (appends -rc to version tag)
     * @return Delivery output string
     */
    public String deliver(
            Directory source,
            String containerRepository,
            String helmRepository,
            File buildArtifact,
            boolean releaseCandidate) throws Exception {
        // Print message
        String output = Dagger.dag().container()
            .from("alpine:latest")
            .withExec(new String[]{"echo", "this is the Deliver function"})
            .stdout();

        return output;
    }
}
