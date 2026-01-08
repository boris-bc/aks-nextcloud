# Contributing to Nextcloud on AKS

Thank you for your interest in contributing to this project! This document provides guidelines for contributing.

## How to Contribute

### Reporting Issues

If you encounter a problem:

1. **Search existing issues** to see if it's already reported
2. **Create a new issue** with:
   - Clear description of the problem
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details (AKS version, kubectl version, etc.)
   - Relevant logs or error messages

### Suggesting Enhancements

We welcome suggestions for:
- New features
- Documentation improvements
- Configuration options
- Performance optimizations

Please open an issue with:
- Clear description of the enhancement
- Use case and benefits
- Proposed implementation (if applicable)

### Pull Requests

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/your-feature-name`
3. **Make your changes**:
   - Follow existing code style
   - Update documentation if needed
   - Test your changes
4. **Commit your changes**: `git commit -m "Description of changes"`
5. **Push to your fork**: `git push origin feature/your-feature-name`
6. **Create a Pull Request**

### PR Guidelines

- **One feature per PR**: Keep PRs focused on a single feature or fix
- **Update documentation**: If you change functionality, update the README
- **Test manifests**: Ensure all YAML files are valid
- **Validate scripts**: Check bash scripts with `bash -n script.sh`
- **Follow conventions**: Match the existing code style

## Development Guidelines

### YAML Manifests

- Use 2 spaces for indentation
- Include comments for complex configurations
- Follow Kubernetes best practices
- Validate with: `kubectl --dry-run=client apply -f file.yaml`

### Scripts

- Use `#!/bin/bash` shebang
- Include error handling (`set -e`)
- Add descriptive comments
- Validate syntax: `bash -n script.sh`

### Documentation

- Use clear, concise language
- Include code examples
- Keep formatting consistent
- Update all relevant docs when making changes

## Testing

Before submitting a PR:

1. **Validate YAML**:
   ```bash
   for file in k8s/base/*.yaml; do
     kubectl --dry-run=client apply -f $file --validate=false
   done
   ```

2. **Check bash syntax**:
   ```bash
   bash -n deploy.sh
   bash -n cleanup.sh
   bash -n validate.sh
   ```

3. **Test deployment** (if possible):
   ```bash
   ./deploy.sh
   ./validate.sh
   ```

## Areas for Contribution

We especially welcome contributions in:

- **High Availability**: Multi-replica setups with shared storage
- **Monitoring**: Prometheus/Grafana integration
- **Backup Solutions**: Automated backup strategies
- **Security**: Security hardening and best practices
- **CI/CD**: GitHub Actions for automated testing
- **Documentation**: Tutorials, troubleshooting guides
- **Examples**: Additional use cases and configurations

## Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Focus on the issue, not the person
- Help others learn and grow

## Questions?

- Open an issue for questions
- Check existing documentation first
- Be specific about your environment and problem

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

Thank you for contributing! 🎉
