FROM debian:bookworm-slim AS godot

ARG GODOT_VERSION=4.6.1
ARG GODOT_STATUS=stable
ARG GODOT_DOWNLOAD_URL=https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_STATUS}/Godot_v${GODOT_VERSION}-${GODOT_STATUS}_linux.x86_64.zip

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/godot
RUN curl -fL "${GODOT_DOWNLOAD_URL}" -o godot.zip \
    && unzip godot.zip \
    && rm godot.zip \
    && mv "Godot_v${GODOT_VERSION}-${GODOT_STATUS}_linux.x86_64" /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot


FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
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
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --home-dir /home/godot --shell /usr/sbin/nologin godot

COPY --from=godot /usr/local/bin/godot /usr/local/bin/godot

WORKDIR /app
COPY apps/game-server/ /app/
COPY deploy/docker/game-server/entrypoint.sh /usr/local/bin/game-server-entrypoint

RUN chmod +x /usr/local/bin/game-server-entrypoint \
    && mkdir -p /home/godot/.local/share/godot/app_userdata \
    && chown -R godot:godot /app /home/godot

USER godot

RUN godot --headless --path /app --import

ENV GAME_SERVER_PORT=9010

EXPOSE 9010/tcp

ENTRYPOINT ["/usr/local/bin/game-server-entrypoint"]
