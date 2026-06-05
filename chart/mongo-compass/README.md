# Mongo Compass Web Helm Chart

Deploy a web-based MongoDB Compass UI on Kubernetes. As of chart `1.1.0` /
compass-web `0.5.0`, the app supports **native OIDC/OAuth and Basic
authentication** built in — no sidecar required. The legacy **OAuth2 Proxy**
sidecar for **Keycloak** is still available, and **HTTPRoute** is supported for
API Gateway integration.

## Features

- Web-based MongoDB Compass in the browser
- **Native OIDC/OAuth authentication** (Authorization Code + PKCE), e.g. Keycloak — built into compass-web 0.5.0+
- **Native Basic auth**
- **Mongo Shell** (`enable-shell`)
- **GenAI** query/aggregation generation (OpenAI key, model, sample documents, custom prompts)
- **Edit connections** in the UI, with optional master-password encryption
- App name and base route configuration
- Optional OAuth2 Proxy sidecar for Keycloak (OIDC) login (legacy alternative to native auth)
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
helm repo add mongo-compass-web-secure https://youknowforsearch.github.io/mongo-compass-web-helm
helm repo update
```

### Basic install (no authentication)

```bash
helm install mongo-compass mongo-compass-web-secure/mongo-compass \
  --set defaultMongodbUri="mongodb://user:password@host:27017/db"
```

### Install with native OIDC/OAuth (recommended, compass-web 0.5.0+)

compass-web now performs the OIDC flow itself and protects the UI, REST API and
MongoDB/shell websockets. This replaces the need for the OAuth2 Proxy sidecar.

#### 1. Create an OIDC client

In your IdP (e.g. Keycloak realm):

1. Create a client (confidential or public) for compass-web
2. Enable **Standard flow** (Authorization Code + PKCE)
3. Set **Valid Redirect URIs** to `https://compass.example.com/auth/callback`
   (add your `baseRoute` prefix if you use one, e.g. `/compass/auth/callback`)

#### 2. Generate a session secret

```bash
openssl rand -base64 32
```

#### 3. Install the chart

```bash
helm install mongo-compass mongo-compass-web-secure/mongo-compass \
  --set httpRoute.enabled=true \
  --set httpRoute.hostnames[0]=compass.example.com \
  --set auth.oidc.enabled=true \
  --set auth.oidc.issuer=https://keycloak.example.com/realms/myrealm \
  --set auth.oidc.clientId=compass-web \
  --set auth.oidc.clientSecret=YOUR_CLIENT_SECRET \
  --set auth.sessionSecret=YOUR_SESSION_SECRET \
  --set defaultMongodbUri="mongodb://user:password@host:27017/db"
```

When `httpRoute`/`ingress` is enabled, the callback URL (`CW_OIDC_REDIRECT_URI`)
is derived automatically as `https://<hostname><baseRoute>/auth/callback`.
Override it with `auth.oidc.redirectUri`. The client secret and session secret
are stored in a chart-managed `Secret` (or supply your own via
`secret.existingSecret`).

Available auth routes (served by compass-web): `/auth/login`,
`/auth/login/oidc`, `/auth/callback`, `/auth/logout`, `/auth/me`.

### Install with native Basic auth

```bash
helm install mongo-compass mongo-compass-web-secure/mongo-compass \
  --set auth.basic.enabled=true \
  --set auth.basic.username=admin \
  --set auth.basic.password=secret \
  --set defaultMongodbUri="mongodb://user:password@host:27017/db"
```

### Enable other features (shell, GenAI, edit connections)

```bash
helm install mongo-compass mongo-compass-web-secure/mongo-compass \
  --set shell.enabled=true \
  --set editConnections.enabled=true \
  --set editConnections.masterPassword=YOUR_MASTER_PASSWORD \
  --set genAI.enabled=true \
  --set genAI.openaiApiKey=YOUR_OPENAI_KEY \
  --set genAI.openaiModel=gpt-5-mini \
  --set appName="My Compass" \
  --set baseRoute=/compass \
  --set defaultMongodbUri="mongodb://user:password@host:27017/db"
```

### Install with Keycloak (OAuth2 Proxy, legacy)

> The OAuth2 Proxy sidecar is a legacy alternative. Prefer native OIDC above.
> `auth.oidc.enabled` and `oauth2Proxy.enabled` are mutually exclusive.


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

#### For native auth / app secrets (`secret.existingSecret`)

Create a Secret containing only the keys you use:
`oidc-client-secret`, `session-secret`, `basic-auth-password`,
`openai-api-key`, `master-password`. Then set
`--set secret.existingSecret=my-compass-secret --set secret.create=false`.

#### For the OAuth2 Proxy sidecar (`oauth2Proxy.existingSecret`)

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
| `appName` | Application name shown in the UI (`CW_APP_NAME`) | `""` |
| `baseRoute` | Base route prefix, e.g. `/compass` (`CW_BASE_ROUTE`) | `""` |
| `shell.enabled` | Enable the Mongo Shell (`CW_ENABLE_SHELL`) | `false` |
| `editConnections.enabled` | Allow adding/editing connections in the UI | `false` |
| `editConnections.masterPassword` | Master password to encrypt saved connections | `""` |
| `genAI.enabled` | Enable GenAI query/aggregation features | `false` |
| `genAI.sampleDocuments` | Upload sample documents to the GenAI service | `false` |
| `genAI.openaiApiKey` | OpenAI API key | `""` |
| `genAI.openaiModel` | OpenAI model | `""` (compass-web default) |
| `genAI.querySystemPrompt` | Custom query system prompt | `""` |
| `genAI.aggregationSystemPrompt` | Custom aggregation system prompt | `""` |
| `auth.oidc.enabled` | Enable native OIDC/OAuth | `false` |
| `auth.oidc.issuer` | OIDC issuer URL | `""` |
| `auth.oidc.clientId` | OIDC client ID | `""` |
| `auth.oidc.clientSecret` | OIDC client secret (omit for public clients) | `""` |
| `auth.oidc.redirectUri` | OIDC callback URL | auto from httpRoute/ingress |
| `auth.oidc.scope` | OIDC scopes | `""` (`openid profile email`) |
| `auth.oidc.postLogoutRedirectUri` | Redirect after logout | `""` |
| `auth.oidc.allowedGroups` | Comma-separated allowed groups/roles | `""` |
| `auth.oidc.groupsClaim` | ID token claim with groups | `""` (`groups`) |
| `auth.basic.enabled` | Enable native Basic auth | `false` |
| `auth.basic.username` | Basic auth username | `""` |
| `auth.basic.password` | Basic auth password | `""` |
| `auth.sessionSecret` | Session cookie secret (>=32 chars, required for OIDC) | `""` |
| `secret.create` | Create chart-managed Secret for sensitive values | `true` |
| `secret.existingSecret` | Use an existing Secret instead | `""` |
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

Native auth (recommended, compass-web 0.5.0+) — auth happens inside the app:

```text
User -> Envoy Gateway -> HTTPRoute -> Service:8080 -> Mongo Compass (OIDC/Basic auth)
                                                              |
                                                              v
                                                         Keycloak OIDC
```

Legacy OAuth2 Proxy sidecar:

```text
User -> Envoy Gateway -> HTTPRoute -> Service:4180 -> OAuth2 Proxy -> localhost:8080 -> Mongo Compass
                                              |
                                              v
                                         Keycloak OIDC
```

With Ingress instead of HTTPRoute, replace `HTTPRoute` with `Ingress` in the diagrams above.

## License

Apache 2.0
