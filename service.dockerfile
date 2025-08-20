ARG node_version=22.16.0

# Étape 1 : dépendances PostgreSQL
FROM node:${node_version}-slim AS pgdg
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gpg \
    && rm -rf /var/lib/apt/lists/* \
    && update-ca-certificates
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ $(grep -oP 'VERSION_CODENAME=\K\w+' /etc/os-release)-pgdg main" \
      | tee /etc/apt/sources.list.d/pgdg.list \
    && curl https://www.postgresql.org/media/keys/ACCC4CF8.asc \
      | gpg --dearmor > /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg


# Étape 2 : métadonnées git
FROM node:${node_version}-slim AS intermediate
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
    && rm -rf /var/lib/apt/lists/*
COPY . .
RUN mkdir /tmp/sentry-versions
RUN git describe --tags --dirty > /tmp/sentry-versions/central
WORKDIR /server
RUN git describe --tags --dirty > /tmp/sentry-versions/server
WORKDIR /client
RUN git describe --tags --dirty > /tmp/sentry-versions/client


# Étape 3 : build frontend (client-builder)
FROM node:${node_version}-slim AS client-builder
WORKDIR /client

# Installer certificats et utilitaires réseau
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
    && rm -rf /var/lib/apt/lists/* \
    && update-ca-certificates

# Copier package.json
COPY client/package*.json ./

# Installer dépendances (⚠️ inclut devDeps pour vite)
RUN rm -rf node_modules package-lock.json \
 && npm config set registry https://registry.npmjs.org/ \
 && npm config set strict-ssl false \
 && npm config set fetch-retries 5 \
 && npm config set fetch-retry-factor 2 \
 && npm config set fetch-retry-mintimeout 20000 \
 && npm config set fetch-retry-maxtimeout 120000 \
 && npm install --legacy-peer-deps --no-audit --fund=false --update-notifier=false

# Copier le reste du code
COPY client/ ./

# Build frontend
RUN npm run build


# Étape 4 : image finale = service + frontend dist
FROM node:${node_version}-slim

ARG node_version
LABEL org.opencontainers.image.source="https://github.com/getodk/central"

WORKDIR /usr/odk

COPY server/package*.json ./
COPY --from=pgdg /etc/apt/sources.list.d/pgdg.list \
    /etc/apt/sources.list.d/pgdg.list
COPY --from=pgdg /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg \
    /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        gpg \
        cron \
        wait-for-it \
        procps \
        postgresql-client-14 \
        netcat-traditional \
    && rm -rf /var/lib/apt/lists/* \
    && npm clean-install --omit=dev --no-audit \
        --fund=false --update-notifier=false

COPY server/ ./
COPY files/shared/envsub.awk /scripts/
COPY files/service/scripts/ ./
COPY files/service/config.json.template /usr/share/odk/
COPY files/service/crontab /etc/cron.d/odk
COPY files/service/odk-cmd /usr/bin/

COPY --from=intermediate /tmp/sentry-versions/ ./sentry-versions

# ✅ frontend compilé ajouté
COPY --from=client-builder /client/dist ./client/dist

EXPOSE 8383
