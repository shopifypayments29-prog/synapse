FROM coturn/coturn:latest

# Copy startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 3478 5349 49152-65535/udp 49152-65535/tcp

CMD ["/start.sh"]