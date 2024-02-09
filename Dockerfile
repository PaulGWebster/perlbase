FROM gcc:13.2.0 AS base

COPY asset/src/system/apt /var/lib/apt/
COPY asset/src/system/cache /var/cache/

RUN apt install -y openssh-server \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

RUN adduser --disabled-password --gecos "" perl

USER perl

RUN ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ''
RUN cat ~/.ssh/*.pub > ~/.ssh/authorized_keys

USER root

RUN mkdir /run/sshd

FROM base AS build

# Build perl

RUN mkdir -p /build/perl
COPY asset/src/perl-5.* /build/perl

WORKDIR /build/perl

RUN ./Configure \
        -des \
        -Dprefix=/usr \
        -Duseshrplib \
        -Dusethreads \
        -Duselargefiles \
        -Duse64bitint \
        -Dusequadmath \
    && make \
    && make install \
    && rm -Rf /build/perl
 
# Build python Python-3.11.2

RUN mkdir -p /build/python
COPY asset/src/Python-* /build/python

WORKDIR /build/python

RUN ./configure \
    --enable-shared \
    --enable-optimizations \
    --prefix=/usr \
    && make -j4 \
    && make install \
    && rm -Rf /build/python

# Build cpanm

RUN mkdir -p /build/cpanm
COPY asset/src/App-cpanminus* /build/cpanm

WORKDIR /build/cpanm

RUN perl Makefile.PL \
    && make \
    && make install \
    && rm -Rf /build/cpanm  

# Build lib local

RUN mkdir -p /build/liblocal
COPY asset/src/local-lib-* /build/liblocal

WORKDIR /build/liblocal

RUN perl Makefile.PL \
    && make \
    && make install \
    && rm -Rf /build/liblocal

# Build lz4

RUN mkdir -p /build/lz4
COPY asset/src/lz4-* /build/lz4

WORKDIR /build/lz4

RUN make -j4 \
    && make \
    && make install \
    && rm -Rf /build/lz4

# Build postgresql

RUN mkdir -p /build/postgresql
COPY asset/src/postgresql-* /build/postgresql

WORKDIR /build/postgresql

RUN ./configure \
        --with-perl \
        --with-python \
        --with-lz4 \
        --with-zstd \
        --with-ssl=openssl \
        --with-libxml \
        --with-libxslt \
        --prefix=/usr \
    && make -j4 \
    && make install \
    && rm -Rf /build/postgresql

# Install Carton

RUN mkdir -p /build/carton
COPY asset/src/carton /build/carton

WORKDIR /build/carton

RUN cpanm --from "$PWD/vendor/cache" --installdeps --notest --quiet .
RUN rm -Rf /build/carton

# Clean up

RUN rm -Rf /build

FROM base AS final

# BEWARE: COPY does not preserve the user and group ownership of the files
# everything will be owned by root:root

COPY --from=build /bin /bin
COPY --from=build /etc /etc
COPY --from=build /lib /lib
COPY --from=build /usr /usr
COPY --from=build /home/perl /home/perl
RUN chown -R perl:perl /home/perl

# Strip any unneeded files
# TODO

# Copy in the entrypoint script

COPY asset/src/system/entrypoint.pl /entrypoint
RUN chmod +x /entrypoint

# Final setup

USER perl
WORKDIR /home/perl

RUN mkdir -p /home/perl/auth
COPY auth/*.pub /home/perl/auth/
RUN cat /home/perl/auth/*.pub > /home/perl/.ssh/authorized_keys \
    && chmod 600 /home/perl/.ssh/authorized_keys \
    && rm -Rf /home/perl/auth

RUN perl -MCPAN -Mlocal::lib -e 'CPAN::install(LWP)' \
    && echo 'eval "$(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)"' >>~/.bashrc

CMD ["/bin/bash"]
