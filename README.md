# Lucretia: Niri & Quickshell

A state-of-the-art, high-performance, and visually stunning Wayland desktop environment built on **Niri** and **Quickshell** (QML/Qt6). 

Featuring real-time Material You dynamic color theme generation, customized high-speed utility widgets, and custom C++ backend controllers.

> **Forked from** [ilyamiro/nixos-configuration](https://github.com/ilyamiro/nixos-configuration) — adapted for **Niri**.

---

## 🚀 Fast Automated Installation

You can automatically deploy this entire desktop configuration, resolve dependencies, and compile all C++ background daemons on **Arch Linux** with a single command:

```bash
curl -sL https://raw.githubusercontent.com/noqokhxnh/lucretia/main/install.sh | bash
```

> [!NOTE]
> The interactive installer will check for existing configurations, create safe backups under `~/.config-backup-[timestamp]`, set up required fonts, configure keyboard layouts, set up graphics drivers, and allow you to configure display managers (SDDM) and weather APIs.

---

##  Preview

| | | |
|---|---|---|
| ![screenshot1](public/screenshot1.png) | ![screenshot2](public/screenshot2.png) | ![screenshot3](public/screenshot3.png) |
| ![screenshot4](public/screenshot4.png) | ![screenshot5](public/screenshot5.png) | ![screenshot6](public/screenshot6.png) |
| ![screenshot7](public/screenshot7.png) | ![screenshot8](public/screenshot8.png) | ![screenshot9](public/screenshot9.png) |

---

## 🤝 Contributing & Pull Request Guidelines

Contributions, issues, and feature requests are welcome! If you would like to contribute, please follow these guidelines:

### 1. Fork & Branch
- **Fork** the repository to your own GitHub account.
- Clone your fork locally and create a new branch from `main`:
  ```bash
  git checkout -b feature/your-feature-name
  # or
  git checkout -b fix/your-bug-fix
  ```

### 2. Making Changes
- Keep changes clean, modular, and focused on a single feature or bug fix.
- Follow the existing project structure and coding conventions (QML, C++, Bash scripts, or KDL configs).
- If your change affects UI/styling, please test across different themes/wallpapers if applicable.

### 3. Commit Convention
Follow [Conventional Commits](https://www.conventionalcommits.org/) format:
- `feat:` for new features or widgets
- `fix:` for bug fixes
- `refactor:` for code refactoring without feature changes
- `docs:` for documentation updates
- `style:` for code formatting, styling, or UI aesthetic tweaks
- `chore:` for maintenance tasks, dependencies, or build scripts

Example:
```bash
git commit -m "feat(quickshell): add new battery charging animation"
```

### 4. Submitting a Pull Request
1. Push your branch to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```
2. Open a **Pull Request** against the `main` branch of this repository.
3. Fill out the PR description:
   - **Summary**: Describe what changes were made and why.
   - **Screenshots / Recordings**: If UI/visual elements are added or modified, include screenshots or GIFs demonstrating the changes.
   - **Related Issues**: Link any open issues (e.g., `Closes #12`).
4. Ensure there are no merge conflicts with `main`.

---

## 📜 License

Distributed under the MIT License. See `LICENSE` for more information.
