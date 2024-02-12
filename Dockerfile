FROM gcc:13.2.0 AS base

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
    && make -j4 \
    && make install \
    && rm -rf /build/perl
 
# Build Python-3.11.2
RUN mkdir -p /build/python
COPY asset/src/Python-* /build/python

WORKDIR /build/python

RUN ./configure \
    --enable-shared \
    --enable-optimizations \
    --prefix=/usr \
    && make -j4 \
    && make install \
    && rm -rf /build/python

# Build cpanm
RUN mkdir -p /build/cpanm
COPY asset/src/App-cpanminus* /build/cpanm

WORKDIR /build/cpanm

RUN perl Makefile.PL \
    && make \
    && make install \
    && rm -rf /build/cpanm  

# Build lib local
RUN mkdir -p /build/liblocal
COPY asset/src/local-lib-* /build/liblocal

WORKDIR /build/liblocal

RUN perl Makefile.PL \
    && make \
    && make install \
    && rm -rf /build/liblocal

# Build lz4
RUN mkdir -p /build/lz4
COPY asset/src/lz4-* /build/lz4

WORKDIR /build/lz4

RUN make -j4 \
    && make \
    && make install \
    && rm -rf /build/lz4

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
    && rm -rf /build/postgresql

# Install Carton
RUN mkdir -p /build/carton
COPY asset/src/carton /build/carton

WORKDIR /build/carton

RUN cpanm --from "$PWD/vendor/cache" --installdeps --notest --quiet .
RUN rm -rf /build/carton

# Clean up
RUN rm -rf /build

FROM base AS config

# BEWARE: COPY does not preserve the user and group ownership of the files
# everything will be owned by root:root
COPY --from=build /bin /bin
COPY --from=build /etc /etc
COPY --from=build /lib /lib
COPY --from=build /usr /usr

# TODO
# Strip any unneeded files

# Final setup
ENV PERL5LIB=/usr/share/perl5:$PERL5LIB
RUN adduser --disabled-password --gecos "" perl

USER perl
WORKDIR /home/perl

RUN ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N '' \
    && cat ~/.ssh/*.pub > ~/.ssh/authorized_keys

RUN mkdir -p /home/perl/auth
COPY auth/*.pub /home/perl/auth/
RUN cat /home/perl/auth/*.pub > /home/perl/.ssh/authorized_keys \
    && chmod 600 /home/perl/.ssh/authorized_keys \
    && rm -rf /home/perl/auth

RUN echo 'eval "$(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)"' >> ~/.bashrc

USER root

COPY asset/src/system/motd /etc/motd
COPY asset/src/system/apt /var/lib/apt/
COPY asset/src/system/cache /var/cache/

RUN apt-get install -y \
    /var/cache/apt/archives/locales_* \
    /var/cache/apt/archives/openssh-server_* \
    /var/cache/apt/archives/gosu_*

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen \
    && echo "C UTF-8" >> /etc/locale.gen \
    && locale-gen

ENV LANG=en_US.UTF-8  
ENV LANGUAGE=en_US:en  
ENV LC_ALL=en_US.UTF-8

# Copy in the system support scripts
COPY asset/src/system/entrypoint.pl /entrypoint
RUN chmod +x /entrypoint
COPY asset/src/system/nocmd.pl /nocmd
RUN chmod +x /nocmd

# Remove the ability to login with passwords at all
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

FROM config AS postgresql

COPY asset/src/system/postgresql.conf /usr/local/etc/postgresql.conf
COPY asset/src/system/bin/* /usr/local/bin/

ENV PGDATA /var/lib/postgresql/data

RUN groupadd -r postgres; \
    PGGROUP=$(getent group postgres | cut -d: -f3); \
    useradd -r -g postgres --uid=$PGGROUP --home-dir=/var/lib/postgresql --shell=/bin/bash postgres; \
    mkdir -p /var/lib/postgresql /docker-entrypoint-initdb.d "$PGDATA"; \
    chown -R postgres:postgres /var/lib/postgresql; \
    chown -R postgres:postgres /docker-entrypoint-initdb.d; \
    chown -R postgres:postgres "$PGDATA"; \
    chmod 1777 "$PGDATA"

COPY asset/src/system/start-postgres.sh /start-postgres
RUN chmod +x /start-postgres

CMD ["/entrypoint"]
