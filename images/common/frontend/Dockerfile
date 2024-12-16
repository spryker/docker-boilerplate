# syntax = docker/dockerfile:experimental
# For brotli support you can use something like fholzer/nginx-brotli:v1.18.0
ARG SPRYKER_FRONTEND_IMAGE=nginx:alpine

FROM ${SPRYKER_FRONTEND_IMAGE} as frontend-basic

RUN mkdir -p /etc/nginx/template/ && chmod 0777 /etc/nginx/template/
COPY --chown=root:root nginx/nginx.original.conf /etc/nginx/nginx.conf
COPY --chown=root:root nginx/conf.d/frontend.default.conf.tmpl /etc/nginx/template/default.conf.tmpl
COPY --chown=root:root nginx/conf.d/resolver.conf.tmpl /etc/nginx/template/resolver.conf.tmpl
COPY --chown=root:root nginx/conf.d/stub.default.conf.tmpl /etc/nginx/conf.d/stub.conf
COPY --chown=root:root nginx/auth /etc/nginx/auth
COPY --chown=root:root nginx/entrypoint.sh /
RUN chmod +x /entrypoint.sh

ENV SPRYKER_DNS_RESOLVER_FLAGS="valid=10s ipv6=off"
ENV SPRYKER_DNS_RESOLVER_IP=""

ARG SPRYKER_MAINTENANCE_MODE_ENABLED
ENV SPRYKER_MAINTENANCE_MODE_ENABLED=${SPRYKER_MAINTENANCE_MODE_ENABLED}

# Build info
ARG SPRYKER_BUILD_HASH='current'
ENV SPRYKER_BUILD_HASH=${SPRYKER_BUILD_HASH}
ARG SPRYKER_BUILD_STAMP=''
ENV SPRYKER_BUILD_STAMP=${SPRYKER_BUILD_STAMP}
COPY --chown=root:root nginx/build.json /tmp/build.json
RUN mkdir -p /usr/share/nginx/ \
  && envsubst '${SPRYKER_BUILD_HASH} ${SPRYKER_BUILD_STAMP}' < /tmp/build.json > /usr/share/nginx/build.json \
  && rm -f /tmp/build.json

ENTRYPOINT [ "/entrypoint.sh" ]

CMD ["nginx", "-g", "daemon off;"]
