#!/bin/bash

set -euxo pipefail

# Update the system and install necessary packages
sudo dnf upgrade -y

# Got to: https://www.postgresql.org/download/ to find the latest version you need
# For Fedora or CentOS, follow the following steps to install PostgreSQL

# Install the PostgreSQL repository RPM
sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm

# If there's another built-in PostgreSQL version, remove it
sudo dnf -qy module disable postgresql

echo "Built-in PostgreSQL module disabled (if it existed)."

# Install PostgreSQL server
sudo dnf install -y postgresql17-server

echo "PostgreSQL-17 server installed."

# Initialize the PostgreSQL database
sudo /usr/pgsql-17/bin/postgresql17-setup initdb

echo "PostgreSQL database initialized."

# Enable the PostgreSQL service to start on boot
sudo systemctl enable postgresql-17

echo "PostgreSQL service enabled to start on boot."

# Start the PostgreSQL service
sudo systemctl start postgresql-17

# Check the status of the PostgreSQL service
sudo systemctl status postgresql-17