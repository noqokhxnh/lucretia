# Lucretia


> **Forked and evolved from** [ilyamiro/nixos-configuration](https://github.com/ilyamiro/nixos-configuration).

---

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/noqokhxnh/lucretia/main/install.sh | bash
```

---

## Updating & Maintenance

Lucretia features an integrated update workflow with automated git conflict and configuration protection:

### Via GUI
Click the update notification banner or open **Guide → About / Updater Popup**, then slide or hold **Update**. The updater launches inside your terminal emulator (`foot`, `kitty`, `ghostty`, or `alacritty`).

### Via Terminal
```bash
bash ~/.config/niri/bin/updater.sh
```

### Configuration Protection
1. **Dirty Worktree Protection**: Automatically stashes untracked and modified files (`git stash push -u`).
2. **Accurate Divergence Check**: Calculates incoming commit counts before pulling (`git rev-list`). If local commits are ahead of remote, it avoids unnecessary pulls.
3. **Conflict Hard Gate**: If `git pull` or `git stash pop` encounters merge conflicts, the process halts immediately and lists conflicting files. It **never runs the installer on conflict markers**, preventing syntax errors and desktop crashes.
4. **3-Way `config.kdl` Merge**: Customized keybinds, window rules, and monitor setups are safely 3-way merged using `git merge-file`. If conflicts occur, your working `config.kdl` is preserved as active, and the new upstream file is saved alongside it as `config.kdl.upstream`.
5. **Atomic `settings.json` Merging**: JSON configuration merges are verified via `jq` in temporary files before atomic replacement, eliminating 0-byte truncation risks.

---

## License & Credits

- Upstream architecture and visual inspiration: [ilyamiro/nixos-configuration](https://github.com/ilyamiro/nixos-configuration)
- Compositor: [Niri](https://github.com/YaLTeR/niri)
- Shell Engine: [Quickshell](https://git.outfoxxed.me/outfoxxed/quickshell)
- Dynamic Theming: [Matugen](https://github.com/InioX/matugen)
