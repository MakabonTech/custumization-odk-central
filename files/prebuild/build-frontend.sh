#!/bin/bash -eu
set -o pipefail
shopt -s inherit_errexit

cd client

if [[ ${SKIP_FRONTEND_BUILD-} != "" ]]; then
  echo "[build-frontend] Skipping frontend build."

  # Create minimal fake frontend to allow tests to pass:
  mkdir dist dist/assets dist/fonts
  echo > dist/blank.html
  echo > dist/favicon.ico
  echo > dist/index.html '<div id="app"></div>'

  echo > dist/assets/actor-link-CHKNLRJ6.js
  echo > dist/assets/branch-data-NQSuaxke.js
  echo > dist/assets/breadcrumbs-P9Q8Sr8V.js
  echo > dist/assets/chunky-array-CWqL2QBf.js
  echo > dist/assets/style-BAOwY-Kl.css
  echo > dist/assets/who-va@2x-KiG_UkDd.jpg
  echo > dist/assets/socio-economic@2x-DT8M7CaZ.jpg
  echo > dist/fonts/icomoon.ttf

  exit
else
  if [ -f package-lock.json ] || [ -f npm-shrinkwrap.json ]; then
    echo "[build-frontend] lockfile présent -> npm ci"
    npm ci --no-audit --fund=false --update-notifier=false
  else
    echo "[build-frontend] lockfile absent -> npm install"
    npm install --no-audit --fund=false --update-notifier=false
  fi
  if npm run | grep -q '^ *build'; then
    npm run build
  else
    echo "[build-frontend] script build absent -> création dist minimale"
    mkdir -p dist && echo '<div id="app"></div>' > dist/index.html
  fi
fi
