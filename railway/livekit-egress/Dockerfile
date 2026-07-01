FROM livekit/egress:latest

# Copy startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Egress runs on port 9090 by default for health checks
EXPOSE 9090

ENTRYPOINT ["/start.sh"]