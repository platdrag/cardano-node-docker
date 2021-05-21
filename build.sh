#!/bin/bash

VERSION="1.27.0"
docker build \
    --build-arg VERSION=${VERSION} \
    --tag pddev/cardano-node:${VERSION} \
    --tag pddev/cardano-node:latest .
