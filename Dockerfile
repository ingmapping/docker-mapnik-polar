FROM ubuntu:16.04
MAINTAINER ingmapping <contact@ingmapping.com>

# Ensure `add-apt-repository` is present
RUN apt-get update -y \
    && apt-get install -y software-properties-common python-software-properties

# Install dependencies 
RUN apt-get update -y \
    && apt-get install -y libboost-all-dev git-core tar unzip wget bzip2 build-essential autoconf libtool libxml2-dev libgeos-dev libgeos++-dev libpq-dev libbz2-dev libproj-dev munin-node munin libprotobuf-c0-dev protobuf-c-compiler libfreetype6-dev libpng12-dev libtiff5-dev libicu-dev libgdal-dev libcairo-dev libcairomm-1.0-dev apache2 apache2-dev libagg-dev liblua5.2-dev ttf-unifont lua5.1 liblua5.1-dev libgeotiff-epsg postgresql-client-9.5

# Install osm2psql
RUN apt-get update -y \
    && apt-get install -y make cmake g++ libboost-dev libboost-system-dev libboost-filesystem-dev libexpat1-dev zlib1g-dev libbz2-dev libpq-dev libgeos-dev libgeos++-dev libproj-dev lua5.2 liblua5.2-dev

RUN mkdir ~/src \
    && cd ~/src \
    && git clone git://github.com/openstreetmap/osm2pgsql.git \
    && cd osm2pgsql \
    && mkdir build && cd build \
    && cmake .. \
    && make \
    && make install 

# Install mapnik library
RUN apt-get install -y autoconf apache2-dev libtool libxml2-dev libbz2-dev libgeos-dev libgeos++-dev libproj-dev gdal-bin libgdal1-dev libmapnik-dev mapnik-utils python-mapnik

# Verify that Mapnik has been installed correctly
RUN python -c 'import mapnik'  

# Install mapnik-stylesheets-polar and additional shapefiles 
RUN cd ~/src \
    && git clone git://github.com/ingmapping/mapnik-stylesheets-polar.git \
    && cd mapnik-stylesheets-polar/data \
    && wget http://data.openstreetmapdata.com/land-polygons-complete-4326.zip \
    && wget http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/10m/cultural/ne_10m_populated_places.zip \
    && wget http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/110m/cultural/ne_110m_admin_0_boundary_lines_land.zip \
    && unzip land-polygons-complete-4326.zip \
    && unzip ne_10m_populated_places.zip \
    && unzip ne_110m_admin_0_boundary_lines_land.zip \
    && find \( -type f -iname "*.zip" -o -iname "*.tgz" \) -delete
    
# Configure mapnik-stylesheets-polar
RUN cd ~/src/mapnik-stylesheets-polar/inc && cp fontset-settings.xml.inc.template fontset-settings.xml.inc
ADD datasource-settings.sed /tmp/
RUN cd ~/src/mapnik-stylesheets-polar/inc && sed --file /tmp/datasource-settings.sed  datasource-settings.xml.inc.template > datasource-settings.xml.inc
ADD settings.sed /tmp/
RUN cd ~/src/mapnik-stylesheets-polar/inc && sed --file /tmp/settings.sed settings.xml.inc.template > settings.xml.inc       
    
# Make local directory for loading OSM data -- this is the place where osm.pbf file should be downloaded to    
RUN mkdir /data
VOLUME /data

# Install necessary fonts for the mapnik-polar style
RUN apt-get install -y ttf-unifont ttf-dejavu

# Entrypoint and instructions for loading OSM data into postgis database
COPY ./docker-entrypoint.sh /docker-entrypoint.sh 
RUN chmod a+rx /docker-entrypoint.sh 

COPY ./osm-antarctica-3031.xml /root/src/mapnik-stylesheets-polar/osm-antarctica-3031.xml
COPY ./osm-antarctica-3412.xml /root/src/mapnik-stylesheets-polar/osm-antarctica-3412.xml
COPY ./render-polar-tiles-3031.py /root/src/mapnik-stylesheets-polar/render-polar-tiles-3031.py
COPY ./render-polar-tiles-3412.py /root/src/mapnik-stylesheets-polar/render-polar-tiles-3412.py
COPY ./render-polar-tiles-3411.py /root/src/mapnik-stylesheets-polar/render-polar-tiles-3411.py
COPY ./render-polar-tiles-3575.py /root/src/mapnik-stylesheets-polar/render-polar-tiles-3575.py
COPY ./view-3031.html /root/src/mapnik-stylesheets-polar/view-3031.html
COPY ./view-3412.html /root/src/mapnik-stylesheets-polar/view-3412.html
COPY ./view-3411.html /root/src/mapnik-stylesheets-polar/view-3411.html
COPY ./view-3575.html /root/src/mapnik-stylesheets-polar/view-3575.html

ENV PGPASSWORD=mysecretpassword 
ENV PGUSER=postgres
ENV PGHOST=postgis

ENV PBFFile=antarctica-latest.osm.pbf
ENV MIN_ZOOM=0
ENV MAX_ZOOM=7
ENV SRS=3412
ENV STYLESHEET=osm-antarctica 

ENTRYPOINT /docker-entrypoint.sh





