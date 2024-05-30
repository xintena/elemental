FROM busybox

ARG CHANNEL_JSON_FILE

COPY channels/$CHANNEL_JSON_FILE /channel.json

USER 10010:10010

ENTRYPOINT ["cp"]
CMD ["/channel.json", "/data/output"]
