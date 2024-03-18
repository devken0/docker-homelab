#!/usr/bin/env bash

# Prompt user for input
read -p "Enter the path to the file you want to monitor: " FILE_TO_MONITOR
read -p "Enter the commit message: " COMMIT_MESSAGE
read -p "Enter the branch name: " BRANCH
read -p "Enter the GitHub repository URL: " REPO_URL
read -p "Enter your GitHub username: " GIT_USERNAME
read -p "Enter your GitHub email address: " GIT_EMAIL

# Create the script with provided inputs
mkdir ~/bin

cat <<EOF > $HOME/bin/github_commit_script.sh
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
    git commit -m "\$COMMIT_MESSAGE (github_commit_script.sh)"
    git push "\$REPO_URL" "\$BRANCH"
    echo "Changes committed and pushed successfully. $CURRENT_DATE_TIME"
fi
EOF

cat <<EOF > $HOME/bin/db_backup_script.sh
#!/usr/bin/env bash

# Cleanup script for photoprism database backups

backup_dir="$HOME/docker-homelab/photoprism/storage/backup/mysql"

# Get today's date in the format yyyy-mm-dd
current_date=$(date +"%Y-%m-%d")

# Calculate the date 3 days ago
three_days_ago=$(date -d "3 days ago" +"%Y-%m-%d")

# List all files in the backup directory
files=$(ls "$backup_dir")

# Loop through each file
for file in $files; do
    # Extract the date from the filename (assuming the format is yyyy-mm-dd.mysql)
    file_date=$(echo "$file" | cut -d'.' -f1)

    # Compare the file date with three days ago
    if [[ "$file_date" < "$three_days_ago" ]]; then
        # If the file is older than three days, delete it
        rm "$backup_dir/$file"
        echo "Deleted $file"
    fi
done
docker exec photoprism photoprism backup -i -f
docker exec paperless-webserver-1 document_exporter ../export
EOF

# Make the script executable
chmod +x ~/bin/github_commit_script.sh
chmod +x ~/bin/db_backup_script.sh.sh

# Add the cron job
read -p "Enter the frequency for the cron job github_commit_script.sh (e.g., * * * * * for every minute): " COMMIT_CRON_FREQUENCY
(crontab -l ; echo "$COMMIT_CRON_FREQUENCY $HOME/bin/github_commit_script.sh") | crontab -
#(crontab -l ; echo "*/30 * * * * rm $(pwd)/cron_log.log") | crontab -
read -p "Enter the frequency for the cron job db_backup_script.sh (e.g., * * * * * for every minute): " BACKUP_CRON_FREQUENCY
(crontab -l ; echo "$BACKUP_CRON_FREQUENCY $HOME/bin/db_backup_script.sh >> $(pwd)/cron.log 2>&1") | crontab -
# Logs cleanup 
(crontab -l ; echo "0 * * * * rm $(pwd)/cron.log") | crontab -
#(crontab -l ; echo "*/5 * * * * docker exec --user www-data -it nextcloud-aio-nextcloud php occ files:scan --all") | crontab - 

echo "Cron job has been set up."
