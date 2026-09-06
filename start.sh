#!/bin/sh

# Apache server name change
if [ ! -z "$APACHE_SERVER_NAME" ]
	then
		sed -i "s|#ServerName www.example.com:80|ServerName $APACHE_SERVER_NAME|" /etc/apache2/httpd.conf
		echo "Changed server name to '$APACHE_SERVER_NAME'..."
	else
		echo "NOTICE: Change 'ServerName' globally and hide server message by setting environment variable >> 'APACHE_SERVER_NAME=your.server.name' in docker command or docker-compose file"
fi

# PHP Config
if [ ! -z "$PHP_SHORT_OPEN_TAG" ]; then sed -i "s|^;\\?[[:space:]]*short_open_tag[[:space:]]*=.*|short_open_tag = $PHP_SHORT_OPEN_TAG|" /etc/php85/php.ini && echo "Set PHP short_open_tag = $PHP_SHORT_OPEN_TAG..."; fi
if [ ! -z "$PHP_OUTPUT_BUFFERING" ]; then sed -i "s|^;\\?[[:space:]]*output_buffering[[:space:]]*=.*|output_buffering = $PHP_OUTPUT_BUFFERING|" /etc/php85/php.ini && echo "Set PHP output_buffering = $PHP_OUTPUT_BUFFERING..."; fi
if [ ! -z "$PHP_OPEN_BASEDIR" ]; then sed -i "s|^;\\?[[:space:]]*open_basedir[[:space:]]*=.*|open_basedir = $PHP_OPEN_BASEDIR|" /etc/php85/php.ini && echo "Set PHP open_basedir = $PHP_OPEN_BASEDIR..."; fi
if [ ! -z "$PHP_MAX_EXECUTION_TIME" ]; then sed -i "s|^;\\?[[:space:]]*max_execution_time[[:space:]]*=.*|max_execution_time = $PHP_MAX_EXECUTION_TIME|" /etc/php85/php.ini && echo "Set PHP max_execution_time = $PHP_MAX_EXECUTION_TIME..."; fi
if [ ! -z "$PHP_MAX_INPUT_TIME" ]; then sed -i "s|^;\\?[[:space:]]*max_input_time[[:space:]]*=.*|max_input_time = $PHP_MAX_INPUT_TIME|" /etc/php85/php.ini && echo "Set PHP max_input_time = $PHP_MAX_INPUT_TIME..."; fi
if [ ! -z "$PHP_MAX_INPUT_VARS" ]; then sed -i "s|^;\\?[[:space:]]*max_input_vars[[:space:]]*=.*|max_input_vars = $PHP_MAX_INPUT_VARS|" /etc/php85/php.ini && echo "Set PHP max_input_vars = $PHP_MAX_INPUT_VARS..."; fi
if [ ! -z "$PHP_MEMORY_LIMIT" ]; then sed -i "s|^;\\?[[:space:]]*memory_limit[[:space:]]*=.*|memory_limit = $PHP_MEMORY_LIMIT|" /etc/php85/php.ini && echo "Set PHP memory_limit = $PHP_MEMORY_LIMIT..."; fi
if [ ! -z "$PHP_ERROR_REPORTING" ]; then sed -i "s|^;\\?[[:space:]]*error_reporting[[:space:]]*=.*|error_reporting = $PHP_ERROR_REPORTING|" /etc/php85/php.ini && echo "Set PHP error_reporting = $PHP_ERROR_REPORTING..."; fi
if [ ! -z "$PHP_DISPLAY_ERRORS" ]; then sed -i "s|^;\\?[[:space:]]*display_errors[[:space:]]*=.*|display_errors = $PHP_DISPLAY_ERRORS|" /etc/php85/php.ini && echo "Set PHP display_errors = $PHP_DISPLAY_ERRORS..."; fi
if [ ! -z "$PHP_DISPLAY_STARTUP_ERRORS" ]; then sed -i "s|^;\\?[[:space:]]*display_startup_errors[[:space:]]*=.*|display_startup_errors = $PHP_DISPLAY_STARTUP_ERRORS|" /etc/php85/php.ini && echo "Set PHP display_startup_errors = $PHP_DISPLAY_STARTUP_ERRORS..."; fi
if [ ! -z "$PHP_LOG_ERRORS" ]; then sed -i "s|^;\\?[[:space:]]*log_errors[[:space:]]*=.*|log_errors = $PHP_LOG_ERRORS|" /etc/php85/php.ini && echo "Set PHP log_errors = $PHP_LOG_ERRORS..."; fi
if [ ! -z "$PHP_LOG_ERRORS_MAX_LEN" ]; then sed -i "s|^;\\?[[:space:]]*log_errors_max_len[[:space:]]*=.*|log_errors_max_len = $PHP_LOG_ERRORS_MAX_LEN|" /etc/php85/php.ini && echo "Set PHP log_errors_max_len = $PHP_LOG_ERRORS_MAX_LEN..."; fi
if [ ! -z "$PHP_IGNORE_REPEATED_ERRORS" ]; then sed -i "s|^;\\?[[:space:]]*ignore_repeated_errors[[:space:]]*=.*|ignore_repeated_errors = $PHP_IGNORE_REPEATED_ERRORS|" /etc/php85/php.ini && echo "Set PHP ignore_repeated_errors = $PHP_IGNORE_REPEATED_ERRORS..."; fi
if [ ! -z "$PHP_REPORT_MEMLEAKS" ]; then sed -i "s|^;\\?[[:space:]]*report_memleaks[[:space:]]*=.*|report_memleaks = $PHP_REPORT_MEMLEAKS|" /etc/php85/php.ini && echo "Set PHP report_memleaks = $PHP_REPORT_MEMLEAKS..."; fi
if [ ! -z "$PHP_HTML_ERRORS" ]; then sed -i "s|^;\\?[[:space:]]*html_errors[[:space:]]*=.*|html_errors = $PHP_HTML_ERRORS|" /etc/php85/php.ini && echo "Set PHP html_errors = $PHP_HTML_ERRORS..."; fi
if [ ! -z "$PHP_ERROR_LOG" ]; then sed -i "s|^;\\?[[:space:]]*error_log[[:space:]]*=.*|error_log = $PHP_ERROR_LOG|" /etc/php85/php.ini && echo "Set PHP error_log = $PHP_ERROR_LOG..."; fi
if [ ! -z "$PHP_POST_MAX_SIZE" ]; then sed -i "s|^;\\?[[:space:]]*post_max_size[[:space:]]*=.*|post_max_size = $PHP_POST_MAX_SIZE|" /etc/php85/php.ini && echo "Set PHP post_max_size = $PHP_POST_MAX_SIZE..."; fi
if [ ! -z "$PHP_DEFAULT_MIMETYPE" ]; then sed -i "s|^;\\?[[:space:]]*default_mimetype[[:space:]]*=.*|default_mimetype = $PHP_DEFAULT_MIMETYPE|" /etc/php85/php.ini && echo "Set PHP default_mimetype = $PHP_DEFAULT_MIMETYPE..."; fi
if [ ! -z "$PHP_DEFAULT_CHARSET" ]; then sed -i "s|^;\\?[[:space:]]*default_charset[[:space:]]*=.*|default_charset = $PHP_DEFAULT_CHARSET|" /etc/php85/php.ini && echo "Set PHP default_charset = $PHP_DEFAULT_CHARSET..."; fi
if [ ! -z "$PHP_FILE_UPLOADS" ]; then sed -i "s|^;\\?[[:space:]]*file_uploads[[:space:]]*=.*|file_uploads = $PHP_FILE_UPLOADS|" /etc/php85/php.ini && echo "Set PHP file_uploads = $PHP_FILE_UPLOADS..."; fi
if [ ! -z "$PHP_UPLOAD_TMP_DIR" ]; then sed -i "s|^;\\?[[:space:]]*upload_tmp_dir[[:space:]]*=.*|upload_tmp_dir = $PHP_UPLOAD_TMP_DIR|" /etc/php85/php.ini && echo "Set PHP upload_tmp_dir = $PHP_UPLOAD_TMP_DIR..."; fi
if [ ! -z "$PHP_UPLOAD_MAX_FILESIZE" ]; then sed -i "s|^;\\?[[:space:]]*upload_max_filesize[[:space:]]*=.*|upload_max_filesize = $PHP_UPLOAD_MAX_FILESIZE|" /etc/php85/php.ini && echo "Set PHP upload_max_filesize = $PHP_UPLOAD_MAX_FILESIZE..."; fi
if [ ! -z "$PHP_MAX_FILE_UPLOADS" ]; then sed -i "s|^;\\?[[:space:]]*max_file_uploads[[:space:]]*=.*|max_file_uploads = $PHP_MAX_FILE_UPLOADS|" /etc/php85/php.ini && echo "Set PHP max_file_uploads = $PHP_MAX_FILE_UPLOADS..."; fi
if [ ! -z "$PHP_ALLOW_URL_FOPEN" ]; then sed -i "s|^;\\?[[:space:]]*allow_url_fopen[[:space:]]*=.*|allow_url_fopen = $PHP_ALLOW_URL_FOPEN|" /etc/php85/php.ini && echo "Set PHP allow_url_fopen = $PHP_ALLOW_URL_FOPEN..."; fi
if [ ! -z "$PHP_ALLOW_URL_INCLUDE" ]; then sed -i "s|^;\\?[[:space:]]*allow_url_include[[:space:]]*=.*|allow_url_include = $PHP_ALLOW_URL_INCLUDE|" /etc/php85/php.ini && echo "Set PHP allow_url_include = $PHP_ALLOW_URL_INCLUDE..."; fi
if [ ! -z "$PHP_DEFAULT_SOCKET_TIMEOUT" ]; then sed -i "s|^;\\?[[:space:]]*default_socket_timeout[[:space:]]*=.*|default_socket_timeout = $PHP_DEFAULT_SOCKET_TIMEOUT|" /etc/php85/php.ini && echo "Set PHP default_socket_timeout = $PHP_DEFAULT_SOCKET_TIMEOUT..."; fi
if [ ! -z "$PHP_DATE_TIMEZONE" ]; then sed -i "s|^;\\?[[:space:]]*date.timezone[[:space:]]*=.*|date.timezone = $PHP_DATE_TIMEZONE|" /etc/php85/php.ini && echo "Set PHP date.timezone = $PHP_DATE_TIMEZONE..."; fi
if [ ! -z "$PHP_PDO_MYSQL_CACHE_SIZE" ]; then sed -i "s|^;\\?[[:space:]]*pdo_mysql.cache_size[[:space:]]*=.*|pdo_mysql.cache_size = $PHP_PDO_MYSQL_CACHE_SIZE|" /etc/php85/php.ini && echo "Set PHP pdo_mysql.cache_size = $PHP_PDO_MYSQL_CACHE_SIZE..."; fi
if [ ! -z "$PHP_PDO_MYSQL_DEFAULT_SOCKET" ]; then sed -i "s|^;\\?[[:space:]]*pdo_mysql.default_socket[[:space:]]*=.*|pdo_mysql.default_socket = $PHP_PDO_MYSQL_DEFAULT_SOCKET|" /etc/php85/php.ini && echo "Set PHP pdo_mysql.default_socket = $PHP_PDO_MYSQL_DEFAULT_SOCKET..."; fi
if [ ! -z "$PHP_SESSION_SAVE_HANDLER" ]; then sed -i "s|^;\\?[[:space:]]*session.save_handler[[:space:]]*=.*|session.save_handler = $PHP_SESSION_SAVE_HANDLER|" /etc/php85/php.ini && echo "Set PHP session.save_handler = $PHP_SESSION_SAVE_HANDLER..."; fi
if [ ! -z "$PHP_SESSION_SAVE_PATH" ]; then sed -i "s|^;\\?[[:space:]]*session.save_path[[:space:]]*=.*|session.save_path = $PHP_SESSION_SAVE_PATH|" /etc/php85/php.ini && echo "Set PHP session.save_path = $PHP_SESSION_SAVE_PATH..."; fi
if [ ! -z "$PHP_SESSION_USE_STRICT_MODE" ]; then sed -i "s|^;\\?[[:space:]]*session.use_strict_mode[[:space:]]*=.*|session.use_strict_mode = $PHP_SESSION_USE_STRICT_MODE|" /etc/php85/php.ini && echo "Set PHP session.use_strict_mode = $PHP_SESSION_USE_STRICT_MODE..."; fi
if [ ! -z "$PHP_SESSION_USE_COOKIES" ]; then sed -i "s|^;\\?[[:space:]]*session.use_cookies[[:space:]]*=.*|session.use_cookies = $PHP_SESSION_USE_COOKIES|" /etc/php85/php.ini && echo "Set PHP session.use_cookies = $PHP_SESSION_USE_COOKIES..."; fi
if [ ! -z "$PHP_SESSION_COOKIE_SECURE" ]; then sed -i "s|^;\\?[[:space:]]*session.cookie_secure[[:space:]]*=.*|session.cookie_secure = $PHP_SESSION_COOKIE_SECURE|" /etc/php85/php.ini && echo "Set PHP session.cookie_secure = $PHP_SESSION_COOKIE_SECURE..."; fi
if [ ! -z "$PHP_SESSION_NAME" ]; then sed -i "s|^;\\?[[:space:]]*session.name[[:space:]]*=.*|session.name = $PHP_SESSION_NAME|" /etc/php85/php.ini && echo "Set PHP session.name = $PHP_SESSION_NAME..."; fi
if [ ! -z "$PHP_SESSION_COOKIE_LIFETIME" ]; then sed -i "s|^;\\?[[:space:]]*session.cookie_lifetime[[:space:]]*=.*|session.cookie_lifetime = $PHP_SESSION_COOKIE_LIFETIME|" /etc/php85/php.ini && echo "Set PHP session.cookie_lifetime = $PHP_SESSION_COOKIE_LIFETIME..."; fi
if [ ! -z "$PHP_SESSION_COOKIE_PATH" ]; then sed -i "s|^;\\?[[:space:]]*session.cookie_path[[:space:]]*=.*|session.cookie_path = $PHP_SESSION_COOKIE_PATH|" /etc/php85/php.ini && echo "Set PHP session.cookie_path = $PHP_SESSION_COOKIE_PATH..."; fi
if [ ! -z "$PHP_SESSION_COOKIE_DOMAIN" ]; then sed -i "s|^;\\?[[:space:]]*session.cookie_domain[[:space:]]*=.*|session.cookie_domain = $PHP_SESSION_COOKIE_DOMAIN|" /etc/php85/php.ini && echo "Set PHP session.cookie_domain = $PHP_SESSION_COOKIE_DOMAIN..."; fi
if [ ! -z "$PHP_SESSION_COOKIE_HTTPONLY" ]; then sed -i "s|^;\\?[[:space:]]*session.cookie_httponly[[:space:]]*=.*|session.cookie_httponly = $PHP_SESSION_COOKIE_HTTPONLY|" /etc/php85/php.ini && echo "Set PHP session.cookie_httponly = $PHP_SESSION_COOKIE_HTTPONLY..."; fi

# Install ownDynDNS
echo "Installing ownDynDNS..."
git clone https://github.com/fernwerker/ownDynDNS /tmp/ownDynDNS
cp -v /tmp/ownDynDNS/*.php /app/public/
cp -avr /tmp/ownDynDNS/src /app/public/
chown -R apache:apache /app && chmod -R 755 /app

# Configure ownDynDNS
# Rebuild .env from the pristine template on every start, otherwise a container
# restart appends the credentials a second time and leaves rotated secrets behind.
echo "Configure ownDynDNS..."
cp /bootstrap/env.base /app/public/.env

if [ ! -z "$OWNDYNDNS_USERNAME" ];
	then
		printf "username=\"$OWNDYNDNS_USERNAME\"\n" >> /app/public/.env
	else
		echo "[ERROR] OWNDYNDNS_USERNAME Variable is not defined!"
fi

if [ ! -z "$OWNDYNDNS_PASSWORD" ];
	then
		printf "password=\"$OWNDYNDNS_PASSWORD\"\n" >> /app/public/.env
	else
		echo "[ERROR] OWNDYNDNS_PASSWORD Variable is not defined!"
fi

if [ ! -z "$NETCUP_APIKEY" ];
	then
		printf "apiKey=\"$NETCUP_APIKEY\"\n" >> /app/public/.env
	else
		echo "[ERROR] NETCUP_APIKEY Variable is not defined!"
fi

if [ ! -z "$NETCUP_APIPASSWORD" ];
	then
		printf "apiPassword=\"$NETCUP_APIPASSWORD\"\n" >> /app/public/.env
	else
		echo "[ERROR] NETCUP_APIPASSWORD Variable is not defined!"
fi

if [ ! -z "$NETCUP_CUSTOMERID" ];
	then
		printf "customerId=\"$NETCUP_CUSTOMERID\"\n" >> /app/public/.env
	else
		echo "[ERROR] NETCUP_CUSTOMERID Variable is not defined!"
fi

chmod 755 -Rc $(find /app/public -type d)
chmod 644 -Rc $(find /app/public -type f)
chown apache:apache /app/public/.env
chmod 660 -Rc /app/public/.env

# Clean
rm -f tmp.php

# Start (ensure apache2 PID not left behind first) to stop auto start crashes if didn't shut down properly

echo "Clearing any old processes..."
rm -f /run/apache2/apache2.pid
rm -f /run/apache2/httpd.pid

echo "Starting apache..."
httpd -D FOREGROUND
