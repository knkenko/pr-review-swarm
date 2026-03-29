#!/bin/bash
set -e

REPO_URL="https://github.com/knkenko/pr-review-swarm"
SKILLS_DIR="$HOME/.claude/skills"
TEMP_DIR=$(mktemp -d)

echo "Installing pr-review-swarm..."

# Clone repo
git clone --depth 1 "$REPO_URL" "$TEMP_DIR" 2>/dev/null || {
  echo "Error: Failed to clone repo. Make sure you have access to $REPO_URL"
  rm -rf "$TEMP_DIR"
  exit 1
}

# Create skills directory if needed
mkdir -p "$SKILLS_DIR"

# Copy all skills
INSTALLED=0
for skill_dir in "$TEMP_DIR"/skills/pr-swarm*/; do
  skill_name=$(basename "$skill_dir")
  target="$SKILLS_DIR/$skill_name"

  if [ -d "$target" ]; then
    echo "  Updating $skill_name"
  else
    echo "  Installing $skill_name"
  fi

  mkdir -p "$target"
  cp "$skill_dir/SKILL.md" "$target/SKILL.md"
  INSTALLED=$((INSTALLED + 1))
done

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "Installed $INSTALLED skills."
echo ""
echo "Usage:"
echo "  /pr-swarm          — Run full parallel PR review"
echo "  /pr-swarm-grade    — Grade fix quality after review"
echo "  /pr-swarm-code     — Run code quality review only"
echo "  /pr-swarm-security — Run security review only"
echo "  ... and 19 more specialized reviewers"
echo ""
echo "Requirements: GitHub CLI (gh) must be installed and authenticated."
