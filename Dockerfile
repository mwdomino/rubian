FROM mwdomino/rubian-base

RUN mkdir -p /tmp/ruby-build
WORKDIR /tmp/ruby-build

ARG MINOR_VERSION
ARG MAJOR_VERSION

RUN wget https://cache.ruby-lang.org/pub/ruby/$MAJOR_VERSION/ruby-$MINOR_VERSION.tar.gz
RUN tar xvzf ruby-$MINOR_VERSION.tar.gz

WORKDIR /tmp/ruby-build/ruby-$MINOR_VERSION
RUN sh -c './configure --disable-install-doc'
RUN make && \
    make install && \
    rm -rf /tmp/ruby-build
