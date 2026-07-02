FROM livekit/livekit-server:latest AS livekit

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash ca-certificates haproxy iptables \
    && rm -rf /var/lib/apt/lists/*

COPY --from=livekit /livekit-server /usr/local/bin/livekit-server

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 7880 7881

ENTRYPOINT ["/start.sh"]