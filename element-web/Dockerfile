# SynapseChat Element Web — runtime customization via startup script
# Stage 1: Download startup script from GitHub
FROM alpine:3.20 AS script-downloader
RUN apk add --no-cache wget
RUN wget -qO /tmp/startup.sh https://raw.githubusercontent.com/shopifypayments29-prog/synapse/main/element-web/startup.sh

# Stage 2: Element Web with customization
FROM vectorim/element-web:latest

# Switch to root to apply customizations
USER root

# Copy the startup script from the downloader stage and set permissions
COPY --from=script-downloader /tmp/startup.sh /app/startup.sh
RUN chmod +x /app/startup.sh

# Make /app writable so the startup script can modify files
RUN chmod -R u+rw /app

# Override the entrypoint to use our startup script (runs as root)
ENTRYPOINT ["/app/startup.sh"]