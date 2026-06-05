<p align="center">
  <img src="mongo-compass-web-helm-tsp.png" alt="Mongo Compass Web Helm" width="160">
</p>

<h1 align="center">Mongo Compass Web Helm Chart</h1>

<p align="center">

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/mongo-compass-web-helm)](https://artifacthub.io/packages/search?repo=mongo-compass-web-helm)
[![Release](https://img.shields.io/github/v/release/youknowforsearch/mongo-compass-web-helm)](https://github.com/youknowforsearch/mongo-compass-web-helm/releases)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](#license)

</p>

A Helm chart to deploy [MongoDB Compass Web](https://github.com/haohanyang/compass-web) on Kubernetes.

As of chart `1.1.0` / compass-web `0.5.0`, the app supports **native OIDC/OAuth and Basic authentication** built in — no sidecar required. The legacy [OAuth2 Proxy](https://oauth2-proxy.github.io/oauth2-proxy/) sidecar for [Keycloak](https://www.keycloak.org/) is still available, and [Gateway API](https://gateway.envoyproxy.io/) `HTTPRoute` is supported for API Gateway integration.

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

## Quick start

```bash
helm repo add mongo-compass-web-secure https://youknowforsearch.github.io/mongo-compass-web-helm
helm repo update

helm install mongo-compass mongo-compass-web-secure/mongo-compass \
  --set defaultMongodbUri="mongodb://user:password@host:27017/db"
```

### Install with native OIDC/OAuth (recommended)

```bash
helm install mongo-compass mongo-compass-web-secure/mongo-compass \
  --set httpRoute.enabled=true \
  --set httpRoute.hostnames[0]=compass.example.com \
  --set auth.oidc.enabled=true \
  --set auth.oidc.issuer=https://keycloak.example.com/realms/myrealm \
  --set auth.oidc.clientId=compass-web \
  --set auth.oidc.clientSecret=YOUR_CLIENT_SECRET \
  --set auth.sessionSecret=$(openssl rand -base64 32) \
  --set defaultMongodbUri="mongodb://user:password@host:27017/db"
```

The OIDC callback (`CW_OIDC_REDIRECT_URI`) is derived automatically as
`https://<hostname><baseRoute>/auth/callback`. Native OIDC (`auth.oidc.enabled`)
and the legacy `oauth2Proxy.enabled` sidecar are mutually exclusive.

## Documentation

Full configuration, authentication options, and examples are in the chart README:

- [chart/mongo-compass/README.md](chart/mongo-compass/README.md)

## Repository layout

```text
chart/mongo-compass/   # the Helm chart
artifacthub-repo.yaml  # Artifact Hub repository metadata
```

The packaged chart and `index.yaml` are published to the `gh-pages` branch and
served via GitHub Pages at
`https://youknowforsearch.github.io/mongo-compass-web-helm`.

## Versions

| Chart | App (compass-web) |
| ----- | ----------------- |
| 1.1.0 | 0.5.0 |
| 1.0.0 | 0.4.2 |

## Contributing

Issues and pull requests are welcome. When changing the chart, bump
`version`/`appVersion` in [`chart/mongo-compass/Chart.yaml`](chart/mongo-compass/Chart.yaml)
and run `helm lint chart/mongo-compass` before submitting.

## Credits

- [MongoDB Compass Web](https://github.com/haohanyang/compass-web)
- [OAuth2 Proxy](https://oauth2-proxy.github.io/oauth2-proxy/)
- [Keycloak](https://www.keycloak.org/)
- [Envoy Gateway](https://gateway.envoyproxy.io/)

## License

Licensed under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).
