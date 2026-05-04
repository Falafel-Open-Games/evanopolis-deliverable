FROM debian:bookworm-slim AS graphical-client-export

ARG GODOT_VERSION=4.6.2
ARG GODOT_STATUS=stable
ARG GODOT_RELEASE=${GODOT_VERSION}-${GODOT_STATUS}
ARG GODOT_TEMPLATE_DIR=${GODOT_VERSION}.${GODOT_STATUS}
ARG GODOT_DOWNLOAD_URL=https://github.com/godotengine/godot/releases/download/${GODOT_RELEASE}/Godot_v${GODOT_RELEASE}_linux.x86_64.zip
ARG GODOT_EXPORT_TEMPLATES_URL=https://github.com/godotengine/godot/releases/download/${GODOT_RELEASE}/Godot_v${GODOT_RELEASE}_export_templates.tpz

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        libasound2 \
        libfontconfig1 \
        libfreetype6 \
        libglu1-mesa \
        libpulse0 \
        libx11-6 \
        libxcursor1 \
        libxext6 \
        libxi6 \
        libxinerama1 \
        libxkbcommon0 \
        libxrandr2 \
        unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/godot
RUN curl -fL "${GODOT_DOWNLOAD_URL}" -o godot.zip \
    && unzip godot.zip \
    && rm godot.zip \
    && mv "Godot_v${GODOT_RELEASE}_linux.x86_64" /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && curl -fL "${GODOT_EXPORT_TEMPLATES_URL}" -o export_templates.tpz \
    && mkdir -p "/root/.local/share/godot/export_templates/${GODOT_TEMPLATE_DIR}" \
    && unzip export_templates.tpz \
    && mv templates/* "/root/.local/share/godot/export_templates/${GODOT_TEMPLATE_DIR}/" \
    && rm -rf export_templates.tpz templates

WORKDIR /repo
COPY apps/graphical-client/godot /repo/apps/graphical-client/godot

RUN mkdir -p /repo/apps/web-wrapper/public/graphical-client \
    && godot --headless --path /repo/apps/graphical-client/godot --import \
    && godot --headless --path /repo/apps/graphical-client/godot --export-release Web /repo/apps/web-wrapper/public/graphical-client/index.html


FROM node:22-bookworm-slim AS build

WORKDIR /app

COPY apps/web-wrapper/package.json /app/package.json
COPY apps/web-wrapper/package-lock.json /app/package-lock.json

RUN npm ci

COPY apps/web-wrapper/index.html /app/index.html
COPY apps/web-wrapper/invite.html /app/invite.html
COPY apps/web-wrapper/launch.html /app/launch.html
COPY apps/web-wrapper/tsconfig.json /app/tsconfig.json
COPY apps/web-wrapper/tsconfig.app.json /app/tsconfig.app.json
COPY apps/web-wrapper/tsconfig.node.json /app/tsconfig.node.json
COPY apps/web-wrapper/vite.config.ts /app/vite.config.ts
COPY apps/web-wrapper/public /app/public
COPY --from=graphical-client-export /repo/apps/web-wrapper/public/graphical-client /app/public/graphical-client
COPY apps/web-wrapper/src /app/src

RUN npm run build

FROM nginx:1.27-alpine

RUN rm -f /etc/nginx/conf.d/default.conf

COPY deploy/docker/web-wrapper/nginx.conf /etc/nginx/conf.d/default.conf
COPY deploy/docker/web-wrapper/entrypoint.sh /docker-entrypoint.d/40-runtime-config.sh
COPY --from=build /app/dist /usr/share/nginx/html

RUN chmod +x /docker-entrypoint.d/40-runtime-config.sh

ENV APP_PORT=8080

EXPOSE 8080/tcp
