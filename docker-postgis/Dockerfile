FROM postgres:9.5
MAINTAINER ingmapping <contact@ingmapping.com>

ENV POSTGIS_MAJOR 2.4                     
ENV POSTGIS_VERSION 2.4.4+dfsg-4.pgdg14.04+1 

RUN apt-get update -y \
      && apt-get install -y --no-install-recommends \
           postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR \
           postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR-scripts \
           postgis-2.4 \
      && rm -rf /var/lib/apt/lists/*
        
RUN mkdir -p /docker-entrypoint-initdb.d
COPY ./initdb-postgis.sh /docker-entrypoint-initdb.d/postgis.sh

EXPOSE 5432
