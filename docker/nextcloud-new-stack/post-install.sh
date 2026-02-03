#!/bin/bash
# Post-install script for Nextcloud custom stack
# Run this after initial setup completes in the web UI

CONTAINER="nextcloud"

echo "Running Nextcloud post-install configuration..."

# Add indices for better performance
echo "Adding database indices..."
docker exec -u www-data $CONTAINER php occ db:add-missing-indices

# Add missing columns
echo "Adding missing columns..."
docker exec -u www-data $CONTAINER php occ db:add-missing-columns

# Add missing primary keys
echo "Adding missing primary keys..."
docker exec -u www-data $CONTAINER php occ db:add-missing-primary-keys

# Convert filecache bigint (can take a while on large installs)
echo "Converting to bigint (this may take a moment)..."
docker exec -u www-data $CONTAINER php occ db:convert-filecache-bigint --no-interaction

# Set default phone region (change as needed)
echo "Setting default phone region..."
docker exec -u www-data $CONTAINER php occ config:system:set default_phone_region --value="US"

# Set maintenance window start (3 AM UTC)
echo "Setting maintenance window..."
docker exec -u www-data $CONTAINER php occ config:system:set maintenance_window_start --type=integer --value=3

# Enable cron as background job method
echo "Setting background jobs to cron..."
docker exec -u www-data $CONTAINER php occ background:cron

echo ""
echo "Post-install configuration complete!"
echo ""
echo "Recommended: Set up a cron job for background tasks:"
echo "  crontab -e"
echo "  */5 * * * * docker exec -u www-data nextcloud php cron.php"
