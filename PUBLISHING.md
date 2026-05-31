# Publishing mongo-compass Helm Chart

Instructions for maintainers to publish this chart on **GitHub Pages** and **Artifact Hub**.

## Repository layout

```text
mongo-compass-web-secure-helm/
├── chart/mongo-compass/     # chart source
├── artifacthub-repo.yaml    # Artifact Hub metadata
├── .github/workflows/       # optional CI
├── index.yaml               # generated
└── mongo-compass-*.tgz      # generated
```

---

## 1. Create the GitHub repository

1. Create a new repo on GitHub, e.g. `mongo-compass-web-helm`
2. Push the chart source:

```bash
cd /path/to/mongo-compass-secure

git init
git add chart/ artifacthub-repo.yaml PUBLISHING.md
git commit -m "Add mongo-compass Helm chart"
git branch -M main
git remote add origin https://github.com/YOUR_USER/mongo-compass-web-secure-helm.git
git push -u origin main
```

---

## 2. Package the chart

Bump `version` in `chart/mongo-compass/Chart.yaml` before each release.

```bash
helm lint ./chart/mongo-compass
helm package ./chart/mongo-compass --destination .
```

This produces `mongo-compass-X.Y.Z.tgz`.

---

## 3. Publish to GitHub Pages (Helm repository)

### Build the index

```bash
helm repo index . --url https://YOUR_USER.github.io/mongo-compass-web-secure-helm
```

Replace `YOUR_USER` and repo name with your actual GitHub Pages URL.

For subsequent releases, merge with the existing index to keep old versions:

```bash
helm repo index . --url https://YOUR_USER.github.io/mongo-compass-web-secure-helm --merge index.yaml
```

### Publish via gh-pages branch

```bash
git checkout --orphan gh-pages
git rm -rf chart .github PUBLISHING.md
git add index.yaml mongo-compass-*.tgz artifacthub-repo.yaml
git commit -m "Publish Helm chart"
git push origin gh-pages
```

### Enable GitHub Pages

1. Go to **Settings → Pages**
2. Source: **Deploy from a branch**
3. Branch: **gh-pages** / **/ (root)**
4. Save

Your Helm repo URL:

```text
https://YOUR_USER.github.io/mongo-compass-web-helm
```

### Verify

```bash
curl https://YOUR_USER.github.io/mongo-compass-web-secure-helm/index.yaml

helm repo add mongo-compass-web-secure https://YOUR_USER.github.io/mongo-compass-web-secure-helm
helm repo update
helm search repo mongo-compass-web
```

---

## 4. Automate releases (optional)

Create `.github/workflows/release.yml` on `main`:

```yaml
name: Release Helm chart

on:
  push:
    tags:
      - "v*"

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: azure/setup-helm@v4

      - name: Package chart
        run: helm package ./chart/mongo-compass --destination /tmp/release

      - name: Download existing index
        run: |
          curl -fLO https://${{ github.repository_owner }}.github.io/${{ github.event.repository.name }}/index.yaml || true

      - name: Update index
        run: |
          cd /tmp/release
          if [ -f "$GITHUB_WORKSPACE/index.yaml" ]; then
            helm repo index . \
              --url https://${{ github.repository_owner }}.github.io/${{ github.event.repository.name }} \
              --merge "$GITHUB_WORKSPACE/index.yaml"
          else
            helm repo index . \
              --url https://${{ github.repository_owner }}.github.io/${{ github.event.repository.name }}
          fi
          cp index.yaml "$GITHUB_WORKSPACE/"

      - name: Publish to gh-pages
        uses: peaceiris/actions-gh-pages@v4
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: /tmp/release
          keep_files: true
          include: |
            index.yaml
            *.tgz
            artifacthub-repo.yaml
```

Release a new version:

```bash
# bump version in chart/mongo-compass/Chart.yaml first
git add chart/mongo-compass/Chart.yaml
git commit -m "Release chart v1.0.0"
git tag v1.0.0
git push origin main --tags
```

---

## 5. Publish on Artifact Hub

### Prerequisites

- GitHub Pages Helm repo is live and publicly accessible
- `artifacthub-repo.yaml` is published alongside `index.yaml` on gh-pages

### Register the repository

1. Sign in at [artifacthub.io](https://artifacthub.io/)
2. **Control Panel → Repositories → Add**
3. Type: **Helm charts**
4. Name: `mongo-compass-web-secure-helm` (or your choice)
5. URL: `https://YOUR_USER.github.io/mongo-compass-web-secure-helm`
6. Submit

### Update artifacthub-repo.yaml

After registration, Artifact Hub assigns a `repositoryID`. Update `artifacthub-repo.yaml`:

```yaml
repositoryID: <your-assigned-uuid>
owners:
  - name: Your Name
    email: you@example.com
```

Republish to gh-pages:

```bash
git checkout gh-pages
# edit artifacthub-repo.yaml, then:
git add artifacthub-repo.yaml
git commit -m "Update Artifact Hub repository ID"
git push origin gh-pages
```

Artifact Hub re-indexes automatically (usually within a few minutes).

### Verify on Artifact Hub

Search for `mongo-compass` at [artifacthub.io](https://artifacthub.io/) and confirm:

- Chart version matches `Chart.yaml`
- README renders correctly
- Install command works

---

## Release checklist

- [ ] Bump `version` in `chart/mongo-compass/Chart.yaml`
- [ ] Update `artifacthub.io/changes` in `Chart.yaml`
- [ ] Run `helm lint ./chart/mongo-compass`
- [ ] Run `helm package ./chart/mongo-compass --destination .`
- [ ] Run `helm repo index` with correct `--url`
- [ ] Push `index.yaml`, `.tgz`, and `artifacthub-repo.yaml` to gh-pages
- [ ] Verify `helm repo add` works
- [ ] Confirm chart appears on Artifact Hub

---

## Common issues

| Problem | Fix |
|---------|-----|
| `helm repo add` fails | Check Pages URL uses `https://USER.github.io/REPO`, not the git clone URL |
| 404 on index.yaml | GitHub Pages not enabled or gh-pages branch missing files |
| Old versions missing | Use `--merge index.yaml` when rebuilding the index |
| Artifact Hub not updating | Confirm `artifacthub-repo.yaml` is on gh-pages; wait 5–15 min |
