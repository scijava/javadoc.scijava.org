#!/bin/bash
#
# apache-test.sh start|reload|stop|trace PATH... - try the site's Apache rules
# on a throwaway, unprivileged server before reloading production.
#
# The server listens on 127.0.0.1:$PORT and serves the build tree with the
# production include from loci-servers, its paths pointed at the build tree
# and the HTTPS redirect dropped. "reload" picks up edits to the include and
# rebuilds the redirect maps. "trace" follows each path's redirects while they
# stay on the test server. Check all URL behavior against it with:
#
#   python3 .tests/check.py --base http://127.0.0.1:18080
#
# (Its JDK checks of versions newer than we generate leave the site, and are
# not followed.)

set -euo pipefail

INCLUDE=${INCLUDE:-$HOME/code/loci/loci-servers/apache/sites/javadoc.scijava.org.include}
BUILD=${JD_BUILD:-/var/www/javadoc/build}
DIR=${JD_APACHE_TEST:-$HOME/.local/state/javadoc.scijava.org/apache-test}
PORT=${PORT:-18080}
MODULES=/usr/lib/apache2/modules
PATH=$PATH:/usr/sbin

configure() {
  mkdir -p "$DIR"
  ln -sfn "$BUILD" "$DIR/docroot"
  for map in redirects latest latest-fallback; do
    httxt2dbm -f SDBM -i "$BUILD/$map.map" -o "$DIR/$map.map.db"
  done
  # The production include, against the build tree: maps from this dir (the
  # build tree holds only their text form), files from the build tree.
  sed -e "s#/var/www/javadoc.scijava.org/\([a-z-]*\.map\.db\)#$DIR/\1#g" \
    -e "s#/var/www/javadoc.scijava.org#$DIR/docroot#g" \
    -e '/^RewriteCond %{HTTPS} !=on/,+1d' \
    "$INCLUDE" > "$DIR/site.include"
  cat > "$DIR/httpd.conf" <<EOF
ServerRoot "$DIR"
Listen 127.0.0.1:$PORT
PidFile $DIR/httpd.pid
ErrorLog $DIR/error.log
LogLevel warn rewrite:warn
LoadModule mpm_event_module $MODULES/mod_mpm_event.so
LoadModule authz_core_module $MODULES/mod_authz_core.so
LoadModule dir_module $MODULES/mod_dir.so
LoadModule mime_module $MODULES/mod_mime.so
LoadModule rewrite_module $MODULES/mod_rewrite.so
LoadModule headers_module $MODULES/mod_headers.so
LoadModule filter_module $MODULES/mod_filter.so
LoadModule substitute_module $MODULES/mod_substitute.so
ServerName localhost
DocumentRoot "$DIR/docroot"
<Directory "$DIR/docroot">
  Options FollowSymLinks
  Require all granted
</Directory>
TypesConfig /etc/mime.types
DirectoryIndex index.html
Include $DIR/site.include
EOF
  apache2 -f "$DIR/httpd.conf" -t
}

trace() {
  local base=http://127.0.0.1:$PORT
  for p in "$@"; do
    local url=$base$p chain="" code loc
    for _ in $(seq 10); do
      read -r code loc < <(curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' "$url")
      chain+=" $code"
      [ -n "$loc" ] || break
      url=${loc/https:\/\/localhost/$base}
      url=${url/http:\/\/localhost/$base}
      case $url in "$base"*) ;; *) chain+=" -> $url"; break ;; esac
    done
    printf '%-62s%s  [%s]\n' "$p" "$chain" "${url#"$base"}"
  done
}

case "${1:-}" in
  start) configure && apache2 -f "$DIR/httpd.conf" -k start ;;
  reload) configure && apache2 -f "$DIR/httpd.conf" -k graceful ;;
  stop) apache2 -f "$DIR/httpd.conf" -k stop ;;
  trace) shift; trace "$@" ;;
  *) sed -n '3,15s/^# \{0,1\}//p' "$0" >&2; exit 2 ;;
esac
