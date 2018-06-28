# docker-postgis
Dockerfile for PostGIS 

This postgis docker container is based on the [official postgres docker image](https://hub.docker.com/_/postgres/) version 9.5. It creates a template database 'template_postgis' owned by user 'postgres' and installs the extensions of postgis, fuzzystrmatch, postgis_tiger_geocoder and hstore. 

## docker-postgis set up image 

How to build the image:

```
docker build -t ingmapping/postgis git://github.com/ingmapping/docker-postgis
```
or 

```
docker pull ingmapping/postgis
```
## docker-postgis run

How to run the container:

```
docker run --name="docker-postgis" -p 5432:5432 -d -t ingmapping/postgis
```
To store data on the host rather than the container, you can mount your created import directory using -v argument:

```
mkdir -p /data/import
docker run --name="docker-postgis" -p 5432:5432 -v /path/to/desired/import/data:/data/import -d -t ingmapping/postgis
```
You need to ensure the data import directory has sufficient read/write permissions.

Furthermore, you can use environment variables such as "-e POSTGRES_PASSWORD=password" or "-e POSTGRES_USER=user" to set a password or username, e.g:

```
docker run --name="docker-postgis" -p 5432:5432 -e POSTGRES_PASSWORD=password -e POSTGRES_USER=user -v /path/to/desired/import/data:/data/import -d -t ingmapping/postgis
```


