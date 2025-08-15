#!/bin/bash

# Script to sync config.local.yml to Forgejo remote when changed
# This script is git-ignored to keep it local-only

CONFIG_FILE="config.local.yml"
FORGEJO_REMOTE="forgejo"  # Change this to your Forgejo remote name
BRANCH="main"             # Change this to your target branch

# Check if config.local.yml exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: $CONFIG_FILE not found"
    exit 1
fi

# Check if we have a Forgejo remote configured
if ! git remote get-url "$FORGEJO_REMOTE" >/dev/null 2>&1; then
    echo "Error: Remote '$FORGEJO_REMOTE' not found"
    echo "Add your Forgejo remote with: git remote add $FORGEJO_REMOTE <your-forgejo-repo-url>"
    exit 1
fi

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)

# Create a temporary branch for Forgejo sync
TEMP_BRANCH="forgejo-config-sync-$(date +%s)"

echo "Creating temporary branch: $TEMP_BRANCH"
git checkout -b "$TEMP_BRANCH"

# Add the config file
echo "Adding $CONFIG_FILE to git..."
git add "$CONFIG_FILE"

# Commit the change
echo "Committing config changes..."
git commit -m "Update local Forgejo configuration

🤖 Generated with [opencode](https://opencode.ai)

Co-Authored-By: opencode <noreply@opencode.ai>"

# Push to Forgejo
echo "Pushing to Forgejo remote..."
git push "$FORGEJO_REMOTE" "$TEMP_BRANCH:$BRANCH"

# Switch back to original branch
echo "Switching back to $CURRENT_BRANCH..."
git checkout "$CURRENT_BRANCH"

# Delete temporary branch
echo "Cleaning up temporary branch..."
git branch -D "$TEMP_BRANCH"

# Remove the config file from git index (keep it untracked)
git rm --cached "$CONFIG_FILE" 2>/dev/null || true

echo "✅ Successfully synced $CONFIG_FILE to Forgejo!"
echo "Note: $CONFIG_FILE remains untracked in your local repo"