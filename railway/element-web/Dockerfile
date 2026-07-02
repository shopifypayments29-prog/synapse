# SynapseChat Element Web — runtime customization via startup script
# ARG cache-bust forces Docker to re-run all layers below when the arg value changes
ARG CACHE_BUST=13

FROM vectorim/element-web:v1.12.23-rc.0

# Switch to root to apply customizations
USER root

# Copy the startup script and version.json from local context
COPY startup.sh /app/startup.sh
COPY version.json /app/version.json
RUN chmod +x /app/startup.sh

# Make /app writable so the startup script can modify files at runtime
RUN chmod -R u+rw /app

# Override the entrypoint to use our startup script (runs as root)
ENTRYPOINT ["/app/startup.sh"]