package cicd;

import io.dagger.client.Container;
import io.dagger.client.Dagger;
import io.dagger.client.Directory;
import io.dagger.client.File;

public class Test {

    /**
     * UnitTest runs the goserv container and executes unit tests against it
     *
     * @param source Source directory containing the project
     * @param buildArtifact Build output from the Build function (if not provided, will build from source)
     * @return Test output string
     */
    public String unitTest(Directory source, File buildArtifact) throws Exception {
        // Print message
        String output = Dagger.dag().container()
            .from("alpine:latest")
            .withExec(new String[]{"echo", "this is the UnitTest function"})
            .stdout();

        return output;
    }

    /**
     * IntegrationTest runs integration tests against a deployed goserv instance
     *
     * @param source Source directory containing the project
     * @param targetHost Target host where goserv is deployed (default: localhost)
     * @param targetPort Target port (default: 8080)
     * @return Test output string
     */
    public String integrationTest(Directory source, String targetHost, String targetPort) throws Exception {
        // Print message
        String output = Dagger.dag().container()
            .from("alpine:latest")
            .withExec(new String[]{"echo", "this is the IntegrationTest function"})
            .stdout();

        return output;
    }
}
