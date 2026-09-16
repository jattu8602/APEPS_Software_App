# Contributing Guidelines

Thank you for your interest in contributing! We welcome contributions from developers of all skill levels.

## Code of Conduct

Please review and abide by our [Code of Conduct](CODE_OF_CONDUCT.md) in all community interactions.

## Getting Started

1. **Fork & Clone**: Fork the repository and clone your fork locally:
   ```bash
   git clone https://github.com/YOUR-USERNAME/ssbweb.git
   cd ssbweb
   ```

2. **Branching**: Create a new feature/bugfix branch off `main` or `dev`:
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Install Dependencies**:
   ```bash
   npm install
   ```

## Development Workflow & Code Consistency

To maintain clean and consistent code across the project:

- **Format & Lint**: Ensure your code passes all linter and formatting rules before committing:
  ```bash
  npm run lint
  ```
- **Code Style**:
  - Use modern JavaScript / TypeScript / Flutter conventions.
  - Follow standard indentation rules (2 spaces, UTF-8, LF line endings) as configured in [.editorconfig](.editorconfig) and [.prettierrc](.prettierrc).
  - Do NOT commit hardcoded credentials, secret tokens, or `.env` files.

## Pull Request Guidelines

When submitting a Pull Request:

1. Fill out the provided [Pull Request Template](.github/PULL_REQUEST_TEMPLATE.md).
2. Ensure all GitHub Actions CI checks pass (linting, build verification, secret scan, typo check).
3. Keep PRs focused on a single feature or bug fix.
4. Request review from maintainers when ready.
