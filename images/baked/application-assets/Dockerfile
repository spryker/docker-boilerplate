# syntax = docker/dockerfile:experimental
ARG SPRYKER_PARENT_IMAGE
ARG SPRYKER_ASSETS_BUILDER_IMAGE

FROM ${SPRYKER_ASSETS_BUILDER_IMAGE} as assets-builder
FROM ${SPRYKER_PARENT_IMAGE} as application-assets

COPY --from=assets-builder --chown=root:root /data/public ${srcRoot}/public
