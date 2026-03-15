# syntax=docker/dockerfile:1.7

FROM node:22-alpine AS build

ARG PHANPY_VERSION

WORKDIR /src

RUN test -n "${PHANPY_VERSION}"

RUN apk add --no-cache curl

RUN curl -fsSL "https://github.com/cheeaun/phanpy/archive/refs/tags/${PHANPY_VERSION}.tar.gz" \
	| tar -xz --strip-components=1

RUN --mount=type=secret,id=phanpy_env,target=/tmp/phanpy.env \
	set -eu; \
	if [ -s /tmp/phanpy.env ]; then \
		set -a; \
		. /tmp/phanpy.env; \
		set +a; \
	fi; \
	npm ci; \
	npm run build

FROM nginx:stable-alpine

COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/dist /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 CMD wget -q -O /dev/null http://127.0.0.1/ || exit 1
