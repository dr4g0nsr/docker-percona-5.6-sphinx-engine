FROM ubuntu:16.04

ENV BUILD_PERCONA_VERSION 5.6
ENV BUILD_PERCONA_VERSION_FULL 5.6.17-66.0
ENV BUILD_SPHINX_VERSION 2.1.6

MAINTAINER Dragutin Cirkovic (dragonmen@gmail.com)

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r mysql && useradd -r -g mysql mysql

# add gosu for easy step-down from root
ENV GOSU_VERSION 1.7

RUN set -x \
	&& apt-get update && apt-get install -y --no-install-recommends ca-certificates wget && rm -rf /var/lib/apt/lists/* \
	&& wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
	&& wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
	&& gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
	&& rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
	&& chmod +x /usr/local/bin/gosu \
	&& gosu nobody true \
	&& apt-get purge -y --auto-remove ca-certificates wget

RUN mkdir /docker-entrypoint-initdb.d

RUN mkdir /usr/src/percona-$BUILD_PERCONA_VERSION

COPY percona-build.sh /usr/src/percona-$BUILD_PERCONA_VERSION/percona-build.sh
COPY percona-build1.sh /usr/src/percona-$BUILD_PERCONA_VERSION/percona-build1.sh
COPY percona-build2.sh /usr/src/percona-$BUILD_PERCONA_VERSION/percona-build2.sh
COPY percona-build3.sh /usr/src/percona-$BUILD_PERCONA_VERSION/percona-build3.sh
COPY percona-build4.sh /usr/src/percona-$BUILD_PERCONA_VERSION/percona-build4.sh

RUN apt update && apt install -y wget build-essential cmake libaio-dev libncurses5-dev libwrap0-dev libreadline-dev ruby-dev sudo nano mytop

RUN cd /usr/src/percona-$BUILD_PERCONA_VERSION/ && ./percona-build1.sh -s $BUILD_SPHINX_VERSION -p $BUILD_PERCONA_VERSION_FULL -d $BUILD_PERCONA_VERSION_FULL -o ubuntu
RUN cd /usr/src/percona-$BUILD_PERCONA_VERSION/ && ./percona-build2.sh -s $BUILD_SPHINX_VERSION -p $BUILD_PERCONA_VERSION_FULL -d $BUILD_PERCONA_VERSION_FULL -o ubuntu
RUN cd /usr/src/percona-$BUILD_PERCONA_VERSION/ && ./percona-build3.sh -s $BUILD_SPHINX_VERSION -p $BUILD_PERCONA_VERSION_FULL -d $BUILD_PERCONA_VERSION_FULL -o ubuntu
RUN cd /usr/src/percona-$BUILD_PERCONA_VERSION/ && ./percona-build4.sh -s $BUILD_SPHINX_VERSION -p $BUILD_PERCONA_VERSION_FULL -d $BUILD_PERCONA_VERSION_FULL -o ubuntu

VOLUME /usr/local/mysql/data
VOLUME /etc/mysql/mysql.conf.d

RUN apt install tzdata pwgen

COPY docker-entrypoint.sh /usr/local/bin/
RUN ln -s /usr/local/bin/docker-entrypoint.sh /entrypoint.sh # backwards compat

RUN cd /usr/bin \
	&& ln -s /usr/local/mysql/bin/mysqld \
	&& ln -s /usr/local/mysql/scripts/mysql_install_db \
	&& ln -s /usr/local/mysql/bin/mysql \
	&& ln -s /usr/local/mysql/bin/mysql_tzinfo_to_sql

RUN mkdir -p /var/run/mysqld
RUN chown mysql:mysql /var/run/mysqld

# default docker conf
COPY docker.cnf /etc/mysql/conf.d/docker.cnf

#RUN sed -i "s/.*bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf

ENV MYSQL_ROOT_PASSWORD root
ENV MYSQL_ALLOW_EMPTY_PASSWORD ""
ENV MYSQL_RANDOM_ROOT_PASSWORD ""
ENV MYSQL_ROOT_HOST "%"

EXPOSE 3306

ENTRYPOINT ["docker-entrypoint.sh"]

#CMD ["bash"]
#CMD ["/usr/local/mysql/bin/mysqld"]
CMD ["mysqld"]