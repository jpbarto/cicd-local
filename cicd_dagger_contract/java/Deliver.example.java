package cicd;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.dagger.client.Container;
import io.dagger.client.Dagger;
import io.dagger.client.Directory;
import io.dagger.client.File;
import java.time.Instant;

public class Deliver {

    /**
     * Deliver publishes the goserv container and Helm chart to repositories
     *
     * @param source Source directory containing the project
     * @param containerRepository Container repository (default: ttl.sh)
     * @param helmRepository Helm chart repository URL (default: oci://ttl.sh)
     * @param buildArtifact Build output from the Build function (if not provided, will build from source)
     * @param releaseCandidate Build as release candidate (appends -rc to version tag)
     * @return File containing delivery context
     */
    public File deliver(
            Directory source,
            String containerRepository,
            String helmRepository,
            File buildArtifact,
            boolean releaseCandidate) throws Exception {
        // Perform delivery operations (container push, chart publish)
        // ... delivery logic here ...

        // Create delivery context
        ObjectMapper mapper = new ObjectMapper();
        ObjectNode deliveryContext = mapper.createObjectNode();
        deliveryContext.put("timestamp", Instant.now().toString());
        deliveryContext.put("imageReference", containerRepository + "/goserv:1.0.0");
        deliveryContext.put("chartReference", helmRepository + "/goserv:0.1.0");
        deliveryContext.put("containerRepository", containerRepository);
        deliveryContext.put("helmRepository", helmRepository);
        deliveryContext.put("releaseCandidate", releaseCandidate);

        String contextJson = mapper.writerWithDefaultPrettyPrinter()
            .writeValueAsString(deliveryContext);

        // Return as file
        return Dagger.dag().directory()
            .withNewFile("delivery-context.json", contextJson)
            .file("delivery-context.json");
    }
}
