FROM busybox

ARG CHANNEL_JSON_FILE

COPY channels/$CHANNEL_JSON_FILE /channel.json

ENTRYPOINT ["cp"]
CMD ["/channel.json", "/data/output"]
