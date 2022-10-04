**NOTE:** *Information on this topic is now being maintained in the [stigman-orchestration repository.](https://github.com/NUWCDIVNPT/stigman-orchestration)*

# STIG Manager OSS docker-compose examples

Sample docker-compose orchestrations for the [STIG Manager OSS project](https://github.com/NUWCDIVNPT/stig-manager)

*The orchestrations are dependent on the [official MySQL 8 image](https://hub.docker.com/_/mysql) and a [custom Keycloak 11 image](https://hub.docker.com/r/nuwcdivnpt/stig-manager-auth).*

## Common step
- Clone this repository and change directory to the cloned working directory.

### Orchestration with unencrypted database session and password authentication
- If you wish the API to automatically fetch current STIG content, in the file `docker-compose.yml` uncomment the lines
```
      # - STIGMAN_INIT_IMPORT_STIGS=true
      # - STIGMAN_INIT_IMPORT_SCAP=true
```

- From your shell, execute `docker-compose up -d && docker-compose logs -f`
- When all the services have started, STIG Manager will output:
```
Server is listening on port 54000
API is available at /api
API documentation is available at /api-docs
Client is available at /
```
- Navigate to ```http://localhost:54000```
- Login using credentials "admin/password", as documented for [the demonstration Keycloak image](https://hub.docker.com/r/nuwcdivnpt/stig-manager-auth)
- Refer to the [STIG Manager documentation](https://nuwcdivnpt.github.io/stig-manager) to create your first Collection

### Orchestration with TLS encrypted database session and client certificate authentication

- If you wish the API to automatically fetch current STIG content, in the file `docker-compose-tls.yml` uncomment the lines
```
      # - STIGMAN_INIT_IMPORT_STIGS=true
      # - STIGMAN_INIT_IMPORT_SCAP=true
```

- From your shell, execute `docker-compose -f docker-compose-tls.yml up -d && docker-compose logs -f`
- When all the services have started, STIG Manager will output:
```
Server is listening on port 54000
API is available at /api
API documentation is available at /api-docs
Client is available at /
```
- Navigate to ```http://localhost:54000```
- Login using credentials "admin/password", as documented for [the demonstration Keycloak image](https://hub.docker.com/r/nuwcdivnpt/stig-manager-auth)
- Refer to the [STIG Manager documentation](https://nuwcdivnpt.github.io/stig-manager) to create your first Collection
