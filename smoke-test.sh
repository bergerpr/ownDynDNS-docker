#!/usr/bin/env bash
#
# Smoke test for the ownDynDNS container.
#
# Builds the image, starts it with throwaway settings and asserts that the
# container comes up, that the PHP settings passed as environment variables
# actually land in php.ini, that .env is rebuilt (not appended to) on restart,
# that the .htaccess denials hold even without the deprecated mod_access_compat,
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

trap 'docker rm -f "$NAME" >/dev/null 2>&1' EXIT

echo "== 1. Build =="
docker build -q -t "$IMAGE" . >/dev/null || { echo "Build fehlgeschlagen"; exit 1; }
echo "  OK   Image gebaut"

echo "== 2. Start =="
docker rm -f "$NAME" >/dev/null 2>&1
docker run -d --name "$NAME" -p "${PORT}:80" \
  -e APACHE_SERVER_NAME=smoke.test \
  -e OWNDYNDNS_USERNAME=smokeuser -e OWNDYNDNS_PASSWORD=smokepass \
  -e NETCUP_APIKEY=SMOKE_KEY -e NETCUP_APIPASSWORD=SMOKE_APIPASS -e NETCUP_CUSTOMERID=100000 \
  -e PHP_DATE_TIMEZONE=Europe/Berlin -e PHP_MEMORY_LIMIT=256M \
  "$IMAGE" >/dev/null || exit 1
for i in $(seq 1 30); do [ "$(code /update.php)" != "000" ] && break; sleep 1; done
chk "Container laeuft" "running" "$(docker inspect -f '{{.State.Status}}' $NAME)"
chk "Apache Konfiguration" "Syntax OK" "$(docker exec $NAME httpd -t 2>&1)"
chk "keine sed-Fehler im Startlog" "0" "$(docker logs $NAME 2>&1 | grep -c 'sed:')"

echo "== 3. PHP-Umgebung =="
chk "PHP-Version" "8.5" "$(docker exec $NAME php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"
chk "date.timezone (Pfadwert via ENV)" "Europe/Berlin" "$(docker exec $NAME php -r 'echo ini_get("date.timezone");')"
chk "memory_limit via ENV" "256M" "$(docker exec $NAME php -r 'echo ini_get("memory_limit");')"
for e in soap mbstring curl json simplexml openssl; do
  chk "Extension $e" "1" "$(docker exec $NAME php -r "echo (int)extension_loaded('$e');")"
done

echo "== 4. Konfiguration =="
chk ".env Zeilenzahl" "8" "$(docker exec $NAME sh -c 'wc -l < /app/public/.env' | tr -d ' ')"
chk ".env ohne CR" "0" "$(docker exec $NAME sh -c "grep -c \$'\r' /app/public/.env || true" | tr -d ' ')"
chk ".env Eigentuemer" "apache" "$(docker exec $NAME stat -c '%U' /app/public/.env)"
chk ".env Rechte" "660" "$(docker exec $NAME stat -c '%a' /app/public/.env)"

echo "== 5. Idempotenz ueber Neustarts =="
before=$(docker exec $NAME md5sum /app/public/.env | cut -d' ' -f1)
for i in 1 2 3; do docker restart $NAME >/dev/null; done
for i in $(seq 1 30); do [ "$(code /update.php)" != "000" ] && break; sleep 1; done
chk ".env nach 3 Neustarts unveraendert" "$before" "$(docker exec $NAME md5sum /app/public/.env | cut -d' ' -f1)"

echo "== 6. Absicherung =="
for p in /.env "/.env/" "/.env." "/%2Eenv" "/./.env" "/src/../.env" /log.json "/log.json/" /.htaccess /; do
  chk "gesperrt: $p" "403" "$(code "$p")"
done
chk "erreichbar: /update.php" "200" "$(code /update.php)"
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

echo
echo "-------------------------------------------"
printf "bestanden: %d   fehlgeschlagen: %d\n" "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
