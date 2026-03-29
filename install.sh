#!/bin/bash
set -e

SKILLS_DIR=""
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --dir)
      SKILLS_DIR="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: install.sh [--dir <path>]"
      echo ""
      echo "Installs pr-review-swarm skills to the detected agent's skills directory."
      echo ""
      echo "Options:"
      echo "  --dir <path>  Install to a custom directory"
      echo ""
      echo "Auto-detected locations:"
      echo "  Claude Code   ~/.claude/skills/"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run with --help for usage."
      exit 1
      ;;
  esac
done

# Auto-detect if no --dir provided
if [ -z "$SKILLS_DIR" ]; then
  if [ -d "$HOME/.claude" ]; then
    SKILLS_DIR="$HOME/.claude/skills"
    echo "Detected: Claude Code → $SKILLS_DIR"
  else
    echo "Could not auto-detect agent. Use --dir <path> to specify install location."
    exit 1
  fi
fi

# Find skills source — either local clone or download
if [ -d "$SCRIPT_DIR/skills" ]; then
  SOURCE="$SCRIPT_DIR/skills"
else
  TEMP_DIR=$(mktemp -d)
  trap "rm -rf $TEMP_DIR" EXIT
  echo "Downloading..."
  git clone --depth 1 https://github.com/knkenko/pr-review-swarm.git "$TEMP_DIR" 2>/dev/null || {
    echo "Error: Failed to download. Check your access to the repository."
    exit 1
  }
  SOURCE="$TEMP_DIR/skills"
fi

# Install
mkdir -p "$SKILLS_DIR"
INSTALLED=0
for skill_dir in "$SOURCE"/pr-swarm*/; do
  [ -d "$skill_dir" ] || continue
  name=$(basename "$skill_dir")
  target="$SKILLS_DIR/$name"
  mkdir -p "$target"
  cp "$skill_dir/SKILL.md" "$target/SKILL.md"
  INSTALLED=$((INSTALLED + 1))
done

echo "Installed $INSTALLED skills to $SKILLS_DIR"
echo ""
echo "Commands:"
echo "  /pr-swarm          Full parallel PR review"
echo "  /pr-swarm-grade    Grade fix quality"
echo "  /pr-swarm-*        Run any individual reviewer"
