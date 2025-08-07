# LazyCommit

A comprehensive lazygit configuration that integrates GitHub Copilot for AI-powered commit message generation and advanced git workflow enhancements.

## Features

- 🤖 **AI Commit Messages**: Generate intelligent commit messages using GitHub Copilot
- 🎯 **Multiple AI Models**: Support for different AI models with easy switching
- 🔐 **Secure Authentication**: Built-in GitHub Copilot authentication flow
- ⚡ **Custom Commands**: Powerful keyboard shortcuts for enhanced productivity
- 🎨 **Interactive Menus**: User-friendly selection interfaces

## Quick Start

### Installation

**Important**: This configuration must be cloned into your lazygit config directory:

```bash
# Remove existing lazygit config (backup first if needed)
mv ~/.config/lazygit ~/.config/lazygit.backup 2>/dev/null || true

# Clone this repository
git clone https://github.com/yourusername/lazycommit.git ~/.config/lazygit
```

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

```
~/.config/lazygit/
├── config.yml              # Main lazygit configuration
├── commit_prompt.txt       # AI prompt template
├── copilot/                 # AI integration scripts
│   ├── ai_commit.sh        # Commit message generation
│   ├── auth.sh             # Authentication management
│   ├── auth_utils.sh       # Authentication utilities
│   ├── copilot.sh          # Main controller script
│   ├── device_flow.sh      # GitHub device flow
│   └── models.sh           # Model management
└── README.md               # This file
```

## Troubleshooting

### Authentication Issues

```bash
# Check authentication status
~/.config/lazygit/copilot/copilot.sh status

# Re-authenticate if needed
~/.config/lazygit/copilot/copilot.sh logout
~/.config/lazygit/copilot/copilot.sh login
```

### Permission Errors

### API Errors

- Ensure you have active GitHub Copilot subscription
- Check internet connectivity
- Verify authentication with test command

## Customization

### Modify AI Prompts

Edit `commit_prompt.txt` to customize commit message generation:

```bash
$EDITOR ~/.config/lazygit/commit_prompt.txt
```

### Add Custom Commands

Extend `config.yml` with additional custom commands following the existing pattern.

## Repository as Subdirectory

This configuration is designed to work as a standalone repository within your dotfiles or as an independent clone. The scripts use absolute paths (`~/.config/lazygit/`) to ensure compatibility regardless of the parent repository structure.

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
- [rxtsel's dotfiles](https://github.com/rxtsel/.dot) - Original configuration inspiration and foundation for this project
- [m7medVision/lazycommit](https://github.com/m7medVision/lazycommit) - Another excellent AI commit message tool for lazygit

## Support

If you encounter issues:

1. Check the [troubleshooting section](#troubleshooting)
2. Review lazygit logs: `lazygit --logs`
3. Open an issue with detailed error information

---

**Note**: This is a community-maintained configuration. It is not officially affiliated with GitHub or the lazygit project.

