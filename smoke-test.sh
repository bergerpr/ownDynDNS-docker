#!/usr/bin/env bash
#
# Smoke test for the ownDynDNS container.
#
# Builds the image, starts it with throwaway settings and asserts that the
# container comes up, that the PHP settings passed as environment variables
# actually land in php.ini, that .env is rebuilt (not appended to) on restart,
# that only update.php is served (also without the deprecated mod_access_compat),
# that the security hardening holds (no credentials in the access log, code not
# writable by the web server, safe handling of special characters in secrets)
# and that the outbound SOAP/TLS chain works.
#
# It needs no Netcup credentials and never attempts an API login. The one thing
# it therefore cannot cover is the real update path -- login, infoDnsRecords,
# updateDnsRecords and the resulting log.json. Everything up to that boundary is
# checked: "credentials wrong" proves .env was read and the payload validated,
# and the WSDL fetch proves SOAP, TLS and the CA bundle work inside the image.
#
# Usage:  bash smoke-test.sh          (from anywhere; PORT and IMAGE overridable)
# Exit:   0 if every check passed, 1 otherwise.
#
set -u
cd "$(dirname "$0")" || exit 1
IMAGE="${IMAGE:-owndyndns-smoke:test}"
NAME="owndyndns-smoke"
PORT="${PORT:-18090}"
B="http://127.0.0.1:${PORT}"
pass=0; fail=0
chk() { # chk <label> <expected> <actual>
  if [ "$2" = "$3" ]; then printf "  \033[32mOK\033[0m   %-46s %s\n" "$1" "$3"; pass=$((pass+1))
  else printf "  \033[31mFAIL\033[0m %-46s erwartet=%s ist=%s\n" "$1" "$2" "$3"; fail=$((fail+1)); fi
}
code() { curl -s -o /dev/null -w '%{http_code}' --path-as-is "$B$1"; }

TMPD=$(mktemp -d)
cleanup() {
  docker rm -f "$NAME" "$NAME-bind" "$NAME-vol" "$NAME-files" "$NAME-deny" "$NAME-sname" >/dev/null 2>&1
  docker volume rm -f "$NAME-oldvol" >/dev/null 2>&1
  # the containers create root-owned files in the bind mounts
  docker run --rm -v "$TMPD:/x" alpine:3.24 rm -rf /x/bind /x/files >/dev/null 2>&1
  rm -rf "$TMPD"
}
trap cleanup EXIT

echo "== 1. Build =="
docker build -q --pull -t "$IMAGE" . >/dev/null || { echo "Build fehlgeschlagen"; exit 1; }
echo "  OK   Image gebaut"

echo "== 2. Start =="
docker rm -f "$NAME" >/dev/null 2>&1
docker run -d --name "$NAME" -p "${PORT}:80" \
  -e APACHE_SERVER_NAME=smoke.test \
  -e OWNDYNDNS_USERNAME=smokeuser -e OWNDYNDNS_PASSWORD=smokepass \
  -e NETCUP_APIKEY=SMOKE_KEY -e 'NETCUP_APIPASSWORD=a%sb|c&d"e\f$g' -e NETCUP_CUSTOMERID=100000 \
  -e PHP_DATE_TIMEZONE=Europe/Berlin -e PHP_MEMORY_LIMIT=256M -e 'PHP_ERROR_LOG=/tmp/a|b&c' \
  "$IMAGE" >/dev/null || exit 1
for i in $(seq 1 30); do [ "$(code /update.php)" != "000" ] && break; sleep 1; done
chk "Container laeuft" "running" "$(docker inspect -f '{{.State.Status}}' $NAME)"
chk "Apache Konfiguration" "Syntax OK" "$(docker exec $NAME httpd -t 2>&1)"
chk "Upstream-Commit im Startlog" "1" "$(docker logs $NAME 2>&1 | grep -cE '^ownDynDNS upstream commit: [0-9a-f]{40}$')"
chk "keine sed-Fehler im Startlog" "0" "$(docker logs $NAME 2>&1 | grep -c 'sed:')"

echo "== 3. PHP-Umgebung =="
chk "PHP-Version" "8.5" "$(docker exec $NAME php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"
chk "date.timezone (Pfadwert via ENV)" "Europe/Berlin" "$(docker exec $NAME php -r 'echo ini_get("date.timezone");')"
chk "memory_limit via ENV" "256M" "$(docker exec $NAME php -r 'echo ini_get("memory_limit");')"
chk "sed-Escaping: | und & in php.ini" "error_log = /tmp/a|b&c" "$(docker exec $NAME grep '^error_log = ' /etc/php85/php.ini | sort -u)"
chk "expose_php aus" "" "$(docker exec $NAME php -r 'echo ini_get("expose_php");')"
chk "open_basedir gesetzt" "/app:/tmp" "$(docker exec $NAME php -r 'echo ini_get("open_basedir");')"
for e in soap mbstring curl json simplexml openssl; do
  chk "Extension $e" "1" "$(docker exec $NAME php -r "echo (int)extension_loaded('$e');")"
done

echo "== 4. Konfiguration =="
ENVF=/app/owndyndns/.env
chk ".env Zeilenzahl" "8" "$(docker exec $NAME sh -c "wc -l < $ENVF" | tr -d ' ')"
chk ".env ohne CR" "0" "$(docker exec $NAME sh -c "grep -c \$'\r' $ENVF || true" | tr -d ' ')"
chk ".env Eigentuemer" "root:apache" "$(docker exec $NAME stat -c '%U:%G' $ENVF)"
chk ".env Rechte" "640" "$(docker exec $NAME stat -c '%a' $ENVF)"
chk ".env nicht im Document Root" "0" "$(docker exec $NAME sh -c 'ls -A /app/public | grep -vc "^update.php$" || true')"
chk "Sonderzeichen im Secret korrekt gelesen" 'a%sb|c&d"e\f$g' "$(docker exec $NAME php -r 'echo parse_ini_file("/app/owndyndns/.env", false, INI_SCANNER_TYPED)["apiPassword"];')"
chk "Code fuer apache nicht schreibbar" "nein" "$(docker exec -u apache $NAME sh -c 'touch /app/owndyndns/x /app/public/x 2>/dev/null && echo ja || echo nein')"
chk "\${ im Secret -> Start verweigert" "1" "$(docker run --rm -e 'OWNDYNDNS_PASSWORD=a${HOME}' "$IMAGE" 2>&1 | grep -c 'must not contain')"

echo "== 5. Idempotenz ueber Neustarts =="
before=$(docker exec $NAME md5sum /app/owndyndns/.env | cut -d' ' -f1)
for i in 1 2 3; do docker restart $NAME >/dev/null; done
for i in $(seq 1 30); do [ "$(code /update.php)" != "000" ] && break; sleep 1; done
chk ".env nach 3 Neustarts unveraendert" "$before" "$(docker exec $NAME md5sum /app/owndyndns/.env | cut -d' ' -f1)"

echo "== 6. Absicherung =="
for p in /.env "/.env/" "/.env." "/%2Eenv" "/./.env" "/src/../.env" /log.json "/log.json/" /.htaccess / \
         /src/Config.php /owndyndns/.env /data/log.json; do
  chk "gesperrt: $p" "403" "$(code "$p")"
done
for p in /../owndyndns/.env "/%2e%2e/owndyndns/.env"; do
  chk "abgewiesen (Traversal): $p" "400" "$(code "$p")"
done
chk "erreichbar: /update.php" "200" "$(code /update.php)"
chk "TRACE abgeschaltet" "405" "$(curl -s -o /dev/null -w '%{http_code}' -X TRACE "$B/update.php")"
chk "Server-Header ohne Version" "Apache" "$(curl -sI "$B/update.php" | tr -d '\r' | sed -n 's/^Server: //Ip')"
chk "kein X-Powered-By" "0" "$(curl -sI "$B/update.php" | grep -ci '^X-Powered-By' || true)"
chk "X-Content-Type-Options gesetzt" "1" "$(curl -sI "$B/update.php" | grep -ci '^X-Content-Type-Options: nosniff' || true)"
curl -s -o /dev/null "$B/update.php?user=smokeuser&password=LEAKMARKER123&domain=a.example.com&ipv4=1.2.3.4"
sleep 1
chk "Passwort nicht im Access-Log" "0" "$(docker logs $NAME 2>&1 | grep -c LEAKMARKER123 || true)"
chk "update.php im Access-Log (Log aktiv)" "1" "$(docker logs $NAME 2>&1 | grep -c '"GET /update.php HTTP' | awk '{print ($1>0)}')"
chk "kein Argumentwert im Exception-Trace" "0" "$(curl -s "$B/update.php?user=smokeuser&password=LEAKMARKER123&domain=a.example.com&ipv4=1.2.3.4" | grep -c LEAKMARKER123 || true)"
# Beweis, dass die .htaccess ohne das veraltete mod_access_compat greift.
docker exec -i "$NAME" sh -s <<'INNER' >/dev/null 2>&1
sed -i 's|^LoadModule access_compat_module|#LoadModule access_compat_module|' /etc/apache2/httpd.conf
httpd -k restart
INNER
sleep 3
chk "mod_access_compat deaktiviert" "0" "$(docker exec $NAME sh -c 'httpd -M 2>/dev/null | grep -c access_compat')"
chk "Sperre haelt trotzdem: /.env" "403" "$(code /.env)"
chk "Sperre haelt trotzdem: /log.json" "403" "$(code /log.json)"
chk "Apache laeuft weiter: /update.php" "200" "$(code /update.php)"
docker restart $NAME >/dev/null; for i in $(seq 1 30); do [ "$(code /update.php)" != "000" ] && break; sleep 1; done

echo "== 7. Anwendungspfad (ohne Netcup-Login) =="
r() { curl -s "$B/update.php?$1"; }
chk "leere Anfrage -> payload invalid" "1" "$(r '' | grep -c 'payload invalid')"
chk "ungueltige IPv4 -> payload invalid" "1" "$(r 'user=smokeuser&password=smokepass&domain=a.example.com&ipv4=999.1.1.1' | grep -c 'payload invalid')"
chk "falsches Passwort -> credentials wrong" "1" "$(r 'user=smokeuser&password=WRONG&domain=a.example.com&ipv4=1.2.3.4' | grep -c 'credentials wrong')"

echo "== 8. Ausgehende SOAP/TLS-Kette (nur WSDL-Abruf, kein Login) =="
chk "WSDL ladbar, API-Methoden sichtbar" "1" "$(docker exec $NAME php -r '
  $w="https://ccp.netcup.net/run/webservice/servers/endpoint.php?WSDL";
  try { $c=new SoapClient($w); echo (int)(count($c->__getFunctions())>0); }
  catch (Throwable $e) { echo 0; }' 2>/dev/null)"

echo "== 9. Kompatibilitaet mit Altbestand (Mounts der alten Pfade) =="
CREDS="-e OWNDYNDNS_USERNAME=smokeuser -e OWNDYNDNS_PASSWORD=smokepass -e NETCUP_APIKEY=K -e NETCUP_APIPASSWORD=P -e NETCUP_CUSTOMERID=1"
start_c() { # start_c <suffix> <docker run args...>
  local n="$NAME-$1"; shift
  docker rm -f "$n" >/dev/null 2>&1
  docker run -d --name "$n" $CREDS "$@" "$IMAGE" >/dev/null || return 1
  for i in $(seq 1 30); do docker exec "$n" curl -s -o /dev/null http://127.0.0.1/ 2>/dev/null && break; sleep 1; done
}
ccode() { docker exec "$NAME-$1" curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1$2"; }
cwrong() { docker exec "$NAME-$1" curl -s "http://127.0.0.1/update.php?user=smokeuser&password=WRONG&domain=a.example.com&ipv4=1.2.3.4" | grep -c 'credentials wrong'; }

chk "bash und curl vorhanden (Healthchecks)" "ok" "$(docker exec $NAME bash -c 'curl --version >/dev/null && echo ok')"

# a) leerer Bind-Mount auf /app/public
mkdir -p "$TMPD/bind"
start_c bind -v "$TMPD/bind:/app/public"
chk "Bind-Mount /app/public: neuer Code antwortet" "1" "$(cwrong bind)"

# b) Named Volume mit dem Inhalt eines alten Images
docker volume rm -f "$NAME-oldvol" >/dev/null 2>&1
docker run --rm -v "$NAME-oldvol:/p" alpine:3.24 sh -c '
  printf "<?php echo \"ALTER CODE\";\n" > /p/update.php
  mkdir -p /p/src && echo x > /p/src/Handler.php
  printf "debug=true\nlog=true\nlogFile=log.json\nusername=\"alt\"\npassword=\"altpass\"\n" > /p/.env
  echo "{}" > /p/log.json
  printf "Options -Indexes\n" > /p/.htaccess' >/dev/null
start_c vol -v "$NAME-oldvol:/app/public"
chk "Altes Volume: neuer Code statt altem" "1" "$(cwrong vol)"
chk "Altes Volume: src/ entfernt" "nein" "$(docker exec $NAME-vol sh -c '[ -e /app/public/src ] && echo ja || echo nein')"
chk "Altes Volume: Zugangsdaten aus alter .env entfernt" "0" "$(docker exec $NAME-vol sh -c 'grep -c password /app/public/.env || true')"
chk "Altes Volume: debug aus alter .env uebernommen" "debug=true" "$(docker exec $NAME-vol grep '^debug' /app/owndyndns/.env)"
chk "Altes Volume: altes log.json weiter benutzt" 'logFile="/app/public/log.json"' "$(docker exec $NAME-vol grep '^logFile' /app/owndyndns/.env)"
chk "Altes Volume: log.json fuer apache schreibbar" "ja" "$(docker exec -u apache $NAME-vol sh -c '[ -w /app/public/log.json ] && echo ja || echo nein')"
for p in /.env /log.json /src/Handler.php; do chk "Altes Volume: gesperrt $p" "403" "$(ccode vol $p)"; done

# c) einzeln gemountete Dateien: .env, log.json, .htaccess mit "Options"
mkdir -p "$TMPD/files"
printf 'debug=true\nlog=true\nlogFile=log.json\nusername="alt"\npassword="altpass"\n' > "$TMPD/files/env"
echo '{}' > "$TMPD/files/log.json"
printf 'Options -Indexes\n<FilesMatch "^\\.">\n    Require all denied\n</FilesMatch>\n' > "$TMPD/files/htaccess"
start_c files -v "$TMPD/files/env:/app/public/.env" -v "$TMPD/files/log.json:/app/public/log.json" -v "$TMPD/files/htaccess:/app/public/.htaccess"
chk "Datei-Mounts: Anwendung antwortet (kein 500)" "1" "$(cwrong files)"
chk "Datei-Mounts: logFile zeigt auf gemountete Datei" 'logFile="/app/public/log.json"' "$(docker exec $NAME-files grep '^logFile' /app/owndyndns/.env)"
chk "Datei-Mounts: Zugangsdaten aus Host-Datei entfernt" "0" "$(grep -c password "$TMPD/files/env" || true)"

# d) eigene .htaccess greift (AllowOverride)
mkdir -p "$TMPD/deny"; printf 'Require all denied\n' > "$TMPD/deny/htaccess"
start_c deny -v "$TMPD/deny/htaccess:/app/public/.htaccess"
chk "eigene .htaccess wird beachtet" "403" "$(ccode deny /update.php)"

# e) ungueltiger ServerName -> Warnung statt Neustart-Schleife
start_c sname -e 'APACHE_SERVER_NAME=my host'
chk "ungueltiger ServerName: Container laeuft" "running" "$(docker inspect -f '{{.State.Status}}' $NAME-sname)"
chk "ungueltiger ServerName: Warnung im Log" "1" "$(docker logs $NAME-sname 2>&1 | grep -c 'ServerName not set')"

echo
echo "-------------------------------------------"
printf "bestanden: %d   fehlgeschlagen: %d\n" "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
