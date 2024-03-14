#!/usr/bin/env bash

# Prompt user for input
read -p "Enter the path to the file you want to monitor: " FILE_TO_MONITOR
read -p "Enter the commit message: " COMMIT_MESSAGE
read -p "Enter the branch name: " BRANCH
read -p "Enter the GitHub repository URL: " REPO_URL
read -p "Enter your GitHub username: " GIT_USERNAME
read -p "Enter your GitHub email address: " GIT_EMAIL

# Create the script with provided inputs
mkdir scripts

cat <<EOF > scripts/github_commit_script.sh
#!/usr/bin/env bash

# Define variables
CURRENT_DATE_TIME=$(date +"%Y-%m-%d %H:%M:%S")
FILE_TO_MONITOR="$FILE_TO_MONITOR"
COMMIT_MESSAGE="$COMMIT_MESSAGE"
BRANCH="$BRANCH"
REPO_URL="$REPO_URL"
GIT_USERNAME="$GIT_USERNAME"
GIT_EMAIL="$GIT_EMAIL"

# Change to the directory where the file is located
cd "\$(dirname "\$FILE_TO_MONITOR")" || exit

# Check if the file has changed
if git diff --quiet "\$FILE_TO_MONITOR"; then
    #echo "No changes detected. $CURRENT_DATE_TIME"
    exit 0
else
    echo "Changes detected. Committing and pushing..."
    git config user.name "\$GIT_USERNAME"
    git config user.email "\$GIT_EMAIL"
    git add "\$FILE_TO_MONITOR"
    git commit -m "\$COMMIT_MESSAGE (automated)"
    git push "\$REPO_URL" "\$BRANCH"
    echo "Changes committed and pushed successfully. $CURRENT_DATE_TIME"
fi
EOF

cat <<EOF > scripts/db_backup_script.sh
#!/usr/bin/env bash
docker exec photoprism photoprism backup -i -f
EOF

# Make the script executable
chmod +x github_commit_script.sh
chmod +x db_backup_script.sh.sh

# Add the cron job
read -p "Enter the frequency for the cron job github_commit_script.sh (e.g., * * * * * for every minute): " COMMIT_CRON_FREQUENCY
(crontab -l ; echo "$COMMIT_CRON_FREQUENCY $(pwd)/scripts/github_commit_script.sh") | crontab -
#(crontab -l ; echo "*/30 * * * * rm $(pwd)/cron_log.log") | crontab -
read -p "Enter the frequency for the cron job db_backup_script.sh (e.g., * * * * * for every minute): " BACKUP_CRON_FREQUENCY
(crontab -l ; echo "$BACKUP_CRON_FREQUENCY $(pwd)/scripts/db_backup_script.sh >> $(pwd)/cron.log 2>&1") | crontab -
#(crontab -l ; echo "*/5 * * * * docker exec --user www-data -it nextcloud-aio-nextcloud php occ files:scan --all") | crontab - 

echo "Cron job has been set up."
