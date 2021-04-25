FROM debian:buster

RUN apt update && \
    apt upgrade -y && \
    apt install --no-install-recommends -y \
    automake \
    ca-certificates \
    gcc \
    git \
    libssl-dev \
    libreadline-dev \
    make \
    wget \
    zlib1g-dev

RUN rm -rf /var/lib/apt/lists/*
