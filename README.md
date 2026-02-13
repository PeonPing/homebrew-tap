# Homebrew Tap for peon-ping

Sound effects and desktop notifications for AI coding agents.

## Install

```bash
brew install PeonPing/tap/peon-ping
```

Then run setup to register hooks and download sound packs:

```bash
peon-ping-setup
```

## Options

```bash
peon-ping-setup              # Install 10 default packs
peon-ping-setup --all        # Install all 43+ packs
peon-ping-setup --packs=peon,glados,sc_kerrigan  # Pick specific packs
```

## Usage

After setup, peon-ping plays automatically during Claude Code sessions.

```bash
peon toggle     # Mute/unmute sounds
peon status     # Check current status
peon help       # See all commands
```

## Links

- [peonping.com](https://peonping.com) - Browse packs with audio previews
- [GitHub](https://github.com/PeonPing/peon-ping) - Source code
- [OpenPeon](https://openpeon.com) - The open standard for coding event sounds
