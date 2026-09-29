#!/bin/sh
set -eu

version="${1:-}"
cd "$(dirname "$0")/.."

if ! printf %s "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "Uso: pnpm release X.Y.Z" >&2
    exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
    echo "Hay cambios sin commit" >&2
    exit 1
fi
if git rev-parse -q --verify "refs/tags/v$version" >/dev/null; then
    echo "El tag v$version ya existe" >&2
    exit 1
fi
if ! grep -q "^## \[$version\]" CHANGELOG.md; then
    echo "Falta la sección ## [$version] en CHANGELOG.md" >&2
    exit 1
fi

node -e '
const fs = require("fs");
for (const file of ["plugin.json", "package.json"]) {
    const data = JSON.parse(fs.readFileSync(file, "utf8"));
    data.version = process.argv[1];
    fs.writeFileSync(file, JSON.stringify(data, null, 2) + "\n");
}
' "$version"

git add plugin.json package.json
git commit -q -m "chore(release): v$version"
git tag -a "v$version" -m "v$version"
echo "Listo: v$version. Publica con: git push --follow-tags"
