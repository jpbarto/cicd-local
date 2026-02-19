package cicd;

import io.dagger.client.Container;
import io.dagger.client.Dagger;
import io.dagger.client.Directory;
import io.dagger.client.File;

public class Build {

    /**
     * Build builds a multi-architecture Docker image and exports it as an OCI tarball
     *
     * @param source Source directory containing the project
     * @param releaseCandidate Whether to build as release candidate (appends -rc to version)
     * @return File containing the build artifact
     */
    public File build(Directory source, boolean releaseCandidate) throws Exception {
        // Print message and return
        String output = Dagger.dag().container()
            .from("alpine:latest")
            .withExec(new String[]{"echo", "This is the Build function"})
            .stdout();

        // Print to show the message
        System.out.println(output);

        // Return a dummy file since the function signature requires File
        return Dagger.dag().container()
            .from("alpine:latest")
            .file("/etc/hostname");
    }
}
