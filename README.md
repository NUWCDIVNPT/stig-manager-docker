# Using Keycloak with TLS and CAC authentication

## Prerequisite: Browser CA trust

The examples use a server certificate for the host `localhost` which is signed by a demonstration CA named "csmig-CA". For the examples to work, you must (temporarily) import and trust this CA certificate, found at `certs/ca/csmig-ca.crt`.

> How you do this varies across operating systems. For Windows, you import the certficate into "Trusted Root Certification Authorities". You should remove the certficate when finished running the examples.

## Run the examples

The examples show Keycloak orchestrated two different ways:

- Keycloak natively runs a TLS stack and listens on a TLS port. To run this orchestration:
 
 ```
 docker-compose -f docker-compose-kc-native.yml up
 ```

- Keycloak runs behind nginx, which runs a TLS stack and listens on a TLS port. Nginx forwards traffic to Keycloak which is listening on an unencrypted HTTP port. To run this orchestration:

 ```
 docker-compose -f docker-compose-kc-nginx.yml up
 ```

In both cases, once STIG Manager starts point your browser at:

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

## Keycloak configuration
### Keycloak Authentication Flow

The Keycloak documentation describes [how to modify a realm's browser authentication flow to incude X.509 client certificates](https://www.keycloak.org/docs/latest/server_admin/#adding-x-509-client-certificate-authentication-to-a-browser-flow).

The built-in execution "X509/Validate Username Form" attempts to match certificate information to existing Keycloak user accounts and fails otherwise.

> The examples deploy a custom plugin [modified from this project](https://github.com/lscorcia/keycloak-cns-authenticator/) that extends the built-in execution to create new user accounts when an exisiting account is not found. The plugin file is `kc/create-x509-user.jar`. The examples volume mounts this file to the Keycloak container at `/opt/jboss/keycloak/standalone/deployments/create-x509-user.jar`


The examples import the realm file `kc/stigman_realm.json`, which is configures the Authentication flow to match a certificate Common Name (CN) to a Keycloak username.

### Keycloak keystores

#### DoD certificates

In both orchestrations (native TLS and reverse proxy), Keycloak requires a keystore that contains certficates for the DoD Root CA and Intermediate CAs used to sign CAC certficates. The examples provide the file `certs/dod/dod-id-[version].p12` for this purpose.

> The orchestrations volume mount this file to the Keycloak container at `/opt/jboss/keycloak/standalone/configuration/truststore.p12`

#### Server certificates

When Keycloak is orchestrated to provide native TLS (no reverse proxy), it requires a keystore that contains the server certificate and private key. The examples provide the file `certs/localhost/localhost.p12` for this purpose.

> The orchestrations volume mount this file to the Keycloak container at `/opt/jboss/keycloak/standalone/configuration/servercert.p12`

### Modifying `standalone-ha.xml`
#### Keycloak behind nginx

The example volume mounts the file `kc/standalone-ha.nginx.xml` to the Keycloak container at `/opt/jboss/keycloak/standalone/configuration/standalone-ha.xml`.

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

The example volume mounts the file `kc/standalone-ha.native.xml` to the Keycloak container at `/opt/jboss/keycloak/standalone/configuration/standalone-ha.xml`.

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

