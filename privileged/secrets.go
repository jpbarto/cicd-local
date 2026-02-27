package cicd

import (
	"context"
	"fmt"
	"os"
	"path/filepath"

	"dagger.io/dagger" //nolint:typecheck // import rewritten by manage_privileged.sh at injection time
)

// INJECTED SECRETS - These values are replaced at runtime by manage_privileged.sh.
// Do NOT modify manually.
const (
	// injectedKubectlContext holds the minified kubeconfig for the current
	// kubectl context, injected as a raw string literal before dagger call.
	injectedKubectlContext = `__INJECTED_KUBECTL_CONTEXT__`

	// injectedContainerRepositoryURL is the container image registry URL,
	// sourced from CONTAINER_REPOSITORY_URL in local_cicd.env.
	injectedContainerRepositoryURL = `__INJECTED_CONTAINER_REPOSITORY_URL__`

	// injectedHelmRepositoryURL is the Helm chart repository URL,
	// sourced from HELM_REPOSITORY_URL in local_cicd.env.
	injectedHelmRepositoryURL = `__INJECTED_HELM_REPOSITORY_URL__`
)

// GetContainerRepositoryURL returns the injected container image registry URL.
func GetContainerRepositoryURL() (string, error) {
	if injectedContainerRepositoryURL == "__INJECTED_CONTAINER_REPOSITORY_URL__" || injectedContainerRepositoryURL == "" {
		return "", fmt.Errorf("container repository URL not injected - ensure manage_privileged.sh ran before dagger call")
	}
	return injectedContainerRepositoryURL, nil
}

// GetHelmRepositoryURL returns the injected Helm chart repository URL.
func GetHelmRepositoryURL() (string, error) {
	if injectedHelmRepositoryURL == "__INJECTED_HELM_REPOSITORY_URL__" || injectedHelmRepositoryURL == "" {
		return "", fmt.Errorf("helm repository URL not injected - ensure manage_privileged.sh ran before dagger call")
	}
	return injectedHelmRepositoryURL, nil
}

// GetKubeconfigSecret returns the injected kubeconfig as a Dagger secret.
// The value is the output of `kubectl config view --minify --raw` captured
// at runtime by manage_privileged.sh before dagger call is executed.
//
// Parameters:
//   - ctx: Context for the operation
//   - client: Dagger client instance
//
// Returns a Dagger secret containing the minified kubeconfig content.
//
// Example usage:
//
//	kubeconfigSecret, err := privileged.GetKubeconfigSecret(ctx, client)
//	if err != nil {
//	    return err
//	}
func GetKubeconfigSecret(ctx context.Context, client *dagger.Client) (*dagger.Secret, error) {
	if injectedKubectlContext == "__INJECTED_KUBECTL_CONTEXT__" || injectedKubectlContext == "" {
		return nil, fmt.Errorf("kubeconfig not injected - ensure manage_privileged.sh ran before dagger call")
	}
	return client.SetSecret("kubeconfig", injectedKubectlContext), nil
}

// GetSecretPath returns the path to a secret file in ~/.cicd-local/secrets/.
// This is useful for storing sensitive values outside the project directory.
//
// Parameters:
//   - secretName: Name of the secret file
//
// Returns the full path to the secret file.
//
// Example usage:
//
//	secretPath, err := privileged.GetSecretPath("api-token")
//	if err != nil {
//	    return err
//	}
func GetSecretPath(secretName string) (string, error) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("failed to get home directory: %w", err)
	}

	secretsDir := filepath.Join(homeDir, ".cicd-local", "secrets")
	secretPath := filepath.Join(secretsDir, secretName)

	if _, err := os.Stat(secretPath); os.IsNotExist(err) {
		return "", fmt.Errorf("secret file not found: %s", secretPath)
	}

	return secretPath, nil
}

// LoadSecretFile reads a secret from ~/.cicd-local/secrets/.
// Returns the secret content as a byte slice.
//
// Example usage:
//
//	content, err := privileged.LoadSecretFile("api-token")
//	if err != nil {
//	    return err
//	}
func LoadSecretFile(secretName string) ([]byte, error) {
	secretPath, err := GetSecretPath(secretName)
	if err != nil {
		return nil, err
	}

	content, err := os.ReadFile(secretPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read secret file: %w", err)
	}

	return content, nil
}

// LoadSecretAsDaggerSecret loads a secret file as a Dagger secret.
// This is useful for passing secrets to Dagger containers.
//
// Parameters:
//   - client: Dagger client instance
//   - secretName: Name of the secret file in ~/.cicd-local/secrets/
//
// Returns a Dagger secret.
//
// Example usage:
//
//	apiToken, err := privileged.LoadSecretAsDaggerSecret(client, "api-token")
//	if err != nil {
//	    return err
//	}
func LoadSecretAsDaggerSecret(client *dagger.Client, secretName string) (*dagger.Secret, error) {
	content, err := LoadSecretFile(secretName)
	if err != nil {
		return nil, err
	}

	return client.SetSecret(secretName, string(content)), nil
}

// GetEnvOrSecret attempts to get a value from environment variable first,
// then falls back to reading from a secret file in ~/.cicd-local/secrets/.
//
// Parameters:
//   - envVar: Environment variable name to check first
//   - secretName: Secret file name to fall back to
//
// Returns the value as a string.
//
// Example usage:
//
//	apiKey, err := privileged.GetEnvOrSecret("API_KEY", "api-key")
//	if err != nil {
//	    return err
//	}
func GetEnvOrSecret(envVar, secretName string) (string, error) {
	// Try environment variable first
	if value := os.Getenv(envVar); value != "" {
		return value, nil
	}

	// Fall back to secret file
	content, err := LoadSecretFile(secretName)
	if err != nil {
		return "", fmt.Errorf("failed to get value from env var %s or secret file %s: %w", envVar, secretName, err)
	}

	return string(content), nil
}
