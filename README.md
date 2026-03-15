# phanpy-docker [![status-badge](https://ci.skobk.in/api/badges/9/status.svg?events=cron%2Cmanual)](https://ci.skobk.in/repos/9)

Builds and publishes a self-hosted Docker image for [Phanpy](https://github.com/cheeaun/phanpy) with Woodpecker CI.

The repository is designed for scheduled and manual Woodpecker runs:

- On every eligible run, CI checks the latest upstream GitHub release from `cheeaun/phanpy`.
- If that release tag is already published to both configured registries, the pipeline exits successfully and does not build a new image.
- If the release is missing from at least one target registry, CI builds the static Phanpy bundle and publishes two tags to each registry: the upstream release version and `latest`.

The produced image is intentionally simple:

- Multi-stage build to keep the final image small.
- `nginx:stable-alpine` runtime image.
- Plain HTTP only on port `80`.
- No TLS or certificate management inside the container.

## Woodpecker setup

Create a cron job in the Woodpecker repository settings with:

- Name: `daily-release-check`
- Schedule: `@daily`

The pipeline also supports manual Woodpecker triggers.

`woodpeckerci/plugin-docker-buildx:6` needs privileged execution. In Woodpecker, make sure this repository is trusted and that the plugin image is allowed in `WOODPECKER_PLUGINS_PRIVILEGED` on the server or agent side.

## Required secrets

Configure these Woodpecker secrets:

- `DOCKERHUB_IMAGE_REPO`
- `GHCR_IMAGE_REPO`
- `DOCKERHUB_LOGIN`
- `DOCKERHUB_TOKEN`
- `GHCR_LOGIN`
- `GHCR_TOKEN`
- `PHANPY_BUILD_ENV`

This repository intentionally uses Woodpecker secrets for all repository-specific inputs, including the image repository names. That keeps `manual` and `cron` runs on the same config path and avoids depending on cron-only environment overrides.

`DOCKERHUB_IMAGE_REPO` is the target repository on Docker Hub, for example `skobkin/phanpy`.

`GHCR_IMAGE_REPO` is the target repository on GHCR, for example `ghcr.io/skobkin/phanpy-docker`.

`PHANPY_BUILD_ENV` should contain the Phanpy build-time environment in `.env` format. CI passes it into the Docker build as a BuildKit secret so the values are not committed to this repository.

Example:

```dotenv
PHANPY_CLIENT_NAME=My Phanpy
PHANPY_WEBSITE=https://phanpy.example.com
PHANPY_DEFAULT_INSTANCE=mastodon.social
PHANPY_DEFAULT_INSTANCE_REGISTRATION_URL=https://mastodon.social/auth/sign_up
PHANPY_PRIVACY_POLICY_URL=https://example.com/privacy
PHANPY_TRANSLANG_INSTANCES=translate.example.com
PHANPY_DISALLOW_ROBOTS=1
```

Only include the variables you actually need. Upstream Phanpy supports build-time customization; see the upstream README for the full list.

## Image behavior

The image serves the already-built static application from Nginx.

- Container port: `80`
- TLS termination: out of scope
- Reverse proxy / ingress: expected to be handled externally

Example:

```sh
docker run --rm -p 8080:80 ghcr.io/example/phanpy-docker:latest
```

Then put your own reverse proxy, ingress, or load balancer in front of it if you need HTTPS.
