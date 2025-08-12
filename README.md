# Vault-Local & PostgreSQL Backend MacOS Set Up 👾

## Context 📖

I have a macOS and found most information online for Linux distributions using `systemd` for Vault to run as a service. Since macOS uses `launchctl` I had to learn about .plist files living in my `~/Library/LaunchAgents` directory.

I downloaded Vault through Homebrew and I knew I wanted Vault running in the background. Once I got the configuration set up and started the Vault server, I needed to load my `homebrew.mxcl.vault.plist` so that it was running as a service and didn't seal itself every time I closed out of my terminal.

Since Vault was downloaded with homebrew, my `.plist` file has content pointing to my `/opt/homebrew` directory. If you downloaded the Vault binary a different way, ensure your paths are pointed to the right place before starting these processes.

For my storage backend, I wanted to learn a little bit more about databases and use a PostgreSQL Container in my homelab server. 

It was fun learning throughout the process and thought to show it here for others in case they were running into the same issues. 

Thus, here we are! 🤓

## PostgreSQL 📈

I created a CentOS container in Proxmox using one of the provided templates. 

<img width="896" height="515" alt="Screenshot 2025-08-11 at 16 01 00" src="https://github.com/user-attachments/assets/97e08cd5-64bf-46d4-b8a8-1cd629b93df2" />


Once within the container, I needed to run `dnf upgrade -y` to install all the necessary packages. Afterwards I installed the PostgreSQL repo, installed the server, initialized, enabled to start at boot and started the service. This script can be found within the `px_psql_container.sh` file.

* Note to replace your password
* Change execution permissions with `chmod +x px_psql_container.sh`

1. Connect to the PostgreSQL shell as `postgres` root user:

```
sudo su postgres
```

2. Enter the PostgreSQL shell with:

```
psql
```

3. Create a new role and table in the postgres database

```
CREATE ROLE vault WITH LOGIN PASSWORD '1a2b3c4d5e6f7g8h9i0j';

CREATE TABLE vault_kv_store (
    parent_path TEXT COLLATE "C" NOT NULL,
    path TEXT COLLATE "C",
    key TEXT COLLATE "C",
    value BYTEA,
    CONSTRAINT pkey PRIMARY KEY (path, key)
);
# Output: CREATE TABLE

CREATE INDEX parent_path_idx ON vault_kv_store (parent_path);
# Output: CREATE INDEX

# For HA enabled, create a new table in the vault database
CREATE TABLE vault_ha_locks (
    ha_key TEXT COLLATE "C" NOT NULL,
    ha_identity TEXT COLLATE "C" NOT NULL,
    ha_value TEXT COLLATE "C",
    valid_until TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT ha_key PRIMARY KEY (ha_key)
);
# Output: CREATE TABLE

# Grant permissions to the vault user
GRANT ALL PRIVILEGES ON DATABASE postgres TO vault;
# Output: GRANT

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO vault;
# Output: GRANT
```

4. Find your `pg_hba.conf` & `postgresql.conf` files to ensure which hosts are allowed to connect and that the server is listening on port 5432.

In your `pg_hba.conf`

<img width="636" height="309" alt="Screenshot 2025-08-12 at 11 27 17" src="https://github.com/user-attachments/assets/a534dad7-164f-42ee-8ddd-c862a7d356ee" />



In your `postgresql.conf`

<img width="747" height="212" alt="Screenshot 2025-08-12 at 11 29 04" src="https://github.com/user-attachments/assets/296271bc-86a0-46a8-96bd-726f835ea046" />
 


5. Run `hostname -I` in your container to get the correct IP. 

6. Test the connection to the postgres database in a new terminal:

`psql postgresql://vault:<password>@<IP>:5432/postgres`

7. Once connection is successful, add the storage line to the vault.hcl configuration file.

```
storage "postgresql" {
  connection_url = "postgresql://vault:<password>@<IP>:5432/postgres"
}
```

## Vault 🔐

Once you have your postgresql backend set up and added to your vault.hcl configuration file, add the remaining necessary content for your vault server to start and run.

Note that TLS is disabled, if you'd like to have it enabled, change it to `0` and add the necessary lines that are currently commented out.

* Recommended putting this within your `vault.d` directory saved as a `vault.hcl` config file.

```
storage "postgresql" {
  connection_url = "postgresql://vault:<password>@<IP>:5432/postgres"
}

listener "tcp" {
  address            = "0.0.0.0:8200"
  tls_disable        = 1
# tls_cert_file      = "/absolute/path/to/vault.crt"
# tls_key_file       = "/absolute/path/to/vault.key"
# tls_client_ca_file = "/absolute/path/to/rootvaultCA.crt"
}

cluster_addr  = "http://127.0.0.1:8201"
api_addr      = "http://127.0.0.1:8200"
ui = true
log_level = "INFO"
disable_mlock = true
```

Run `vault server -config=/absolute/path/to/vault.d/vault.hcl`

In another terminal run the following commands:

Run `lsof -i :8200` to ensure vault is listening on port 8200. You can also try `ps aux | grep vault`

### Initialize Vault

Set the env variables:

`export VAULT_ADDR='http://127.0.0.1:8200`
`export VAULT_SKIP_VERIFY=true`

Run `vault operator init -key-shares=3 -key-threshold=2` or whatever seal method you've configured. By default, Vault uses Shamir as its unseal method.

### Unseal Vault

Run `vault operator unseal` with the unseal keys you received after initializing.

### Vault Login

Run `vault login` with the root token that was provided while initializing. 

### Vault as a Service

Once the vault server is initialized and unsealed, open a new terminal to add Vault as a service so it can run in the background on you macOS.

Within your `~/Library/LaunchAgents` directory, create a file named `homebrew.mxcl.vault.plist`. I added a few lines for Proxmox as Vault requires the PostgreSQL container to run in order to write data to it. If the container fails to start, it will affect the Vault server and you'll get some errors.

Add the file contents and run the following, while the vault server is still running.

* Before loading the service, add `vault.out.log && vault.err.log` to your `/vault.d` directory, where your `vault.hcl` file lives.

`launchctl load homebrew.mxcl.vault.plist`

Run this command to ensure vault is running on your macOS as a service:
`launchctl list | grep vault`

Now that you've got vault running as a service, you can close out the terminal where you started the server. 

Run `vault status` to see if everything is configured as you wanted. You should see your seal method, as well as `postgresql` storage type and HA (if you had it enabled).

<img width="381" height="200" alt="Screenshot 2025-08-12 at 11 43 09" src="https://github.com/user-attachments/assets/f7534ae4-6a5e-4445-800a-7c96405d5eb3" />


## Troubleshooting 😤

### PostgreSQL & Vault Migration

I came across many many **many** errors, especially while configuring postgresql as a storage backend. Specifically: 

```
WARNING! Unable to read storage migration status.
2025-08-09T23:32:20.664-0400 [INFO]  proxy environment: http_proxy="" https_proxy="" no_proxy=""
2025-08-09T23:32:20.697-0400 [WARN]  storage migration check error: error="ERROR: relation \"vault_kv_store\" does not exist (SQLSTATE 42P01)"
```

This essentially means you may have created your table in a different database and Vault can't find the table with the user/password info in your connection URL. Just ensure you're pointing to the right database so Vault can find it and bind to it.

### Launchd Loading `homebrew.mxcl.vault.plist`

If you're receiving: 

```
Error checking seal status: Get "http://127.0.0.1:8200/v1/sys/seal-status": dial tcp 127.0.0.1:8200: connect: connection refused
```

Launchd is in a loop and you may have to unload and reload the Vault service. Ensure PostgreSQL container is running.

If your vault server is still running manually, run:

```
launchctl unload ~/Library/LaunchAgents/homebrew.mxcl.vault.plist 2>/dev/null || true

# Wait a minute

launchctl load ~/Library/LaunchAgents/homebrew.mxcl.vault.plist
```

Then verify that it's running with:
`launchctl list | grep vault`

Also try tailing the logs with:
`tail -f /absolute/path/to/vault.d/logs/vault.out.log`

Check that everything is running smoothly with `vault status` and you should see postgres as your storage. 

## References

[Vault PostgreSQL Configuration](https://developer.hashicorp.com/vault/docs/configuration/storage/postgresql)

[How to Install PostgreSQL on CentOS 9 + Create Roles and Databases](https://www.hostinger.com/tutorials/how-to-install-postgresql-on-centos)

[PostgreSQL Download](https://www.postgresql.org/download/)
