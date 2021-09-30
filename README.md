# Using Keycloak with TLS and CAC authentication

## Prerequisite: Browser CA trust

The project uses a server certificate for the host `localhost` which is signed by a demonstration CA named "csmig-CA". For the examples to work, you must (temporarily) import and trust this CA certificate, found at [`certs/ca/csmig-ca.crt`](certs/ca/csmig-ca.crt).

> How you do this varies across operating systems. For Windows, you import the certficate into "Trusted Root Certification Authorities". You should remove the certficate when finished running the orchestrations.

## Quick links

- [Running the orchestrations](#running-the-orchestrations)
  - [Keycloak native TLS](#keycloak-natively-runs-a-tls-stack)
  - [Keycloak behind nginx](#keycloak-runs-behind-nginx)
- [Nginx configuration](#nginx-configuration)
  - [Keycloak native TLS](#keycloak-natively-runs-a-tls-stack-1)
  - [Keycloak behind nginx](#keycloak-runs-behind-nginx-1)
- [Keycloak configuration](#keycloak-configuration)
  - [Authenication flow](#keycloak-authentication-flow)
  - [Keystores](#keycloak-keystores)
  - [Modifying standalone-ha.xml](#modifying-standalone-haxml)

## Running the orchestrations

The project demonstrates Keycloak orchestrated two different ways:

### Keycloak natively runs a TLS stack

![Keycloak native diagram](diagrams/kc-native.svg)

- Keycloak runs a TLS stack with client certificate verification and listens on an exposed TLS port
- Nginx runs a TLS stack without client certificate verification and listens on an exposed TLS port. Nginx forwards traffic to the API listening on an unexposed HTTP port.

To run this orchestration, pass the file [`docker-compose-kc-native.yml`](docker-compose-kc-native.yml) to `docker-compose up`:
 
 ```
 docker-compose -f docker-compose-kc-native.yml up
 ```

### Keycloak runs behind nginx

![Keycloak reverse diagram](diagrams/kc-reverse.svg)


- Nginx runs a TLS stack with client certificate verification and listens on an exposed TLS port. Nginx forwards traffic to both the API and Keycloak which are listening on unexposed HTTP ports
 
To run this orchestration, pass the file [`docker-compose-kc-nginx.yml`](docker-compose-kc-nginx.yml) to `docker-compose up`:

 ```
 docker-compose -f docker-compose-kc-nginx.yml up
 ```
### Connecting to STIG Manager and Keycloak

For both orchetrations, once STIG Manager starts point your browser at:

```
https://localhost/stigman/
```

For the Keycloak native orchestration, you can access Keycloak at:

```
https://localhost:8443/
```

For the Keycloak reverse proxy orchestration, you can access Keycloak at:

```
https://localhost/auth/
```

## nginx configuration

### Keycloak natively runs a TLS stack

In this orchestratiuon, nginx provides TLS service to the API only. Client certificate authentication is unnecessary because access to the API is controlled by OIDC/OAuth2 tokens.

The orchestration:

- volume mounts the file [`nginx/nginx-api.conf`](nginx/nginx-api.conf) to the nginx container at `/etc/nginx/nginx.conf`
- volume mounts the server certificate [`certs/localhost/localhost.crt`](certs/localhost/localhost.crt) to the nginx container at `/etc/nginx/cert.pem`
- volume mounts the server private key [`certs/localhost/localhost.key`](certs/localhost/localhost.key) to the nginx container at `/etc/nginx/privkey.pem`

### Keycloak runs behind nginx

In this orchestratiuon, nginx provides TLS service to the API and Keycloak. Client certificate authentication is required for access to the Keycloak authorization_endpoint. Client certificate authentication is unnecessary for API endpoints because access to the API is controlled by OIDC/OAuth2 tokens.

The orchestration:

- volume mounts the file [`nginx/nginx-api-kc.conf`](nginx/nginx-api-kc.conf) to the nginx container at `/etc/nginx/nginx.conf`
- volume mounts the server certificate [`certs/localhost/localhost.crt`](certs/localhost/localhost.crt) to the nginx container at `/etc/nginx/cert.pem`
- volume mounts the server private key [`certs/localhost/localhost.key`](certs/localhost/localhost.key) to the nginx container at `/etc/nginx/privkey.pem`
- volume mounts the DoD CAs in [`certs/dod/dod-id-5.9.pem`](certs/dod/dod-id-5.9.pem) to the nginx container at `/etc/nginx/dod-id.pem`

## Keycloak configuration
### Keycloak Authentication Flow

The Keycloak documentation describes [how to modify a realm's browser authentication flow to incude X.509 client certificates](https://www.keycloak.org/docs/latest/server_admin/#adding-x-509-client-certificate-authentication-to-a-browser-flow).

The built-in execution "X509/Validate Username Form" attempts to match certificate information to existing Keycloak user accounts and fails otherwise.

Both orchestrations import the realm file [`kc/stigman_realm.json`](kc/stigman_realm.json), which is configures the Authentication flow to match a certificate Common Name (CN) to a Keycloak username.

> The project includes a custom plugin [modified from this project](https://github.com/lscorcia/keycloak-cns-authenticator/) that extends the built-in execution to create new user accounts when an exisiting account is not found. The plugin file is `kc/create-x509-user.jar`. The orchestrations volume mount this file to the Keycloak container at `/opt/jboss/keycloak/standalone/deployments/create-x509-user.jar`



### Keycloak keystores

#### DoD certificates

In both orchestrations (native TLS and reverse proxy), Keycloak requires a keystore that contains certficates for the DoD Root CA and Intermediate CAs used to sign CAC certficates. 

> The project provides the file `certs/dod/dod-id-[version].p12` for this purpose. The orchestrations volume mount this file to the Keycloak container at `/opt/jboss/keycloak/standalone/configuration/truststore.p12`

#### Server certificates

When Keycloak is orchestrated to provide native TLS (no reverse proxy), it requires a keystore that contains the server certificate and private key. 

> The project provides the file `certs/localhost/localhost.p12` for this purpose. The orchestrations volume mount this file to the Keycloak container at `/opt/jboss/keycloak/standalone/configuration/servercert.p12`

### Modifying `standalone-ha.xml`
#### Keycloak behind nginx

The orchestration volume mounts the file [`kc/standalone-ha.nginx.xml`](kc/standalone-ha.nginx.xml) to the Keycloak container at `/opt/jboss/keycloak/standalone/configuration/standalone-ha.xml`.

The file includes [these lines](https://github.com/NUWCDIVNPT/stig-manager-docker-compose/blob/8e1c24a1468e215bdb06a1e451a58bee2b7cef34/tls/kc/standalone-ha.nginx.xml#L538-L557) as children of the element `<server><profile><subsystem xmlns="urn:jboss:domain:keycloak-server:1.1">`

```
<spi name="x509cert-lookup">
  <default-provider>nginx</default-provider>
  <provider name="nginx" enabled="true">
      <properties>
          <property name="sslClientCert" value="ssl-client-cert"/>
          <property name="sslCertChainPrefix" value="USELESS"/>
          <property name="certificateChainLength" value="2"/>
      </properties>
  </provider>
</spi>
<spi name="truststore">
  <provider name="file" enabled="true">
      <properties>
          <property name="file" value="/opt/jboss/keycloak/standalone/configuration/truststore.p12"/>
          <property name="password" value="password"/>
          <property name="hostname-verification-policy" value="WILDCARD"/>
          <property name="enabled" value="true"/>
      </properties>
  </provider>
</spi>
```

#### Keycloak native TLS

The orchestration volume mounts the file [`kc/standalone-ha.native.xml`](kc/standalone-ha.native.xml) to the Keycloak container at `/opt/jboss/keycloak/standalone/configuration/standalone-ha.xml`.

The file includes [these lines](https://github.com/NUWCDIVNPT/stig-manager-docker-compose/blob/8e1c24a1468e215bdb06a1e451a58bee2b7cef34/tls/kc/standalone-ha.native.xml#L58-L67) as children of `<server><management><security-realms>`

```
<security-realm name="ssl-realm">
  <server-identities>
      <ssl>
          <keystore path="servercert.p12" relative-to="jboss.server.config.dir" keystore-password="password"/>
      </ssl>
  </server-identities>
  <authentication>
      <truststore path="truststore.p12" relative-to="jboss.server.config.dir" keystore-password="password"/>
  </authentication>
</security-realm>      
```

and [this line](https://github.com/NUWCDIVNPT/stig-manager-docker-compose/blob/8e1c24a1468e215bdb06a1e451a58bee2b7cef34/tls/kc/standalone-ha.native.xml#L644) as a child of `<server><profile><subsystem xmlns="urn:jboss:domain:undertow:12.0">`

```
<https-listener name="https" socket-binding="https" security-realm="ssl-realm" verify-client="REQUESTED"/>
```

## Notes
### Make pkcs12 archive from cert and private key

`openssl pkcs12 -export -name server-cert -in tls.crt -inkey tls.key -out tls.p12`

(Must set an export password because keytool step below requires one)

### Import pkcs12 archive into a JKS keystore

`keytool -importkeystore -destkeystore tls.jks -srckeystore tls.p12 -srcstoretype pkcs12 -alias server-cert`

### To clear Chrome HSTS entry (for localhost, perhaps)

`chrome://net-internals/#hsts` -  Delete domain security policies

`chrome://settings/clearBrowserData` - Cached images and files

