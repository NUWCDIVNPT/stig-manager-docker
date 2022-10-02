# STIG Manager with CAC Authentication

## Scope of the example

This project provides an example orchestration for deploying STIG Manager with support for user authentication incorporating the U.S. Department of Defense Common Access Card (CAC). **The example is provided as a proof of concept limited to connections from `localhost` and is NOT intended for production use.**

However, the concept demonstrated is applicable to a range of production deployments. For smaller teams, minor enhancements to the example may be all that is necessary to create an acceptable deployment.

## General architecture

![Keycloak native diagram](diagrams/kc-reverse-1.svg)

- The `nginx` reverse proxy executes a TLS stack with client certificate verification and listens on an exposed frontend HTTPS port.
- `nginx` proxies traffic to `stigman` and `keycloak` which are listening on unexposed backend HTTP ports.
- `stigman` communicates with `keycloak` via Keycloak's unexposed backend port using HTTP and with `mysql` via MySQL's unexposed backend port using the MySQL Protocol.
- End users located at `browser with CAC` connect to `nginx` on the exposed frontend HTTPS port and request resources from `stigman` and `keycloak`. These resources include the Keycloak authentication service, the STIG Manager API, and the STIG Manager Web App.

This general architecture can be implemented with a wide ramge of technologies, from bare-metal deployments to complex containerized orchestrations. The example uses a simple docker-compose orchestration. 

## Dependencies for running the example

- Recent Windows, Linux, or macOS
- CAC reader configured for your OS
- docker
- docker-compose
- Chrome, Edge, or Firefox browser

The example uses a server certificate issued to the host `localhost` and signed by a CA named `demoCA`. For the example to work, you must (temporarily) import trust in your browser for the `demoCA` certificate, found at [`certs/ca/demoCA.crt`](certs/ca/demoCA.crt).

> How you do this varies across operating systems and browsers. For Windows, you import the certificate into "Trusted Root Certification Authorities". You should remove the certificate when finished running the orchestrations.

## Fetching the example files

You have two options:

- If you have `git` installed, navigate to an appropriate directory and execute the command `git clone https://github.com/NUWCDIVNPT/stig-manager-cac-example.git`. Then change to the newly created directory `stig-manager-cac-example`.

- [Download a ZIP of this repository](https://github.com/NUWCDIVNPT/stig-manager-cac-example/archive/refs/heads/main.zip). Extract the archive to an appropriate directory and change to the newly extracted directory `stig-manager-cac-example-main`.
## Running the orchestration

```
docker-compose -p cac-example up
```

The orchestration has successfully bootstrapped when you see a `started` message like this from the STIG Manager API:

```
cac-example-stigman-1   | {"date":"2022-10-01T18:04:26.734Z","level":3,"component":"index","type":"started","data":{"durationS":21.180474449,"port":54000,"api":"/api","client":"/","documentation":"/docs"}}
```

The orchestration will continue to run until you type `Ctrl-C` to end it.

## Authenticating to STIG Manager with CAC

Once STIG Manager has started, navigate your browser to:

```
https://localhost/stigman/
```

The following sequence of events occur:

- Your browser starts the TLS Handshake with the `nginx` proxy.
- During the handshake, `nginx` sends a `Certificate Request` message to your browser.
- Your browser prompts you to chose a certificate from your CAC.
- The certificate you choose is provided to `nginx` in a `Certificate` message and the corresponding private key on your CAC is used by your browser to create a `Certificate Verify` message which authenticates the certificate.
- 
- The Web App redirects your browser to the Keycloak authorization endpoint.
- `nginx` proxies this authorization request and asks your browser to prompt for a certificate from your PIN-protected CAC.
- Your browser completes the Mutual TLS (mTLS) Handshake with `nginx` and forwards 
- After a successful authentication, Keycloak tries to match your certificate's Common Name (CN) to a Keycloak account. If necessary, it creates a new account using your CN and configure that account with the roles "Application Management" and "Create Collection".
- Keycloak will generate an OAuth2 token that contains your identity and application roles/scopes. This token is provided to the Web App for making requests to STIG Manager API endpoints.
- The Web App will display 

You can access the Keycloak admin pages by navigating to:

```
https://localhost/kc/admin
```

> After using Chrome to HTTPS connect to `https://localhost`, you may find Chrome will no longer make HTTP connections to `http://localhost:[ANY_PORT]`. Once you're finished with the example, see [this note](#to-clear-chrome-hsts-entry-for-localhost-perhaps) for how to remedy this.

## `nginx` configuration

`nginx` provides TLS service for the STIG Manager API and Keycloak. Client certificate authentication is **required** for access to the Keycloak `authorization_endpoint`. Client certificate authentication is **optional** for API endpoints because access to the API is controlled by OIDC/OAuth2 tokens.

The orchestration:

- volume mounts the file [`nginx/nginx.conf`](nginx/nginx.conf) to the `nginx` container at `/etc/nginx/nginx.conf`
- volume mounts the server certificate [`certs/localhost/localhost.crt`](certs/localhost/localhost.crt) to the `nginx` container at `/etc/nginx/cert.pem`
- volume mounts the server private key [`certs/localhost/localhost.key`](certs/localhost/localhost.key) to the `nginx` container at `/etc/nginx/privkey.pem`
- volume mounts the DoD CAs in [`certs/dod/Certificates_PKCS7_v5.9_DoD.pem.pem`](certs/dod/Certificates_PKCS7_v5.9_DoD.pem.pem) to the nginx container at `/etc/nginx/dod-certs.pem`

## Keycloak configuration
### Keycloak Authentication Flow

The Keycloak documentation describes [how to modify a realm's browser authentication flow to incude X.509 client certificates](https://www.keycloak.org/docs/latest/server_admin/#adding-x-509-client-certificate-authentication-to-a-browser-flow).

The built-in execution "X509/Validate Username Form" attempts to match certificate information to existing Keycloak user accounts and fails otherwise.

Both orchestrations import the realm file [`kc/stigman_realm.json`](kc/stigman_realm.json), which is configures the Authentication flow to match a certificate Common Name (CN) to a Keycloak username.

> The project includes a custom plugin [modified from this project](https://github.com/lscorcia/keycloak-cns-authenticator/) that extends the built-in execution to create new user accounts when an exisiting account is not found. The plugin file is `kc/create-x509-user.jar`. The orchestrations volume mount this file to the Keycloak container at `/opt/jboss/keycloak/standalone/deployments/create-x509-user.jar`



### Keycloak keystores

#### DoD certificates

In both orchestrations (native TLS and reverse proxy), Keycloak requires a keystore that contains certificates for the DoD Root CA and Intermediate CAs used to sign CAC certificates. 

> The project provides the file `certs/dod/dod-id-[version].p12` for this purpose. The orchestrations volume mount this file to the Keycloak container at `/opt/jboss/keycloak/standalone/configuration/truststore.p12`

#### Server certificates

When Keycloak is orchestrated to provide native TLS (no reverse proxy), it requires a keystore that contains the server certificate and private key. 

> The project provides the file `certs/localhost/localhost.p12` for this purpose. The orchestrations volume mount this file to the Keycloak container at `/opt/jboss/keycloak/standalone/configuration/servercert.p12`



## Notes
### Make pkcs12 archive from cert and private key

`openssl pkcs12 -export -name server-cert -in tls.crt -inkey tls.key -out tls.p12`

(Must set an export password because keytool step below requires one)

### Import pkcs12 archive into a JKS keystore

`keytool -importkeystore -destkeystore tls.jks -srckeystore tls.p12 -srcstoretype pkcs12 -alias server-cert`

### To clear Chrome HSTS entry (for localhost, perhaps)

`chrome://net-internals/#hsts` -  Delete domain security policies

`chrome://settings/clearBrowserData` - Cached images and files

