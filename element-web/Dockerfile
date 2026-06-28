FROM vectorim/element-web:latest

# Cache buster — forces rebuild when config changes
ARG REBUILD=20260628

# Replace the default config with our SynapseChat config
COPY config.json /app/config.json

# Replace nginx config to serve custom pages and APK redirect
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Replace branding in index.html
RUN sed -i 's|<title>Element</title>|<title>SynapseChat</title>|g' /app/index.html && \
    sed -i 's|content="Element"|content="SynapseChat"|g' /app/index.html && \
    sed -i 's|apple-mobile-web-app-title" content="Element"|apple-mobile-web-app-title" content="SynapseChat"|g' /app/index.html && \
    sed -i 's|application-name" content="Element"|application-name" content="SynapseChat"|g' /app/index.html

# Replace the mobile guide page with our custom download page
COPY mobile_guide.html /app/mobile_guide/index.html