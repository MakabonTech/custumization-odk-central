# Utilise l'image officielle ODK Central Nginx comme base
FROM ghcr.io/getodk/central-nginx:latest

# Supprimer l'ancien client officiel
RUN rm -rf /usr/share/nginx/html/*

# (frontend désactivé temporairement: pas de client/dist à copier)
# COPY client/dist/ /usr/share/nginx/html/

# Droits pour Nginx
RUN chown -R nginx:nginx /usr/share/nginx/html

# Vérification du contenu
# RUN ls -la /usr/share/nginx/html/
