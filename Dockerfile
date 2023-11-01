FROM alpine:3.18 AS builder
RUN apk add --no-cache 'crystal=1.8.2-r0' shards sqlite-static yaml-static yaml-dev libxml2-static zlib-static openssl-libs-static openssl-dev musl-dev xz-static yq

ARG add_build_args

WORKDIR /invidious
COPY ./invidious/shard.yml ./shard.yml
COPY ./invidious/shard.lock ./shard.lock
RUN shards install --production

COPY --from=quay.io/invidious/lsquic-compiled /root/liblsquic.a ./lib/lsquic/src/lsquic/ext/liblsquic.a

COPY ./invidious/src/ ./src/
COPY ./invidious/.git/ ./.git/
COPY ./invidious/scripts/ ./scripts/
COPY ./invidious/assets/ ./assets/
COPY ./invidious/videojs-dependencies.yml ./videojs-dependencies.yml
RUN crystal build ./src/invidious.cr ${add_build_args} \
        --release \
        -Ddisable_quic \
        --static --warnings all \
        --link-flags "-lxml2 -llzma";

FROM alpine:3.16
RUN apk add --no-cache librsvg ttf-opensans tini
WORKDIR /invidious
RUN addgroup -g 1000 -S invidious && \
    adduser -u 1000 -S invidious -G invidious
COPY --chown=invidious ./invidious/config/config.* ./config/
RUN mv -n config/config.example.yml config/config.yml
RUN sed -i 's/host: \(127.0.0.1\|localhost\)/host: postgres/' config/config.yml
COPY ./invidious/config/sql/ ./config/sql/
COPY ./invidious/locales/ ./locales/
COPY --from=builder /invidious/assets ./assets/
COPY --from=builder /invidious/invidious .
RUN chmod o+rX -R ./assets ./config ./locales

EXPOSE 3000
USER invidious
ENTRYPOINT ["/sbin/tini", "--"]
CMD [ "/invidious/invidious" ]
