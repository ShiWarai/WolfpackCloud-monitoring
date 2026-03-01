#!/usr/bin/env bash
set -e

/app/docker/docker-bootstrap.sh

STEP_CNT=4

echo_step() {
    cat <<EOF

######################################################################
Init Step ${1}/${STEP_CNT} [${2}] -- ${3}
######################################################################

EOF
}

# Initialize the database
echo_step "1" "Starting" "Applying DB migrations"
superset db upgrade
echo_step "1" "Complete" "Applying DB migrations"

# Create an admin user
echo_step "2" "Starting" "Setting up admin user"
superset fab create-admin \
    --username admin \
    --firstname Admin \
    --lastname User \
    --email admin@localhost \
    --password admin || true
echo_step "2" "Complete" "Setting up admin user"

# Create default roles and permissions
echo_step "3" "Starting" "Setting up roles and perms"
superset init
echo_step "3" "Complete" "Setting up roles and perms"

if [ "$SUPERSET_LOAD_EXAMPLES" = "yes" ]; then
    echo_step "4" "Starting" "Loading examples"
    superset load_examples --force
    echo_step "4" "Complete" "Loading examples"
else
    echo_step "4" "Skipping" "Loading examples"
fi

echo "Init complete."
echo ""
echo "NOTE: Default dashboards will be provisioned by superset-provision container"
echo "      after Superset web server is healthy."
