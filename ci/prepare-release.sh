#!/bin/sh

set -eu

: "${DOCKERHUB_IMAGE_REPO:?DOCKERHUB_IMAGE_REPO is required}"
: "${GHCR_IMAGE_REPO:?GHCR_IMAGE_REPO is required}"

UPSTREAM_REPO="${UPSTREAM_REPO:-cheeaun/phanpy}"
RELEASE_ENV_FILE="${RELEASE_ENV_FILE:-.woodpecker/release.env}"
TAGS_FILE="${TAGS_FILE:-.woodpecker/tags.txt}"

fetch_latest_release() {
	curl -fsSL \
		-H "Accept: application/vnd.github+json" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		"https://api.github.com/repos/${UPSTREAM_REPO}/releases/latest"
}

dockerhub_token() {
	curl -fsSL \
		"https://auth.docker.io/token?service=registry.docker.io&scope=repository:${1}:pull" \
		| jq -r '.token'
}

ghcr_token() {
	if [ -n "${GHCR_LOGIN:-}" ] && [ -n "${GHCR_TOKEN:-}" ]; then
		curl -fsSL \
			-u "${GHCR_LOGIN}:${GHCR_TOKEN}" \
			"https://ghcr.io/token?service=ghcr.io&scope=repository:${1}:pull" \
			| jq -r '.token'
		return
	fi

	curl -fsSL \
		"https://ghcr.io/token?service=ghcr.io&scope=repository:${1}:pull" \
		| jq -r '.token'
}

registry_manifest_status() {
	registry_url="$1"
	repo="$2"
	tag="$3"
	token="$4"

	curl -sS -o /dev/null -w '%{http_code}' \
		-H "Authorization: Bearer ${token}" \
		-H "Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.docker.distribution.manifest.v2+json" \
		"${registry_url}/v2/${repo}/manifests/${tag}"
}

tag_exists_in_dockerhub() {
	status="$(registry_manifest_status "https://registry-1.docker.io" "$1" "$2" "$(dockerhub_token "$1")")"
	[ "${status}" = "200" ]
}

tag_exists_in_ghcr() {
	status="$(registry_manifest_status "https://ghcr.io" "$1" "$2" "$(ghcr_token "$1")")"
	[ "${status}" = "200" ]
}

release_json="$(fetch_latest_release)"
phanpy_version="$(printf '%s' "${release_json}" | jq -r '.tag_name')"

if [ -z "${phanpy_version}" ] || [ "${phanpy_version}" = "null" ]; then
	echo "Unable to determine the latest Phanpy release version." >&2
	exit 1
fi

should_build=1

if tag_exists_in_dockerhub "${DOCKERHUB_IMAGE_REPO}" "${phanpy_version}" && tag_exists_in_ghcr "${GHCR_IMAGE_REPO}" "${phanpy_version}"; then
	should_build=0
fi

mkdir -p "$(dirname "${RELEASE_ENV_FILE}")"

cat > "${RELEASE_ENV_FILE}" <<EOF
PHANPY_VERSION=${phanpy_version}
SHOULD_BUILD=${should_build}
EOF

cat > "${TAGS_FILE}" <<EOF
${phanpy_version}
latest
EOF

echo "Resolved Phanpy release: ${phanpy_version}"
if [ "${should_build}" = "1" ]; then
	echo "At least one target registry is missing ${phanpy_version}; build will proceed."
else
	echo "Both target registries already have ${phanpy_version}; build will be skipped."
fi
