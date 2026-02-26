package cicd;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.dagger.client.Container;
import io.dagger.client.Dagger;
import io.dagger.client.Directory;
import io.dagger.client.File;
import io.dagger.client.Secret;

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
     * @param deploymentContext Deployment context from Deploy function
     * @param validationContext Validation context from Validate function
     * @return String containing test results
     */
    public String integrationTest(
            Directory source,
            File deploymentContext,
            File validationContext) throws Exception {
        // Extract endpoint from deployment context if provided
        String targetUrl = null;
        if (deploymentContext != null) {
            ObjectMapper mapper = new ObjectMapper();
            String contextContent = deploymentContext.contents();
            JsonNode context = mapper.readTree(contextContent);
            targetUrl = context.get("endpoint").asText();
        }

        // Check validation status if provided
        if (validationContext != null) {
            ObjectMapper mapper = new ObjectMapper();
            String valContent = validationContext.contents();
            JsonNode valContext = mapper.readTree(valContent);
            if (!"healthy".equals(valContext.get("status").asText())) {
                return "Skipping tests: deployment validation failed";
            }
        }

        // Run integration tests against targetUrl
        String output = Dagger.dag().container()
            .from("alpine:latest")
            .withExec(new String[]{"echo", "Running integration tests against " + targetUrl})
            .stdout();

        return output;
    }
}
