<?php
// Entry point in the document root. The real application, its .env with the
// credentials and src/ live in /app/owndyndns, outside the document root, so
// none of them can ever be served directly -- whatever the access rules say.
// ownDynDNS reads '.env' relative to the working directory, hence the chdir.
chdir('/app/owndyndns');
require '/app/owndyndns/update.php';
