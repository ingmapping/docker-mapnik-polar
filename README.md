# docker-mapnik-polar
Generating antarctica raster tiles in polar projection with Mapnik and Docker!

Related project: [mapnik-stylesheets-polar](https://github.com/ingmapping/mapnik-stylesheets-polar/).

<img src="https://github.com/ingmapping/mapnik-stylesheets-polar/blob/master/demo.gif" width="250">

[View demo of antarctica basemap in polar projection EPSG:3031](https://tileserver.ingmapping.com/osm_antarctica/index.html)

## Introduction  

This project is part of an internship assignment which aimed at creating tiled basemaps for the KNMI geospatial infrastructure. The data and tools used to create the antarctica basemap are open-source. Therefore, this project is reproducible for everyone who wants to create simple basemaps (raster tiled basemaps) from free vector data! 

Due to the position of Antarctica around the South Pole the usual map web map projections e.g. [Web Mercator](https://epsg.io/3857) show Antarctica rather distorted. This project can help you if you want to generate raster tiles of the Antartica based on OpenStreetMap and Natural Earth data in custom polar projection ([EPSG:3031](https://epsg.io/3031)) or ([EPSG:3412](https://epsg.io/3412)) with Mapnik inside a docker container. Tiles can also be generated with Natural Earth shapefiles for the north pole in custom polar projection ([EPSG:3575](https://epsg.io/3031)) or ([EPSG:3411](https://epsg.io/3411)).

The polar basemap and corresponding style was based on the [mapnik-stylesheets-polar](https://github.com/ingmapping/mapnik-stylesheets-polar/) project in which OpenStreetMap/Natural Earth data was used to render antarctica tiles with mapnik in the [WGS 84 / Antarctic Polar Stereographic projection](https://epsg.io/3031).

This project was inspired from https://github.com/MaZderMind/mapnik-stylesheets-polar which is the development location of the Mapnik XML stylesheets powering http://polar.openstreetmap.de/. The website is not working anymore since the OSM Antarctica Map is currently unmaintained. 

The docker-mapnik-polar container is intended to be used with a postgis container like [docker-postgis](https://github.com/ingmapping/docker-postgis).

## How to set up docker-postgis for use with docker mapnik-polar

The docker-postgis image can be built by pulling the image from Docker Hub:

```
docker pull ingmapping/postgis
```
or from source:

```
docker build -t ingmapping/postgis git://github.com/ingmapping/docker-postgis
```

After buidling the postgis image, first create a network (e.g. "foo") to be able to link both containers (docker-postgis & docker-mapnik-polar): 

```
docker network create foo
```

Then, run the postgis container:

```
docker run --name postgis -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=mysecretpassword -e POSTGRES_DBNAME=antarctica -p 5432:5432 --net foo -d ingmapping/postgis
```
You might need to start the postgis container with the following command:

```
docker start postgis
```

To inspect the created network "foo":

```
docker network inspect foo
```

## How to set up docker-mapnik-polar

Can be built from the Dockerfile:

```
docker build -t ingmapping/docker-mapnik-polar github.com/ingmapping/docker-mapnik-polar.git
```

or pulled from Docker Hub:

```
docker pull ingmapping/docker-mapnik-polar
```

## How to run docker-mapnik-polar

To run the docker-mapnik-polar container, replace 'pwd' by your current working directory (the directory where you want the tiles to be exported, e.g. ~/data) and use the following command:

```
docker run -i -t --rm --name docker-mapnik-polar --net foo -v 'pwd'/:/data ingmapping/docker-mapnik-polar
```

The above command will generate antarctica tiles for zoomlevel 1 to 7 for projection ([EPSG:3412](https://epsg.io/3412)) in a folder called 'tiles-3412'. If you want to generate antarctica tiles for other zoom levels you can use the environment variables "MIN_ZOOM" and "MAX_ZOOM". For example, for zoom level 3 to 6:

```
docker run -i -t --rm --name docker-mapnik-polar --net foo -v 'pwd'/:/data -e MIN_ZOOM=3 -e MAX_ZOOM=6 -e SRS=3412 ingmapping/docker-mapnik-polar
```
If you want to generate antarctica tiles for another polar projection ([EPSG:3031](https://epsg.io/3031)), then you can use the environment variable "SRS". The following command generates antarctica tiles for zoom levels 1 to 6 in polar projection ([EPSG:3031](https://epsg.io/3031)):

```
docker run -i -t --rm --name docker-mapnik-polar --net foo -v 'pwd'/:/data -e MAX_ZOOM=6 -e SRS=3031 ingmapping/docker-mapnik-polar
```

If you want to generate tiles for the northpole, with custom polar projection ([EPSG:3575](https://epsg.io/3031)) or ([EPSG:3411](https://epsg.io/3411)), then you can use the environment variable "STYLESHEET". Linking the container to postgis is not needed since only shapefiles are used for the northpole style. You may ignore the errors for postgis. The following command generates north pole tiles for zoom levels 1 to 6 in polar projection ([EPSG:3411](https://epsg.io/3411)):

```
docker run -i -t --rm --name docker-mapnik-polar -v 'pwd'/:/data -e MAX_ZOOM=6 -e STYLESHEET=northpole -e SRS=3411 ingmapping/docker-mapnik-polar
```

## How to remove your exported tiles when having permission problems: 

If the tiles are created by root inside the Docker container it can cause problems when you want to remove your tiles locally on the host with a non-root user. A solution how to remove the files is to run another docker container and remove the files as root again:

```
docker run -it --rm -v 'pwd'/:/mnt:z phusion/baseimage bash 
cd mnt 
rm -rf tiles-3412
exit
```

## How to use/view your generated polar tiles

Once that you have your tiles exported in a folder directory structure, you can use/view the generated raster tiles using various JavaScript mapping libraries. OpenLayers can handle custom projections out of the box, and Leaflet with the [Proj4Leafletplugin](https://kartena.github.io/Proj4Leaflet/). For configuration settings for the viewer see: [polar_projections.txt](https://github.com/ingmapping/docker-mapnik-polar/blob/master/polar_projections.txt)

[OpenLayers demo viewer of antarctica basemap in polar projection EPSG:3031](https://tileserver.ingmapping.com/osm_antarctica/index.html)
