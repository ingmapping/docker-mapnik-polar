# Perform sed substitutions for `datasource-settings.xml.inc`
s/%(dbname)s/antarctica/
s/%(password)s/mysecretpassword/
s/%(host)s/postgis/
s/%(estimate_extent)s/false/
s/%(extent)s/-200037508,-19929239,20037508,19929239/      
s/<Parameter name="\([^"]*\)">%(\([^)]*\))s<\/Parameter>/<!-- <Parameter name="\1">%(\2)s<\/Parameter> -->/
