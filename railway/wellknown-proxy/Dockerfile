FROM nginx:alpine

# Copy main nginx config (replaces the default)
COPY nginx.conf /etc/nginx/nginx.conf

# Remove the default server block to avoid conflicts
RUN rm -f /etc/nginx/conf.d/default.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]