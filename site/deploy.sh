#!/bin/zsh
# Uploads site/ to the web host with rsync over SSH.
# Reads tools/.secrets/site.env (gitignored):  SITE_SSH=user@host  SITE_PORT=22  SITE_ROOT=/path/to/docroot
# The host's CDN caches static files for a week, so the stylesheet is published under a content-hashed
# name (style.<hash>.css) and the HTML is rewritten to point at it in a staging copy. Source files stay clean.
set -euo pipefail
cd "$(dirname "$0")"
source ../tools/.secrets/site.env
HASH=$(md5 -q style.css | cut -c1-10)
STAGE=$(mktemp -d)
rsync -a --exclude deploy.sh --exclude '*.md' --exclude '.DS_Store' ./ "$STAGE/"
mv "$STAGE/style.css" "$STAGE/style.$HASH.css"
find "$STAGE" -name '*.html' -exec sed -i '' "s#/style\.css#/style.$HASH.css#g" {} +
rsync -avz --delete -e "ssh -p ${SITE_PORT:-22}" "$STAGE/" "${SITE_SSH}:${SITE_ROOT%/}/"
rm -rf "$STAGE"
echo "Deployed to https://gtp-art.aijam.pro/ (stylesheet style.$HASH.css)"
