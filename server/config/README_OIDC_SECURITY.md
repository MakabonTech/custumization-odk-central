OIDC Example Configs
====================

Les fichiers `oidc-example-*.json` sont des exemples et NE DOIVENT PAS contenir de vrais identifiants ou secrets OAuth.

Utilise les variables d'environnement suivantes pour injecter les valeurs réelles dans le conteneur/service sans les committer :

  - OIDC_ENABLED=true|false
  - OIDC_ISSUER_URL
  - OIDC_CLIENT_ID
  - OIDC_CLIENT_SECRET

Les placeholders présents dans les exemples (ex: GOOGLE_OAUTH_CLIENT_ID_PLACEHOLDER) sont intentionnels et évitent le blocage "push protection" GitHub.

Si tu as déjà committé un secret par erreur :
 1. Le révoquer dans le fournisseur (Google/Auth0).
 2. Réécrire l'historique ou laisser GitHub le marquer comme révoqué si acceptable.
 3. Forcer un nouveau push après nettoyage (git commit --amend ou git rebase -i, puis git push --force-with-lease).
