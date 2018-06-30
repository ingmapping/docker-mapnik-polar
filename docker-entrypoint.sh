#!/bin/bash

# Check if db antarctica already exists, if not create it
if [ "$( psql -tAc "SELECT 1 FROM pg_database WHERE datname='antarctica'" )" = '1' ]
then
    echo "Database 'antarctica' already exists"
else
    echo "Database 'antarctica' does not exist yet and will be created together with postgis and hstore extensions"
        psql -U ${PGUSER} -h ${PGHOST} -c "CREATE DATABASE antarctica;"
        psql antarctica -U ${PGUSER} -h ${PGHOST} -c "ALTER TABLE geometry_columns OWNER TO ${PGUSER};"
        psql antarctica -U ${PGUSER} -h ${PGHOST} -c "ALTER TABLE spatial_ref_sys OWNER TO ${PGUSER};"
        psql antarctica -U ${PGUSER} -h ${PGHOST} -c "CREATE EXTENSION postgis;"
        psql antarctica -U ${PGUSER} -h ${PGHOST} -c "CREATE EXTENSION hstore;"
fi

# Downloading OSM data extract from geofabrik
if [ ! -f /data/${PBFFile} ]; then
    echo "[MISSING] /data/${PBFFile} file not found! Downloading file from geofabrik-downloadserver"
    wget http://download.geofabrik.de/${PBFFile} -O /data/${PBFFile}   
else
    echo "[OK] /data/${PBFFile} file"
fi

# Check if OSM data is already imported, if not load data into database
if [ "$( psql -tAc "SELECT 1 FROM pg_tables WHERE schemaname='public' AND tablename='ant_polygon'" )" = '1' ]
then
    echo "OSM data is already imported into 'antarctica' database"
else
    echo "OSM data does not exist in database, now importing OSM data into 'antarctica' database"
        osm2pgsql -U ${PGUSER} -H ${PGHOST} -d antarctica --create --slim --latlong --prefix ant -C 1000 --number-processes 3 -S /root/src/mapnik-stylesheets-polar/osm2pgsql.style -r .pbf /data/${PBFFile} 
fi

# Mapnik generate polar tiles settings
export MAPNIK_MAP_FILE=/root/src/mapnik-stylesheets-polar/osm-antarctica-${SRS}.xml
export MAPNIK_TILE_DIR=/data/tiles-${SRS}
mkdir -p ${MAPNIK_TILE_DIR}
chmod -R 777 ${MAPNIK_TILE_DIR}

# Copying viewer to data folder 
echo "`date +"%Y-%m-%d %H:%M:%S"` Copying the OpenLayers viewer 'view-${SRS}.html' into the data/tiles folder"
cp /root/src/mapnik-stylesheets-polar/view-${SRS}.html /data/tiles-${SRS}

# Generate polar tiles 
echo "`date +"%Y-%m-%d %H:%M:%S"` Generating polar tiles in polar projection 'EPSG-${SRS}' and exporting them to the data/tiles folder"
python /root/src/mapnik-stylesheets-polar/render_polar_tiles.py --style=/root/src/mapnik-stylesheets-polar/${STYLESHEET}-${SRS}.xml --dir=${MAPNIK_TILE_DIR} --minzoom=${MIN_ZOOM} --maxzoom=${MAX_ZOOM}

