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
