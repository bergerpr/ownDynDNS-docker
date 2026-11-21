#!/bin/sh
set -eu

NL='
'
ENV_FILE=/app/owndyndns/.env
PHP_INI=/etc/php85/php.ini

PUBLIC=/app/public
LEGACY_ENV=$PUBLIC/.env
LEGACY_LOG=$PUBLIC/log.json
CREDENTIAL_KEYS='username|password|apiKey|apiPassword|customerId'

die()  { echo "[ERROR] $*" >&2; exit 1; }
warn() { echo "[WARNING] $*" >&2; }

# Escape a string for use as the replacement part of a sed s|||-expression.
sed_repl_escape() { printf '%s' "$1" | sed -e 's/[\\|&]/\\&/g'; }

if [ -r /app/owndyndns/REVISION ]; then
	echo "ownDynDNS upstream commit: $(cat /app/owndyndns/REVISION)"
fi
. /etc/os-release 2>/dev/null && echo "Base image: $PRETTY_NAME"

# Apache server name change
# Written to its own file on every start, so a changed name also takes effect
# after a restart. An invalid name is skipped, not fatal: older images accepted
# anything, and a container must not end up in a restart loop over it.
rm -f /etc/apache2/conf.d/servername.conf
if [ -n "${APACHE_SERVER_NAME:-}" ]; then
	case "$APACHE_SERVER_NAME" in
		*[!A-Za-z0-9._:-]*)
			warn "APACHE_SERVER_NAME '$APACHE_SERVER_NAME' contains invalid characters, ServerName not set" ;;
		*)
			printf 'ServerName %s\n' "$APACHE_SERVER_NAME" > /etc/apache2/conf.d/servername.conf
			echo "Changed server name to '$APACHE_SERVER_NAME'..." ;;
	esac
else
	echo "NOTICE: Change 'ServerName' globally and hide server message by setting environment variable >> 'APACHE_SERVER_NAME=your.server.name' in docker command or docker-compose file"
fi

# PHP Config
# Each line maps an environment variable to a php.ini directive.
PHP_SETTINGS='
PHP_SHORT_OPEN_TAG short_open_tag
PHP_OUTPUT_BUFFERING output_buffering
PHP_OPEN_BASEDIR open_basedir
PHP_MAX_EXECUTION_TIME max_execution_time
PHP_MAX_INPUT_TIME max_input_time
PHP_MAX_INPUT_VARS max_input_vars
PHP_MEMORY_LIMIT memory_limit
PHP_ERROR_REPORTING error_reporting
PHP_DISPLAY_ERRORS display_errors
PHP_DISPLAY_STARTUP_ERRORS display_startup_errors
PHP_LOG_ERRORS log_errors
PHP_LOG_ERRORS_MAX_LEN log_errors_max_len
PHP_IGNORE_REPEATED_ERRORS ignore_repeated_errors
PHP_REPORT_MEMLEAKS report_memleaks
PHP_HTML_ERRORS html_errors
PHP_ERROR_LOG error_log
PHP_POST_MAX_SIZE post_max_size
PHP_DEFAULT_MIMETYPE default_mimetype
PHP_DEFAULT_CHARSET default_charset
PHP_FILE_UPLOADS file_uploads
PHP_UPLOAD_TMP_DIR upload_tmp_dir
PHP_UPLOAD_MAX_FILESIZE upload_max_filesize
PHP_MAX_FILE_UPLOADS max_file_uploads
PHP_ALLOW_URL_FOPEN allow_url_fopen
PHP_ALLOW_URL_INCLUDE allow_url_include
PHP_DEFAULT_SOCKET_TIMEOUT default_socket_timeout
PHP_DATE_TIMEZONE date.timezone
PHP_PDO_MYSQL_CACHE_SIZE pdo_mysql.cache_size
PHP_PDO_MYSQL_DEFAULT_SOCKET pdo_mysql.default_socket
PHP_SESSION_SAVE_HANDLER session.save_handler
PHP_SESSION_SAVE_PATH session.save_path
PHP_SESSION_USE_STRICT_MODE session.use_strict_mode
PHP_SESSION_USE_COOKIES session.use_cookies
PHP_SESSION_COOKIE_SECURE session.cookie_secure
PHP_SESSION_NAME session.name
PHP_SESSION_COOKIE_LIFETIME session.cookie_lifetime
PHP_SESSION_COOKIE_PATH session.cookie_path
PHP_SESSION_COOKIE_DOMAIN session.cookie_domain
PHP_SESSION_COOKIE_HTTPONLY session.cookie_httponly
'

echo "$PHP_SETTINGS" | while read -r var directive; do
	[ -n "$var" ] || continue
	# $var comes from the fixed list above, never from outside.
	eval "value=\${$var:-}"
	[ -n "$value" ] || continue
	case "$value" in *"$NL"*) die "$var must not contain a line break" ;; esac
	key_re=$(printf '%s' "$directive" | sed 's/\./\\./g')
	sed -i "s|^;\\?[[:space:]]*${key_re}[[:space:]]*=.*|${directive} = $(sed_repl_escape "$value")|" "$PHP_INI"
	echo "Set PHP $directive = $value..."
done

# Document root
# Older images kept the whole application (and the generated .env) in
# /app/public. With a volume on /app/public that content survives an image
# update: the old code would keep running with stale credentials, and a fresh
# bind mount would hide the entry point. So the entry point is installed on
# every start and the old application code is removed.
if ! cmp -s /bootstrap/update.php "$PUBLIC/update.php" 2>/dev/null; then
	if cp /bootstrap/update.php "$PUBLIC/update.php" 2>/dev/null; then
		chmod 644 "$PUBLIC/update.php" 2>/dev/null || true
		echo "Installed entry point $PUBLIC/update.php..."
	else
		warn "could not write $PUBLIC/update.php (read-only mount?) - the service will not answer"
	fi
fi
if [ -d "$PUBLIC/src" ]; then
	if rm -rf "$PUBLIC/src" 2>/dev/null; then
		echo "NOTICE: removed old application code $PUBLIC/src (layout of older images)"
	else
		warn "could not remove old application code $PUBLIC/src"
	fi
fi

# Configure ownDynDNS
# Rebuild .env from the pristine template on every start, otherwise a container
# restart appends the credentials a second time and leaves rotated secrets behind.
echo "Configure ownDynDNS..."

# ini_value <key> <file>: last value of <key>, surrounding double quotes removed.
ini_value() {
	[ -f "$2" ] || return 0
	sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" "$2" | tail -n 1 \
		| sed -e 's/[[:space:]]*$//' -e 's/^"\(.*\)"$/\1/'
}

# A .env in the document root is the configuration of older images, often a
# bind mount. Its settings (debug, log, logFile) are still honoured; the
# credentials always come from the environment variables.
if [ -f "$LEGACY_ENV" ]; then
	echo "NOTICE: $LEGACY_ENV is the layout of older images. Its debug/log/logFile settings are still used; credentials come from the environment variables."
	if grep -Eq "^[[:space:]]*($CREDENTIAL_KEYS)[[:space:]]*=" "$LEGACY_ENV"; then
		tmp=$(mktemp)
		grep -Ev "^[[:space:]]*($CREDENTIAL_KEYS)[[:space:]]*=" "$LEGACY_ENV" > "$tmp" || true
		# Written in place (not replaced), so this also works for a bind-mounted file.
		if ( cat "$tmp" > "$LEGACY_ENV" ) 2>/dev/null; then
			echo "NOTICE: removed credentials from $LEGACY_ENV"
		else
			warn "could not remove the credentials from $LEGACY_ENV (read-only mount?). It is not served, but please delete them there."
		fi
		rm -f "$tmp"
	fi
fi

# bool_setting <key>: value from the old .env if valid, else from the template.
bool_setting() {
	value=$(ini_value "$1" "$LEGACY_ENV")
	if [ -n "$value" ]; then
		case $(printf '%s' "$value" | tr 'A-Z' 'a-z') in
			true|false|on|off|yes|no|1|0) printf '%s' "$value"; return 0 ;;
			*) warn "ignoring invalid value for $1 in $LEGACY_ENV" ;;
		esac
	fi
	ini_value "$1" /bootstrap/env.base
}
debug=$(bool_setting debug)
log=$(bool_setting log)

# Log file: an absolute logFile from the old .env wins, then a log.json mounted
# into the document root (old layout), then the default /app/data/log.json.
log_file=$(ini_value logFile "$LEGACY_ENV")
case "$log_file" in
	/*) ;;
	*)  log_file="" ;;  # relative paths pointed into the old document root
esac
case "$log_file" in
	*'"'*|*'\'*|*'$'*) warn "ignoring logFile with unsupported characters"; log_file="" ;;
esac
if [ -z "$log_file" ] && [ -f "$LEGACY_LOG" ]; then
	log_file=$LEGACY_LOG
	echo "NOTICE: using $LEGACY_LOG (layout of older images). Please mount a volume at /app/data instead."
fi
[ -n "$log_file" ] || log_file=$(ini_value logFile /bootstrap/env.base)
case "$log_file" in
	/app/*|/tmp/*) ;;
	*) warn "logFile $log_file is outside /app and /tmp; PHP open_basedir will block it" ;;
esac
if [ -f "$log_file" ]; then
	chown apache:apache "$log_file" 2>/dev/null || warn "could not hand $log_file to the web server"
fi

# write_env <ini key> <env var name>
# Writes key="value" with the value escaped for parse_ini_file: backslash and
# double quote are escaped; line breaks and ${...} (PHP would expand it) are rejected.
write_env() {
	eval "value=\${$2:-}"
	if [ -z "$value" ]; then
		echo "[ERROR] $2 Variable is not defined!"
		return 0
	fi
	case "$value" in
		*"$NL"*) die "$2 must not contain a line break" ;;
		*'${'*)  die "$2 must not contain the sequence \${" ;;
	esac
	printf '%s="%s"\n' "$1" "$(printf '%s' "$value" | sed -e 's/[\\"]/\\&/g')" >> "$ENV_FILE.tmp"
}

umask 027
{
	printf 'debug=%s\n' "$debug"
	printf 'log=%s\n' "$log"
	printf 'logFile="%s"\n' "$log_file"
} > "$ENV_FILE.tmp"
write_env username    OWNDYNDNS_USERNAME
write_env password    OWNDYNDNS_PASSWORD
write_env apiKey      NETCUP_APIKEY
write_env apiPassword NETCUP_APIPASSWORD
write_env customerId  NETCUP_CUSTOMERID
# Readable by the web server, writable only by root.
chown root:apache "$ENV_FILE.tmp"
chmod 640 "$ENV_FILE.tmp"
mv -f "$ENV_FILE.tmp" "$ENV_FILE"
umask 022

# A mounted /app/data volume may come with other ownership (or refuse chown,
# e.g. NFS with root_squash) - warn, but keep starting.
{ chown apache:apache /app/data && chmod 750 /app/data; } 2>/dev/null \
	|| warn "could not hand /app/data to the web server; the log may not be writable"

# Start (ensure apache2 PID not left behind first) to stop auto start crashes if didn't shut down properly
echo "Clearing any old processes..."
rm -f /run/apache2/apache2.pid
rm -f /run/apache2/httpd.pid

echo "Starting apache..."
exec httpd -D FOREGROUND
