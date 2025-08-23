# ==============================
# ARG : version de Node.js
# ==============================
ARG node_version=22.16.0

# NOTE: Les métadonnées git (tags/commit) ne seront disponibles que si le dossier
# .git est inclus dans le contexte de build. Actuellement il est exclu par
# .dockerignore. Pour avoir des versions réelles: retirer .git de .dockerignore
# OU ajouter `COPY .git/ .git/` juste avant les commandes git puis le supprimer.

# ==============================
# Étape 1 : Dépendances PostgreSQL
# ==============================
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


# ==============================
# Étape 2 : Récupération des métadonnées Git (optionnelle)
# ==============================
FROM node:${node_version}-slim AS intermediate

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
    && rm -rf /var/lib/apt/lists/*

# Copier uniquement les fichiers essentiels
COPY package.json ./
COPY server/package.json server/package.json
# (client désactivé temporairement: package.json manquant)

# Si le dossier .git existe → on le copie
ONBUILD COPY .git/ .git/

# Créer dossier versions pour Sentry
RUN mkdir -p /tmp/sentry-versions

# Définir versions ou valeur par défaut si .git absent / pas de tags
RUN if git rev-parse --git-dir > /dev/null 2>&1; then \
            (git describe --tags --dirty 2>/dev/null || git rev-parse --short HEAD || echo v0.0.0) \
                > /tmp/sentry-versions/central; \
        else echo 'no-git' > /tmp/sentry-versions/central; fi
WORKDIR /server
RUN if git rev-parse --git-dir > /dev/null 2>&1; then \
            (git describe --tags --dirty 2>/dev/null || git rev-parse --short HEAD || echo v0.0.0) \
                > /tmp/sentry-versions/server; \
        else echo 'no-git' > /tmp/sentry-versions/server; fi || true
WORKDIR /client
RUN if git rev-parse --git-dir > /dev/null 2>&1; then \
            (git describe --tags --dirty 2>/dev/null || git rev-parse --short HEAD || echo v0.0.0) \
                > /tmp/sentry-versions/client; \
        else echo 'no-git' > /tmp/sentry-versions/client; fi || true


## Étape 3 (frontend) désactivée temporairement : client/package.json absent.
## Pour réactiver: restaurer client/package.json + sources puis réintroduire stage client-builder.


# ==============================
# Étape 4 : Image finale (backend + frontend)
# ==============================
FROM node:${node_version}-slim

ARG node_version
LABEL org.opencontainers.image.source="https://github.com/getodk/central"

WORKDIR /usr/odk

# Copier package.json serveur
COPY server/package*.json ./

# Ajouter les dépôts PostgreSQL
COPY --from=pgdg /etc/apt/sources.list.d/pgdg.list \
    /etc/apt/sources.list.d/pgdg.list
COPY --from=pgdg /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg \
    /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg

# Installer dépendances système
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        gpg \
        cron \
        wait-for-it \
        procps \
        postgresql-client-14 \
        netcat-traditional \
    && rm -rf /var/lib/apt/lists/*

# Installer les dépendances Node.js du backend (tolère absence de lock)
RUN if [ -f package-lock.json ] || [ -f npm-shrinkwrap.json ]; then \
            echo '[build] lockfile présent -> npm ci'; \
            npm ci --omit=dev --no-audit --fund=false --update-notifier=false; \
        else \
            echo '[build] lockfile absent -> npm install'; \
            npm install --omit=dev --no-audit --fund=false --update-notifier=false; \
        fi

# Copier le code serveur
COPY server/ ./

# Placeholder: fournir scripts attendus par start-odk.sh si backend réel absent
RUN mkdir -p lib/bin \
 && if [ ! -f lib/bin/run-migrations ]; then \
            printf '#!/usr/bin/env node\nconsole.log("[placeholder] skip run-migrations (backend absent)");\n' > lib/bin/run-migrations; \
            chmod +x lib/bin/run-migrations; \
        fi \
 && if [ ! -f lib/bin/log-upgrade ]; then \
            printf '#!/usr/bin/env node\nconsole.log("[placeholder] skip log-upgrade (backend absent)");\n' > lib/bin/log-upgrade; \
            chmod +x lib/bin/log-upgrade; \
        fi

# Copier scripts et fichiers nécessaires
COPY files/shared/envsub.awk /scripts/
COPY files/service/scripts/ ./
COPY files/service/config.json.template /usr/share/odk/
COPY files/service/crontab /etc/cron.d/odk
COPY files/service/odk-cmd /usr/bin/

# Copier versions sentry
COPY --from=intermediate /tmp/sentry-versions/ ./sentry-versions

# Frontend désactivé (pas de copie de dist). Ajouter quand client restauré:
# COPY --from=client-builder /client/dist ./client/dist

# Exposer le port principal
EXPOSE 8383

# Lancer le serveur
CMD ["npm", "start"]
