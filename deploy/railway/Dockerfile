# Railway production image: one service, one public listener, one persistent /data volume.
#
# The browser build intentionally loads exercise media from the upstream dataset CDN. This keeps
# the third-party media out of this image and removes the Compose-only shared media volume/job.
# See NOTICE.md before reusing that media.
FROM node:22-alpine AS frontend-build

WORKDIR /build/frontend
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci
COPY frontend/ ./

ARG VITE_IMG_BASE="https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@7455efae41b330c265e7cd4b78dfa848e7ce5ebd/images/"
ARG VITE_GIF_BASE="https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@7455efae41b330c265e7cd4b78dfa848e7ce5ebd/videos/"
ARG VITE_SOURCE_URL="https://github.com/isaacSoto10/OpenGym"
ENV VITE_IMG_BASE=${VITE_IMG_BASE}
ENV VITE_GIF_BASE=${VITE_GIF_BASE}
ENV VITE_SOURCE_URL=${VITE_SOURCE_URL}
# Railway serves the PWA from the domain root. Root-absolute assets keep nested SPA routes
# reloadable while the default/mobile build retains vite.config.js's relative base.
RUN npm run build -- --base=/

FROM node:22-alpine AS api-dependencies

WORKDIR /build/api
COPY api/package.json api/package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

FROM node:22-alpine

ARG VERSION=dev
ARG VCS_REF=dev
ARG BUILD_DATE=unknown

LABEL maintainer="Isaac Soto https://github.com/isaacSoto10" \
    org.opencontainers.image.authors="Duarte Santos; Isaac Soto" \
    org.opencontainers.image.title="openGym Railway" \
    org.opencontainers.image.description="Single-container Railway deployment for openGym's self-hosted PWA and API" \
    org.opencontainers.image.source="https://github.com/isaacSoto10/OpenGym" \
    org.opencontainers.image.url="https://github.com/isaacSoto10/OpenGym" \
    org.opencontainers.image.documentation="https://github.com/isaacSoto10/OpenGym/blob/main/docs/RAILWAY.md" \
    org.opencontainers.image.licenses="AGPL-3.0-or-later" \
    org.opencontainers.image.version=${VERSION} \
    org.opencontainers.image.revision=${VCS_REF} \
    org.opencontainers.image.created=${BUILD_DATE}

RUN apk add --no-cache gettext nginx tini

WORKDIR /app
COPY --from=frontend-build /build/frontend/dist /usr/share/nginx/html
COPY --from=api-dependencies /build/api/node_modules /app/api/node_modules
COPY api/package.json api/package-lock.json api/server.js /app/api/
COPY deploy/railway/nginx.conf.template deploy/railway/entrypoint.sh /app/railway/
COPY LICENSE NOTICE.md /usr/share/licenses/opengym/

RUN chmod 0755 /app/railway/entrypoint.sh \
    && mkdir -p /data /run/nginx

ENV NODE_ENV=production
ENV DATA_DIR=/data
ENV API_PORT=3000
ENV PORT=8080

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --spider -q "http://127.0.0.1:${PORT}/api/health" || exit 1

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/app/railway/entrypoint.sh"]
