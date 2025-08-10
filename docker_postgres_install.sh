#!/bin/bash

# Remember to replace [1a2b3c4d5e6f7g8h90] with your actual password in the commands below.
# Remember to change execution permissions with: chmod +x docker_postgres_install.sh

docker volume create --name vault

docker run --name vault-postgres \
    -p 5432:5432 \
    -e POSTGRES_USER=vault \
    -e POSTGRES_PASSWORD=[1a2b3c4d5e6f7g8h90] \
    -v vault:/var/lib/postgresql/data \
    postgres 

echo "Downloading PostgreSQL Container Image..."

# List the latest running container
docker container ls --latest