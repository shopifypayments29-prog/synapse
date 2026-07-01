FROM matrixdotorg/synapse:latest

# Install nginx (for well-known/proxy), curl (for health checks), and pynacl (for cross-signing bootstrap)
RUN apt-get update && apt-get install -y nginx curl && rm -rf /var/lib/apt/lists/*

# Copy nginx config that serves server well-known and proxies to Synapse on 8009
COPY nginx.conf /etc/nginx/nginx.conf

# Put our custom files in /synapsechat instead of /data
# (because /data will be overwritten by the volume mount)
RUN mkdir -p /synapsechat

# Generate signing key at build time
RUN python3 -m synapse.app.homeserver \
      --server-name synapsechat.up.railway.app \
      --generate-keys \
      --config-path /synapsechat/homeserver.yaml \
      --keys-directory /synapsechat \
      --report-stats no || true

# Create the log config
RUN cat > /synapsechat/synapsechat.up.railway.app.log.config << 'EOF'
version: 1

formatters:
  precise:
    format: '%(asctime)s - %(name)s - %(lineno)d - %(levelname)s - %(request)s - %(message)s'

handlers:
  console:
    class: logging.StreamHandler
    formatter: precise
    stream: 'ext://sys.stdout'

loggers:
  synapse:
    handlers: [console]
    propagate: false
    level: INFO

root:
  handlers: [console]
  level: INFO
EOF

# Copy the startup script and cross-signing bootstrap
COPY start.sh /synapsechat/start.sh
COPY cross_signing_bootstrap.py /synapsechat/cross_signing_bootstrap.py
RUN chmod +x /synapsechat/start.sh

# pynacl is already installed as a Synapse dependency, but ensure psycopg2-binary for DB access
# and bcrypt for password hashing in start.sh
RUN pip install psycopg2-binary bcrypt --quiet 2>/dev/null || true

EXPOSE 8008

ENTRYPOINT ["/synapsechat/start.sh"]