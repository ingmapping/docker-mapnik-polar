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

# Loading OSM data
if [ ! -f /data/${PBFFile} ]; then
    echo "[MISSING] /data/${PBFFile} file not found! Downloading file"
    wget http://download.geofabrik.de/${PBFFile} -O /data/${PBFFile}   
else
    echo "[OK] /data/${PBFFile} file"
fi

     echo "Loading data into antarctica database if not already done"
     osm2pgsql -U ${PGUSER} -H ${PGHOST} -d antarctica --create --slim --latlong --prefix ant -C 2000 --number-processes 3 -S /root/src/mapnik-stylesheets-polar/osm2pgsql.style -r .pbf /data/${PBFFile} 

# Mapnik generate polar tiles settings
export MAPNIK_MAP_FILE=/root/src/mapnik-stylesheets-polar/osm-antarctica-${SRS}.xml
export MAPNIK_TILE_DIR=/data/tiles-${SRS}
mkdir -p ${MAPNIK_TILE_DIR}
chmod -R 777 ${MAPNIK_TILE_DIR}

# Copying viewer to data folder 
echo "`date +"%Y-%m-%d %H:%M:%S"` Copying OpenLayers viewer to data/tiles folder"
cp /root/src/mapnik-stylesheets-polar/view-${SRS}.html /data/tiles-${SRS}

# Generate polar tiles 
echo "`date +"%Y-%m-%d %H:%M:%S"` Generating polar tiles in data/tiles folder"
python /root/src/mapnik-stylesheets-polar/render-polar-tiles-${SRS}.py --style=/root/src/mapnik-stylesheets-polar/osm-antarctica-${SRS}.xml --dir=${MAPNIK_TILE_DIR} --minzoom=${MIN_ZOOM} --maxzoom=${MAX_ZOOM}


