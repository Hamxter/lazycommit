# LazyCommit

A comprehensive lazygit configuration that integrates GitHub Copilot for
AI-powered commit message generation and advanced git workflow enhancements.

## Screenshots

![LazyCommit Overview](images/lazycommit.png)

![AI Commit Generation](images/lazycommit-commit.png)

## Features

- 🤖 **AI Commit Messages**: Generate intelligent commit messages using GitHub Copilot
- 🎯 **Multiple AI Models**: Support for different AI models with easy switching
- 🔐 **Secure Authentication**: Built-in GitHub Copilot authentication flow
- ⚡ **Custom Commands**: Powerful keyboard shortcuts for enhanced productivity
- 🎨 **Interactive Menus**: User-friendly selection interfaces

## Quick Start

### Installation

**Recommended**: Clone this repository and use lazygit's multiple config file support for easy customization.

#### Option 1: Multiple Config Files (Recommended)

This approach allows you to keep your personal lazygit settings while using LazyCommit features:

```bash
# Backup existing lazygit config (if any)
mv ~/.config/lazygit ~/.config/lazygit.backup 2>/dev/null || true

# Clone this repository
git clone https://github.com/Hamxter/lazycommit.git ~/.config/lazygit

# If you had a previous config, copy it as your local config:
cp ~/.config/lazygit.backup/config.yml ~/.config/lazygit/config.local.yml

# Or create an empty local config file for customizations:
touch ~/.config/lazygit/config.local.yml
```

**Method A: Environment Variable (Recommended)**

Add to your shell config (`~/.zshrc`, `~/.bashrc`, etc.):

```bash
# LAZYGIT - Use multiple config files
export LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml,$HOME/.config/lazygit/config.local.yml"
```

**Method B: Shell Alias**

```bash
# Add to ~/.bashrc, ~/.zshrc, etc.
alias lg='lazygit --use-config-file="~/.config/lazygit/config.yml,~/.config/lazygit/config.local.yml"'
```

**Benefits of this approach:**

- Keep your existing lazygit configuration intact
- Easy to customize LazyCommit settings in `config.local.yml`
- Simple updates by pulling the latest changes
- Can easily disable by removing the environment variable or alias
- Environment variable method works with any lazygit invocation (recommended)
- Alias method gives you a separate command (`lg`) for LazyCommit-enabled lazygit

#### Option 2: Fresh Installation (For new lazygit users)

```bash
# Backup existing lazygit config (if any)
mv ~/.config/lazygit ~/.config/lazygit.backup 2>/dev/null || true

# Clone this repository
git clone https://github.com/Hamxter/lazycommit.git ~/.config/lazygit
```

#### Option 3: Traditional Merge (Legacy approach)

If you prefer to merge configurations manually:

```bash
# Clone the repository to a temporary location
git clone https://github.com/Hamxter/lazycommit.git /tmp/lazycommit

# Copy just the lazycommit folder
cp -r /tmp/lazycommit/lazycommit ~/.config/lazygit/

# Backup your current config
cp ~/.config/lazygit/config.yml ~/.config/lazygit/config.yml.backup

# Use the LazyCommit config or manually merge
cp /tmp/lazycommit/config.yml ~/.config/lazygit/config.yml

# Clean up
rm -rf /tmp/lazycommit
```

**Note**: If your existing config already has a `customCommands` section,
you'll need to manually merge the commands instead of replacing the entire file.

### Prerequisites

- [lazygit](https://github.com/jesseduffield/lazygit) installed
- GitHub account with Copilot access
- `curl` and `jq` for API interactions

### Authentication Setup

1. Open lazygit in any git repository
2. Press `Ctrl+G` to open the Copilot menu
3. Select "Login" to start authentication
4. Follow the device flow instructions
5. Select "Complete Login" after entering the device code

## Keyboard Shortcuts

| Key | Context | Description |
|-----|---------|-------------|
| `Ctrl+U` | Files | Generate AI commit message |
| `Ctrl+G` | Global | GitHub Copilot management |
| `Ctrl+N` | Global | Select AI model |

## Commands

### AI Commit Generation (`Ctrl+U`)

1. Stage your changes in lazygit
2. Press `Ctrl+U` in the files view
3. Select from AI-generated commit messages
4. Edit the message if needed
5. Commit automatically applies

### Copilot Management (`Ctrl+G`)

- **Check Status**: View current authentication state
- **Login**: Start GitHub authentication flow
- **Complete Login**: Finish authentication process
- **Logout**: Clear stored credentials
- **Test**: Verify authentication works

### Model Selection (`Ctrl+N`)

Switch between available AI models for commit generation.

## File Structure

### Recommended Multiple Config Setup

```text
~/.config/lazygit/
├── config.yml               # LazyCommit configuration
├── config.local.yml         # Your personal lazygit settings
├── lazycommit/              # LazyCommit integration
│   ├── commit_prompt.txt    # AI prompt template
│   ├── auth.json            # Authentication data (auto-generated)
│   ├── models_cache.json    # Cached AI models (auto-generated)
│   ├── selected_model.txt   # User's preferred model (auto-generated)
│   └── copilot/             # AI integration scripts
│       ├── ai_commit.sh     # Commit message generation
│       ├── auth.sh          # Authentication management
│       ├── auth_utils.sh    # Authentication utilities
│       ├── copilot.sh       # Main controller script
│       ├── device_flow.sh   # GitHub device flow
│       └── models.sh        # Model management
└── README.md                # This file
```

### Traditional Single Config Setup

```text
~/.config/lazygit/
├── config.yml              # Main lazygit configuration
├── lazycommit/              # LazyCommit integration
│   ├── commit_prompt.txt    # AI prompt template
│   ├── auth.json            # Authentication data (auto-generated)
│   ├── models_cache.json    # Cached AI models (auto-generated)
│   ├── selected_model.txt   # User's preferred model (auto-generated)
│   └── copilot/             # AI integration scripts
│       ├── ai_commit.sh     # Commit message generation
│       ├── auth.sh          # Authentication management
│       ├── auth_utils.sh    # Authentication utilities
│       ├── copilot.sh       # Main controller script
│       ├── device_flow.sh   # GitHub device flow
│       └── models.sh        # Model management
└── README.md                # This file
```

## Troubleshooting

### Multiple Config Files Issues

If you're having issues with the multiple config file setup:

```bash
# Check your LG_CONFIG_FILE environment variable
echo $LG_CONFIG_FILE

# Test if your config files are valid
lazygit --help

# Or test with explicit config files
lazygit --use-config-file="~/.config/lazygit/config.yml,~/.config/lazygit/config.local.yml" --help

# Check if files exist
ls -la ~/.config/lazygit/config.yml
ls -la ~/.config/lazygit/config.local.yml

# Update LazyCommit
cd ~/.config/lazygit && git pull
```

### Authentication Issues

```bash
# Check authentication status
~/.config/lazygit/lazycommit/copilot/copilot.sh status

# Re-authenticate if needed
~/.config/lazygit/lazycommit/copilot/copilot.sh logout
~/.config/lazygit/lazycommit/copilot/copilot.sh login
```

### Permission Errors

If you encounter permission issues with the scripts:

```bash
# Make scripts executable
chmod +x ~/.config/lazygit/lazycommit/copilot/*.sh
```

### API Errors

- Ensure you have active GitHub Copilot subscription
- Check internet connectivity
- Verify authentication with test command

## Customization

### Using Multiple Config Files (Recommended)

If you're using the multiple config file approach, add your customizations to `~/.config/lazygit/config.local.yml`. This file is loaded after the LazyCommit config, so your settings will override LazyCommit defaults.

Example `config.local.yml`:

```yaml
# Customize AI prompts
# (LazyCommit config is loaded first, then these settings override)

# Customize keybindings
keybinding:
  universal:
    # Override the default AI commit key
    commitChanges: c  # Use 'c' instead of 'Ctrl+U'

# Add your own custom commands
customCommands:
  - key: 'Y'
    context: 'global'
    description: 'My custom command'
    command: 'echo "Hello from custom command"'
```

### Traditional Single Config Customization

### Modify AI Prompts

Edit `lazycommit/commit_prompt.txt` to customize commit message generation:

```bash
$EDITOR ~/.config/lazygit/lazycommit/commit_prompt.txt
```

### Add Custom Commands

Extend `config.yml` with additional custom commands following the existing pattern.

## Repository as Subdirectory

This configuration is designed to work as a standalone repository within
your dotfiles or as an independent clone. The scripts use absolute paths
to ensure compatibility regardless of the parent repository structure.

### Updating LazyCommit

#### Multiple Config Setup

```bash
# Update LazyCommit while preserving your customizations
cd ~/.config/lazygit
git stash push config.local.yml  # preserve your local config
git pull origin main
git stash pop  # restore your local config
```

Your personal settings in `~/.config/lazygit/config.local.yml` remain untouched with this approach.

#### Traditional Setup

```bash
# Update LazyCommit (be careful with local changes)
cd ~/.config/lazygit
git stash  # if you have local changes
git pull origin main
git stash pop  # restore local changes if any
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly with different git repositories
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Acknowledgments

- [lazygit](https://github.com/jesseduffield/lazygit) - Amazing terminal UI for git
- [GitHub Copilot](https://github.com/features/copilot) - AI pair programmer
- [rxtsel's dotfiles](https://github.com/rxtsel/.dot) - Original configuration
  inspiration and foundation for this project
- [m7medVision/lazycommit](https://github.com/m7medVision/lazycommit) - Another
  excellent AI commit message tool for lazygit

## Support

If you encounter issues:

1. Check the [troubleshooting section](#troubleshooting)
2. Review lazygit logs: `lazygit --logs`
3. Open an issue with detailed error information

---

**Note**: This is a community-maintained configuration. It is not officially
affiliated with GitHub or the lazygit project.
