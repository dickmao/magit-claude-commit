# magit-claude-commit

Automatically generate git commit messages using Claude Code integrated with Magit via project-claude.

## Features

- Automatically generates commit messages when you initiate a commit in Magit
- Uses project-claude to communicate with Claude Code (no API key required)
- Includes staged changes and recent commit history for context
- Messages are inserted directly into the commit buffer for easy editing
- Fully customizable through Emacs customization system

## Requirements

- Emacs 27.1 or later
- Magit 3.0.0 or later
- project-claude 0.0.1 or later
- Claude Code CLI (managed by project-claude)

## Installation

### Manual Installation

1. Download `magit-claude-commit.el`
2. Place it in your Emacs load path
3. Add to your init file:

```elisp
(require 'magit-claude-commit)
(magit-claude-commit-mode 1)
```

### Using `use-package`

```elisp
(use-package magit-claude-commit
  :load-path "/path/to/magit-claude-commit.el"
  :after magit
  :config
  (magit-claude-commit-mode 1))
```

## Usage

Once enabled, the package works automatically:

1. Stage your changes in Magit as usual (`s` to stage)
2. Press `c c` to create a commit
3. The commit message buffer will open with a generated message already inserted
4. Edit, accept, or delete the message as desired
5. Press `C-c C-c` to commit or `C-c C-k` to cancel

### Manual Generation

You can also manually generate a message while in the commit buffer:

```
M-x magit-claude-commit-generate
```

This is useful if you want to regenerate the message or if automatic generation was skipped.

## Customization

Customize the behavior through Emacs customization:

```
M-x customize-group RET magit-claude-commit RET
```

Available options:

- **magit-claude-commit-timeout**: Timeout for Claude responses in seconds (default: 30)
- **magit-claude-commit-context-lines**: Number of recent commits for context (default: 10)
- **magit-claude-commit-additional-instructions**: Custom instructions for message style
- **magit-claude-commit-verbose**: Enable debug logging (default: nil)

### Example Customization

```elisp
(setq magit-claude-commit-additional-instructions
      "Use imperative mood. Keep the summary under 50 characters. Include ticket numbers from branch names.")
```

## How It Works

1. When you initiate a commit, the package hooks into `git-commit-setup-hook`
2. It gathers:
   - The staged diff (`git diff --staged`)
   - Recent commit messages for style consistency (`git log`)
3. This context is sent to Claude Code via project-claude with a carefully crafted prompt
4. The generated message is inserted at the beginning of the commit buffer
5. You maintain full control to edit, replace, or delete the message

The package piggybacks on existing project-claude buffers or creates a new one if needed, ensuring efficient resource usage.

## Troubleshooting

### No message is generated

- Ensure project-claude is installed and working: `M-x project-claude`
- Enable verbose logging: `(setq magit-claude-commit-verbose t)`
- Check the `*Messages*` buffer for errors
- Verify you have staged changes: `git diff --staged` should show output
- Make sure you're in a project recognized by project.el

### Message generation is slow

- Increase the timeout: `(setq magit-claude-commit-timeout 60)`
- Claude Code requires network access and may be slow on large diffs

### Message quality issues

- Adjust the context: `(setq magit-claude-commit-context-lines 20)`
- Add custom instructions: `(setq magit-claude-commit-additional-instructions "...")`

## Disabling

To temporarily disable:

```elisp
(magit-claude-commit-mode -1)
```

To permanently disable, remove or comment out the mode activation in your init file.

## License

MIT
