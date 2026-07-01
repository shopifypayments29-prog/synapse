FROM node:22-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y git python3 make g++ && rm -rf /var/lib/apt/lists/*

# Enable corepack for pnpm
RUN corepack enable

WORKDIR /app

# Clone Element Call from source
RUN git clone https://github.com/element-hq/element-call.git .

# Install dependencies and build
RUN pnpm install --frozen-lockfile || pnpm install
RUN pnpm build

# Production stage — serve static files with nginx
FROM nginx:alpine

# Copy built files from builder
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy our config
COPY config.json /usr/share/nginx/html/config.json

# Copy nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]