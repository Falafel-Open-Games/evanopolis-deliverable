FROM node:22-bookworm-slim

WORKDIR /app

COPY apps/rooms-api/package.json /app/package.json
COPY apps/rooms-api/package-lock.json /app/package-lock.json

RUN npm ci

COPY apps/rooms-api/tsconfig.json /app/tsconfig.json
COPY apps/rooms-api/src /app/src

RUN npm run build

ENV PORT=3001

EXPOSE 3001/tcp

CMD ["npm", "start"]
