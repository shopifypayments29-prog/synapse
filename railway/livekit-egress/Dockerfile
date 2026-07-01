FROM livekit/egress:latest

# The livekit/egress image has its own entrypoint that:
# 1. Starts PulseAudio daemon
# 2. Runs the egress binary
# We just need to provide the config via EGRESS_CONFIG_FILE env var.
# Our start.sh generates the config and then exec's the original entrypoint.

COPY --chmod=755 start.sh /start.sh

ENTRYPOINT ["/start.sh"]