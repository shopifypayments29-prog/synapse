FROM livekit/livekit-server:latest

# Copy startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 7880 7881

ENTRYPOINT ["/start.sh"]