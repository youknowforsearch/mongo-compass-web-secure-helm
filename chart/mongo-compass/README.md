# Mongo Compass Web Helm Chart

Deploy a web-based MongoDB Compass UI on Kubernetes, with optional **OAuth2 Proxy** integration for **Keycloak** OIDC authentication.

## Features

- Web-based MongoDB Compass in the browser
- Optional OAuth2 Proxy sidecar for Keycloak (OIDC) login
- MongoDB URI from values or Kubernetes secret
- Gateway API HTTPRoute for Envoy Gateway, or classic Ingress
- HPA and standard production knobs

## Prerequisites

- Kubernetes cluster
- Helm 3.x
- (Optional) Keycloak realm and OIDC client for authenticated access
- (Optional) Envoy Gateway with a configured `Gateway` resource

## Install

### Add the Helm repository

```bash
helm repo add mongo-compass-web-secure https://youknowforsearch.github.io/mongo-compass-web-secure-helm
helm repo update
```

### Basic install (no authentication)

```bash
helm install mongo-compass mongo-compass-web-secure/mongo-compass \
  --set defaultMongodbUri="mongodb://user:password@host:27017/db"
```

### Install with Keycloak (OAuth2 Proxy)

#### 1. Create a Keycloak client

In your Keycloak realm:

1. Create a **confidential** client (e.g. `mongo-compass`)
2. Enable **Standard flow**
3. Set **Valid Redirect URIs** to `https://compass.example.com/oauth2/callback`
4. Copy the **Client ID** and **Client secret**

#### 2. Generate a cookie secret

```bash
python -c "import os,base64; print(base64.urlsafe_b64encode(os.urandom(32)).decode())"
```

#### 3. Install the chart

```bash
helm install mongo-compass mongo-compass-web-secure/mongo-compass \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set ingress.hosts[0].host=compass.example.com \
  --set ingress.hosts[0].paths[0].path=/ \
  --set ingress.hosts[0].paths[0].pathType=Prefix \
  --set ingress.tls[0].secretName=compass-tls \
  --set ingress.tls[0].hosts[0]=compass.example.com \
  --set oauth2Proxy.enabled=true \
  --set oauth2Proxy.oidc.issuerURL=https://keycloak.example.com/realms/myrealm \
  --set oauth2Proxy.clientID=mongo-compass \
  --set oauth2Proxy.clientSecret=YOUR_CLIENT_SECRET \
  --set oauth2Proxy.cookieSecret=YOUR_COOKIE_SECRET \
  --set defaultMongodbUri="mongodb://user:password@host:27017/db"
```

When ingress or HTTPRoute is enabled, the OAuth callback URL is derived automatically as `https://<hostname>/oauth2/callback`. Override with `oauth2Proxy.redirectURL` if needed.

### Install with Envoy Gateway (HTTPRoute)

Use `httpRoute` instead of `ingress` when routing through [Envoy Gateway](https://gateway.envoyproxy.io/):

```bash
helm install mongo-compass mongo-compass-web-secure/mongo-compass \
  --set httpRoute.enabled=true \
  --set httpRoute.parentRefs[0].name=envoy-gateway \
  --set httpRoute.parentRefs[0].namespace=envoy-gateway-system \
  --set httpRoute.parentRefs[0].sectionName=https \
  --set httpRoute.hostnames[0]=compass.example.com \
  --set oauth2Proxy.enabled=true \
  --set oauth2Proxy.oidc.issuerURL=https://keycloak.example.com/realms/myrealm \
  --set oauth2Proxy.clientID=mongo-compass \
  --set oauth2Proxy.clientSecret=YOUR_CLIENT_SECRET \
  --set oauth2Proxy.cookieSecret=YOUR_COOKIE_SECRET \
  --set defaultMongodbUri="mongodb://user:password@host:27017/db"
```

Ensure your Envoy `Gateway` listener and TLS certificate are configured separately. The chart creates an `HTTPRoute` that attaches to the Gateway via `parentRefs` and forwards traffic to the Service (OAuth2 Proxy port when auth is enabled).

`ingress.enabled` and `httpRoute.enabled` are mutually exclusive.

### Using an existing Kubernetes secret

Create a secret with keys `client-id`, `client-secret`, and `cookie-secret`:

```bash
kubectl create secret generic mongo-compass-oauth2 \
  --from-literal=client-id=mongo-compass \
  --from-literal=client-secret=YOUR_CLIENT_SECRET \
  --from-literal=cookie-secret=YOUR_COOKIE_SECRET
```

Then install with:

```bash
helm install mongo-compass mongo-compass-web-secure/mongo-compass \
  --set httpRoute.enabled=true \
  --set httpRoute.hostnames[0]=compass.example.com \
  --set oauth2Proxy.enabled=true \
  --set oauth2Proxy.existingSecret=mongo-compass-oauth2 \
  --set oauth2Proxy.secret.create=false \
  --set oauth2Proxy.oidc.issuerURL=https://keycloak.example.com/realms/myrealm \
  --set defaultMongodbUri="mongodb://user:password@host:27017/db"
```

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Deployment replicas | `1` |
| `image.repository` | Compass Web image | `haohanyang/compass-web` |
| `image.tag` | Image tag | `""` (uses `appVersion`) |
| `service.port` | Mongo Compass container port | `8080` |
| `defaultMongodbUri` | Default MongoDB URI in UI | `mongodb://user:password@host:port/db` |
| `mongodbUriFromSecret.secretName` | Secret containing MongoDB URI | `""` |
| `mongodbUriFromSecret.secretKey` | Key in secret for MongoDB URI | `""` |
| `ingress.enabled` | Enable Ingress | `false` |
| `httpRoute.enabled` | Enable Gateway API HTTPRoute (Envoy Gateway) | `false` |
| `httpRoute.parentRefs` | Gateway parent references | see `values.yaml` |
| `httpRoute.hostnames` | Public hostnames for the route | `["chart-example.local"]` |
| `httpRoute.scheme` | URL scheme for OAuth callback derivation | `https` |
| `httpRoute.rules` | HTTPRoute match/filter rules | PathPrefix `/` |
| `oauth2Proxy.enabled` | Enable OAuth2 Proxy sidecar | `false` |
| `oauth2Proxy.oidc.issuerURL` | Keycloak realm issuer URL | `""` |
| `oauth2Proxy.clientID` | Keycloak OIDC client ID | `""` |
| `oauth2Proxy.clientSecret` | Keycloak OIDC client secret | `""` |
| `oauth2Proxy.cookieSecret` | Base64 cookie encryption secret | `""` |
| `oauth2Proxy.redirectURL` | OAuth callback URL | auto from httpRoute/ingress |
| `oauth2Proxy.existingSecret` | Pre-created OAuth2 credentials secret | `""` |
| `oauth2Proxy.port` | OAuth2 Proxy listen port | `4180` |
| `oauth2Proxy.emailDomains` | Allowed email domains | `["*"]` |
| `oauth2Proxy.scopes` | OIDC scopes | `["openid","profile","email"]` |

When `oauth2Proxy.enabled` is `true`, the Service exposes port `4180` and routes traffic through OAuth2 Proxy before Mongo Compass.

## Architecture

```text
User -> Envoy Gateway -> HTTPRoute -> Service:4180 -> OAuth2 Proxy -> localhost:8080 -> Mongo Compass
                                              |
                                              v
                                         Keycloak OIDC
```

With Ingress instead of HTTPRoute, replace `HTTPRoute` with `Ingress` in the diagram above.

## License

Apache 2.0
