#!/usr/bin/env bash

# Directory to monitor
MONITORED_DIR="/home/$USER/docker-homelab"

# GitHub repository details
REPO_URL="https://github.com/devken0/docker-homelab.git"
BRANCH="main"
REMOTE="origin"

# Change to the monitored directory
cd "$MONITORED_DIR" || exit

# Function to check for changes and push to GitHub
check_and_push_changes() {
    # Check for modified compose.yaml files
    changed_files=$(git status --porcelain | grep 'compose.yaml' | awk '{print $2}')

    # If there are changes, add them, commit, and push
    if [ -n "$changed_files" ]; then
        echo "Changes detected. Pushing to GitHub..."
        git add $changed_files
        git commit -m "Update: $(date '+%Y-%m-%d %H:%M:%S')"
        git push $REMOTE $BRANCH
        echo "Changes pushed successfully."
    else
        echo "No changes detected."
    fi
}

# Run the function to check and push changes
check_and_push_changes

