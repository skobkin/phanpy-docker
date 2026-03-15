#!/bin/sh

set -eu

: "${1:?target registry name is required}"

target="$1"

. .woodpecker/release.env

if [ "${SHOULD_BUILD}" != "1" ]; then
	echo "Skipping Docker build because ${PHANPY_VERSION} is already published."
	exit 0
fi

: "${PHANPY_BUILD_ENV:?PHANPY_BUILD_ENV is required}"

tmp_secret_file="$(mktemp)"
trap 'rm -f "${tmp_secret_file}"' EXIT INT TERM
printf '%s\n' "${PHANPY_BUILD_ENV}" > "${tmp_secret_file}"

export PLUGIN_DOCKERFILE="Dockerfile"
export PLUGIN_TAGS_FILE=".woodpecker/tags.txt"
export PLUGIN_ENV_FILE=".woodpecker/release.env"
export PLUGIN_BUILD_ARGS_FROM_ENV="PHANPY_VERSION"
export PLUGIN_SECRETS="id=phanpy_env,src=${tmp_secret_file}"
export PLUGIN_PLATFORMS="linux/amd64,linux/arm64"

case "${target}" in
	dockerhub)
		: "${DOCKERHUB_IMAGE_REPO:?DOCKERHUB_IMAGE_REPO is required}"
		: "${DOCKERHUB_LOGIN:?DOCKERHUB_LOGIN is required}"
		: "${DOCKERHUB_TOKEN:?DOCKERHUB_TOKEN is required}"

		export PLUGIN_REPO="${DOCKERHUB_IMAGE_REPO}"
		export PLUGIN_REGISTRY="https://index.docker.io/v1/"
		export PLUGIN_USERNAME="${DOCKERHUB_LOGIN}"
		export PLUGIN_PASSWORD="${DOCKERHUB_TOKEN}"
		export PLUGIN_CACHE_IMAGES="${DOCKERHUB_IMAGE_REPO}:buildcache"
		;;
	ghcr)
		: "${GHCR_IMAGE_REPO:?GHCR_IMAGE_REPO is required}"
		: "${GHCR_LOGIN:?GHCR_LOGIN is required}"
		: "${GHCR_TOKEN:?GHCR_TOKEN is required}"

		export PLUGIN_REPO="${GHCR_IMAGE_REPO}"
		export PLUGIN_REGISTRY="https://ghcr.io"
		export PLUGIN_USERNAME="${GHCR_LOGIN}"
		export PLUGIN_PASSWORD="${GHCR_TOKEN}"
		export PLUGIN_CACHE_IMAGES="${GHCR_IMAGE_REPO}:buildcache"
		;;
	*)
		echo "Unknown build target: ${target}" >&2
		exit 1
		;;
esac

for candidate in plugin-docker-buildx /bin/plugin-docker-buildx /usr/local/bin/plugin-docker-buildx; do
	if command -v "${candidate}" >/dev/null 2>&1; then
		exec "${candidate}"
	fi
	if [ -x "${candidate}" ]; then
		exec "${candidate}"
	fi
done

echo "Could not find the plugin-docker-buildx executable in the buildx plugin image." >&2
exit 1
