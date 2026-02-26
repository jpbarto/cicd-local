# Dagger Contract Examples

This directory contains reference implementations of the cicd-local contract in multiple languages.

## Available Languages

- **[golang/](golang/)** - Go examples
- **[python/](python/)** - Python examples  
- **[java/](java/)** - Java examples
- **[typescript/](typescript/)** - TypeScript examples

## Documentation

For complete documentation, see:

- **[Contract Reference](../docs/CONTRACT_REFERENCE.md)** - Complete contract specification
- **[Contract Validation](../docs/CONTRACT_VALIDATION.md)** - Validation guide with examples
- **[Context Files](../docs/CONTEXT_FILES.md)** - Context files for inter-function communication
- **[User Guide](../docs/USER_GUIDE.md)** - Complete usage guide

## Quick Start

Each language directory contains example files demonstrating all six required functions:

- `build.example.*` - Build function
- `test.example.*` - UnitTest and IntegrationTest functions
- `deliver.example.*` - Deliver function
- `deploy.example.*` - Deploy function
- `validate.example.*` - Validate function

## Validating Your Implementation

To verify your Dagger functions conform to the contract:

```bash
cicd-local validate
```

See [Contract Validation Guide](../docs/CONTRACT_VALIDATION.md) for details.
