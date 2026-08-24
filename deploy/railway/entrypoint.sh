#!/bin/sh
set -eu

PUBLIC_PORT=${PORT:-8080}
INTERNAL_API_PORT=${API_PORT:-3000}
PERSISTENT_DATA_DIR=${DATA_DIR:-/data}

case "$PUBLIC_PORT" in
  ''|*[!0-9]*) echo "PORT must be a numeric TCP port" >&2; exit 64 ;;
esac
case "$INTERNAL_API_PORT" in
  ''|*[!0-9]*) echo "API_PORT must be a numeric TCP port" >&2; exit 64 ;;
esac
if [ "$PUBLIC_PORT" -lt 1 ] || [ "$PUBLIC_PORT" -gt 65535 ]; then
  echo "PORT must be between 1 and 65535" >&2
  exit 64
fi
if [ "$INTERNAL_API_PORT" -lt 1 ] || [ "$INTERNAL_API_PORT" -gt 65535 ]; then
  echo "API_PORT must be between 1 and 65535" >&2
  exit 64
fi
if [ "$PUBLIC_PORT" = "$INTERNAL_API_PORT" ]; then
  echo "PORT and API_PORT must be different" >&2
  exit 64
fi

mkdir -p "$PERSISTENT_DATA_DIR"
if [ ! -w "$PERSISTENT_DATA_DIR" ]; then
  echo "DATA_DIR is not writable: $PERSISTENT_DATA_DIR" >&2
  exit 73
fi

export PORT="$PUBLIC_PORT"
export API_PORT="$INTERNAL_API_PORT"
export DATA_DIR="$PERSISTENT_DATA_DIR"

# Limit substitution to our two placeholders so nginx variables such as $host remain intact.
envsubst '${PORT} ${API_PORT}' \
  < /app/railway/nginx.conf.template \
  > /etc/nginx/nginx.conf

nginx -t

# The API itself reads PORT, so override it for only this child. The shell keeps Railway's public
# PORT for nginx and for the container health check.
PORT="$INTERNAL_API_PORT" node /app/api/server.js &
api_pid=$!
nginx -g 'daemon off;' &
nginx_pid=$!

shutdown() {
  trap - INT TERM
  echo "Stopping openGym..." >&2
  kill -QUIT "$nginx_pid" 2>/dev/null || true
  kill -TERM "$api_pid" 2>/dev/null || true
  wait "$nginx_pid" 2>/dev/null || true
  wait "$api_pid" 2>/dev/null || true
  exit 0
}

trap shutdown INT TERM

# BusyBox ash does not provide a portable way to retrieve whichever child exits first. Poll both
# PIDs, then preserve the failed process's status and stop its sibling. A clean, unexpected child
# exit is still a container failure so Railway can restart it.
while kill -0 "$api_pid" 2>/dev/null && kill -0 "$nginx_pid" 2>/dev/null; do
  sleep 1 &
  wait $! || true
done

exit_status=1
if ! kill -0 "$api_pid" 2>/dev/null; then
  if wait "$api_pid"; then exit_status=1; else exit_status=$?; fi
  echo "openGym API exited unexpectedly (status $exit_status); stopping nginx" >&2
  kill -QUIT "$nginx_pid" 2>/dev/null || true
  wait "$nginx_pid" 2>/dev/null || true
else
  if wait "$nginx_pid"; then exit_status=1; else exit_status=$?; fi
  echo "nginx exited unexpectedly (status $exit_status); stopping openGym API" >&2
  kill -TERM "$api_pid" 2>/dev/null || true
  wait "$api_pid" 2>/dev/null || true
fi

exit "$exit_status"
