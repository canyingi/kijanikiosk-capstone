# ---- Stage 1: install production dependencies only ----
FROM node:20.18.0-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# ---- Stage 2: runtime (no npm, no build tools) ----
FROM alpine:3.20
RUN apk add --no-cache nodejs \
 && addgroup -S -g 10001 kijani && adduser -S -u 10001 kijani -G kijani
WORKDIR /app
ARG APP_VERSION=unknown
ENV NODE_ENV=production APP_VERSION=${APP_VERSION}
COPY --from=deps --chown=kijani:kijani /app/node_modules ./node_modules
COPY --chown=kijani:kijani package.json ./
COPY --chown=kijani:kijani src ./src
USER 10001
EXPOSE 3001
CMD ["node", "src/server.js"]
