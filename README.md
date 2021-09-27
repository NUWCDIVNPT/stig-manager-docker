## Modifying `keycloak-ha.xml`
### Keycloak behind nginx
Add these lines:

https://github.com/NUWCDIVNPT/stig-manager-docker-compose/blob/8e1c24a1468e215bdb06a1e451a58bee2b7cef34/tls/kc/standalone-ha.nginx.xml#L538-L557

### Keycloak native TLS
Add these lines:

https://github.com/NUWCDIVNPT/stig-manager-docker-compose/blob/8e1c24a1468e215bdb06a1e451a58bee2b7cef34/tls/kc/standalone-ha.native.xml#L58-L67

and this line:

https://github.com/NUWCDIVNPT/stig-manager-docker-compose/blob/8e1c24a1468e215bdb06a1e451a58bee2b7cef34/tls/kc/standalone-ha.native.xml#L644

## Notes
### Make pkcs12 archive from cert and private key

`openssl pkcs12 -export -name server-cert -in tls.crt -inkey tls.key -out tls.p12`

(Must set an export password because keytool step below requires one)

### Import pkcs12 archive into a JKS keystore

`keytool -importkeystore -destkeystore tls.jks -srckeystore tls.p12 -srcstoretype pkcs12 -alias server-cert`

### To clear Chrome HSTS entry (for localhost, perhaps)

`chrome://net-internals/#hsts` -  Delete domain security policies

`chrome://settings/clearBrowserData` - Cached images and files

