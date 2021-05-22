from debian:stable-slim

SHELL ["/bin/bash", "-c"]

# Install build dependencies
RUN apt-get update -y \
    && apt-get install -y automake build-essential pkg-config libffi-dev libgmp-dev libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev make g++ tmux git jq wget libncursesw5 libtool autoconf libsqlite3-dev m4 ca-certificates gcc libc6-dev \
    && apt-get clean


# Install cabal
ENV PATH="/root/.cabal/bin:/root/.ghcup/bin:/root/.local/bin:$PATH"
RUN wget https://downloads.haskell.org/~cabal/cabal-install-3.2.0.0/cabal-install-3.2.0.0-x86_64-unknown-linux.tar.xz \
    && tar -xf cabal-install-3.2.0.0-x86_64-unknown-linux.tar.xz \
    && rm cabal-install-3.2.0.0-x86_64-unknown-linux.tar.xz cabal.sig \
    && mkdir -p ~/.local/bin \
    && mv cabal ~/.local/bin/ \
    && cabal update && cabal --version


# Install GHC
RUN wget https://downloads.haskell.org/ghc/8.10.2/ghc-8.10.2-x86_64-deb9-linux.tar.xz \
    && tar -xf ghc-8.10.2-x86_64-deb9-linux.tar.xz \
    && rm ghc-8.10.2-x86_64-deb9-linux.tar.xz \
    && cd ghc-8.10.2 \
    && ./configure \
    && make install \
    && cd / \
    && rm -rf /ghc-8.10.2


# Install libsodium
RUN git clone https://github.com/jedisct1/libsodium --branch stable \
    && cd libsodium \
    && ./autogen.sh \
    && ./configure \
    && make \
    && make install \
    && cd .. && rm -rf libsodium
ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH" \
    PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"

# Install cardano-node
ARG VERSION
RUN echo "Building tags/$VERSION..." \
    && echo tags/$VERSION > /CARDANO_BRANCH \
    && git clone https://github.com/input-output-hk/cardano-node.git \
    && cd cardano-node \
    && git fetch --all --recurse-submodules --tags \
    && git tag \
    && git checkout tags/$VERSION \
    && cabal configure --with-compiler=ghc-8.10.2 \
    && echo "package cardano-crypto-praos" >>  cabal.project.local \
    && echo "  flags: -external-libsodium-vrf" >>  cabal.project.local \
    && cabal build all \
    && mkdir -p /root/.local/bin/ \
    && cp -p dist-newstyle/build/x86_64-linux/ghc-8.10.2/cardano-node-${VERSION}/x/cardano-node/build/cardano-node/cardano-node /root/.local/bin/ \
    && cp -p dist-newstyle/build/x86_64-linux/ghc-8.10.2/cardano-cli-${VERSION}/x/cardano-cli/build/cardano-cli/cardano-cli /root/.local/bin/ \
    && rm -rf /root/.cabal/packages \
    && rm -rf /usr/local/lib/ghc-8.6.5/ \
    && rm -rf /cardano-node/dist-newstyle/ \ 
    && rm -rf /root/.cabal/store/ghc-8.6.5

# Install cncli
RUN git clone https://github.com/AndrewWestberg/cncli \
    && cd cncli \
    && cargo install --path . --force \
    && cncli -V

# Install tools
RUN apt-get update -y \
    && apt-get install -y vim procps dnsutils bc curl nano cron python3 python3-pip \
    && apt-get clean
RUN pip3 install pytz

# Expose ports
## cardano-node, EKG, Prometheus
EXPOSE 3000 12788 12798


# ENV variables
ENV NODE_PORT="3000" \
    NODE_NAME="node1" \
    NODE_TOPOLOGY="" \
    NODE_RELAY="False" \
    CARDANO_NETWORK="main" \
    EKG_PORT="12788" \
    PROMETHEUS_HOST="127.0.0.1" \
    PROMETHEUS_PORT="12798" \
    RESOLVE_HOSTNAMES="False" \
    REPLACE_EXISTING_CONFIG="False" \
    POOL_PLEDGE="100000000000" \
    POOL_COST="10000000000" \
    POOL_MARGIN="0.05" \
    METADATA_URL="" \
    PUBLIC_RELAY_IP="TOPOLOGY" \
    WAIT_FOR_SYNC="True" \
    AUTO_TOPOLOGY="True" \
    PATH="/root/.local/bin/:/scripts/:/scripts/functions/:/cardano-node/scripts/:${PATH}" \
    LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH}" \
    CARDANO_NODE_SOCKET_PATH="DEFAULT" \
    LANG="C.UTF-8"

# Add config
ADD cfg-templates/ /cfg-templates/
RUN mkdir -p /config/
VOLUME /config/

# Add scripts
#RUN echo "source /scripts/init_node_vars" >> /root/.bashrc
ADD scripts/ /scripts/
RUN chmod -R +x /scripts/

ENTRYPOINT ["/scripts/start-cardano-node"]