FROM debian:buster

RUN apt update && \
    apt upgrade -y && \
    apt install --no-install-recommends -y \
    wget \
    gcc \
    make \
    automake \
    git \
    libssl-dev \
    libreadline-dev \
    zlib1g-dev

# Clean Cache and such here
RUN mkdir -p /tmp/ruby-build
WORKDIR /tmp/ruby-build
ARG MINOR_VERSION
ARG MAJOR_VERSION

RUN wget https://cache.ruby-lang.org/pub/ruby/$MAJOR_VERSION/ruby-$MINOR_VERSION.tar.gz
RUN tar xvzf ruby-$MINOR_VERSION.tar.gz

WORKDIR /tmp/ruby-build/ruby-$MINOR_VERSION
RUN sh -c './configure'
RUN make && \
    make install

# Remove build folder and apt cache
RUN rm -rf /tmp/ruby-build && \
    rm -rf /var/lib/apt/lists/*
