#!/bin/bash

# The command below will start a second Keycloak instance on a port offset from the other instance.
# The second instance will export the indicated realm and attach itself to the terminal.
# Keycloak will log the message: "Admin console listening on http://127.0.0.1:<port>"
# You should press Ctrl-C after this message is logged.

docker exec -it ${1:-stig-manager-auth} /opt/jboss/keycloak/bin/standalone.sh \
-Djboss.socket.binding.port-offset=100 \
-Dkeycloak.migration.action=export \
-Dkeycloak.migration.provider=singleFile \
-Dkeycloak.migration.realmName=stigman \
-Dkeycloak.migration.usersExportStrategy=REALM_FILE \
-Dkeycloak.migration.file=/tmp/stigman_realm.json

# Press Ctrl-C here to stop Keycloak and execute this line
docker cp ${1:-stig-manager-auth}:/tmp/stigman_realm.json .

