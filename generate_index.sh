#!/usr/bin/env sh
set -eu

CONF_DIR="${CONF_DIR:-/etc/nginx/conf.d}"
HTML_DIR="${HTML_DIR:-/usr/share/nginx/html}"
HTML_FILE="$HTML_DIR/index.html"
INDEX_HOSTNAME="${INDEX_HOSTNAME:-nginx.local}"

mkdir -p "$HTML_DIR"

TMP_HOSTS="$(mktemp)"
trap 'rm -f "$TMP_HOSTS"' EXIT

if ls "$CONF_DIR"/*.conf >/dev/null 2>&1; then
    awk -v idx="$INDEX_HOSTNAME" '
    /^[[:space:]]*server_name[[:space:]]+[^;]+;/ {
        line = $0
        sub(/^[[:space:]]*server_name[[:space:]]+/, "", line)
        sub(/;[[:space:]]*$/, "", line)

        n = split(line, items, /[[:space:]]+/)
        for (i = 1; i <= n; i++) {
            host = items[i]
            sub(/;+$/, "", host)

            if (host == "" || host == "_" || host == "localhost" || host == idx) {
                continue
            }
            if (index(host, "*") > 0 || substr(host, 1, 1) == "~") {
                continue
            }

            print host
        }
    }
    ' "$CONF_DIR"/*.conf 2>/dev/null | sort -u > "$TMP_HOSTS" || true
fi

{
cat <<EOF
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Índice de servicios</title>
</head>
<body>
    <h1>Servicios disponibles</h1>
    <ul>
EOF

if [ ! -s "$TMP_HOSTS" ]; then
    echo "        <li>No hay rutas configuradas todavía.</li>"
else
    while IFS= read -r host; do
        echo "        <li><a href=\"http://$host\">$host</a></li>"
    done < "$TMP_HOSTS"
fi

cat <<EOF
    </ul>
</body>
</html>
EOF
} > "$HTML_FILE"

echo "[INFO] Índice generado en $HTML_FILE"
