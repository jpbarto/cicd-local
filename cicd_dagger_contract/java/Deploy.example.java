package cicd;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.dagger.client.Container;
import io.dagger.client.Dagger;
import io.dagger.client.Directory;
import io.dagger.client.File;
import io.dagger.client.Secret;
import java.time.Instant;

public class Deploy {

    /**
     * Deploy installs the Helm chart from a Helm repository to a Kubernetes cluster
     * Note: This function should have cache = "never" configuration
     *
     * @param source Source directory containing the project
     * @param kubeconfig Kubernetes config file content
     * @param awsconfig AWS configuration file content
     * @param helmRepository Helm chart repository URL (default: oci://ttl.sh)
     * @param containerRepository Container repository URL (default: ttl.sh)
     * @param releaseCandidate Build as release candidate (appends -rc to version tag)
     * @return File containing deployment context
     */
    public File deploy(
            Directory source,
            Secret kubeconfig,
            Secret awsconfig,
            String helmRepository,
            String containerRepository,
            boolean releaseCandidate) throws Exception {
        // Perform deployment (helm install/upgrade)
        // ... deployment logic here ...

        // Create deployment context
        ObjectMapper mapper = new ObjectMapper();
        ObjectNode deploymentContext = mapper.createObjectNode();
        deploymentContext.put("timestamp", Instant.now().toString());
        deploymentContext.put("endpoint", "http://goserv.default.svc.cluster.local:8080");
        deploymentContext.put("releaseName", "goserv");
        deploymentContext.put("namespace", "default");
        deploymentContext.put("chartVersion", "0.1.0");
        deploymentContext.put("imageReference", imageRef);

        String contextJson = mapper.writerWithDefaultPrettyPrinter()
            .writeValueAsString(deploymentContext);

        // Return as file
        return Dagger.dag().directory()
            .withNewFile("deployment-context.json", contextJson)
            .file("deployment-context.json");
    }
}
