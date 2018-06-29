#!/usr/bin/python
#
# render data from postgresql to an tiles in an polar projection
#

from optparse import OptionParser
import sys, os, multiprocessing
import Queue

try:
    import mapnik
except:
    import mapnik2 as mapnik

cairo_exists = True

try:
    import cairo
except ImportError:
    cairo_exists = False

    SRS = int(os.environ['SRS'])

    SRS = os.getenv("SRS")
    p={"3031":{"scale":6000000},"3412":{"scale":6000000},"3575":{"scale":10000000},"3411":{"scale":24800000}}


def main():
    style = os.path.dirname(os.path.abspath(__file__))+"/osm.xml"
    dir = "tiles"
    type = "png"
    scale = p[SRS]["scale"]
    minzoom = 1
    maxzoom = 6
    threads = 1
    context = 3

    parser = OptionParser()
    parser.add_option("-s", "--style", action="store", type="string", dest="style", 
                      help="path to the mapnik stylesheet xml, defaults to: "+style)
    
    parser.add_option("-d", "--dir", action="store", type="string", dest="dir", 
                      help="path to the destination folder, defaults to "+type)
    
    parser.add_option("-t", "--type", action="store", type="string", dest="type", 
                      help="file type to render (png, png256, jpg), defaults to "+type)
    
    parser.add_option("-z", "--minzoom", action="store", type="int", dest="minzoom", 
                      help="minimum zoom level to render, defaults to "+str(minzoom))
    
    parser.add_option("-Z", "--maxzoom", action="store", type="int", dest="maxzoom", 
                      help="maximum zoom level to render, defaults to "+str(maxzoom))
    
    parser.add_option("-T", "--threads", action="store", type="int", dest="threads", 
                      help="number of threads to launch, defaults to "+str(threads))

    parser.add_option("-i", "--only-interesting", action="store_true", dest="onlyinteresting", 
                      help="only render around interesting places (buildings, peaks, islands, ...)")

    parser.add_option("-c", "--only-interesting-context", action="store", type="int", dest="context",
                      help="when rendering tiles around interesting places, how many tiles around those places should be rendered?"+
                      "0 means that only the tile with the interesting feature will be rendered; "+
                      "1 means that the 8 surrounding tiles will be rendered for each zoom level, too; "+
                      "2 adds 24 extra tiles; 3 adds 48 extra tiles; 4 adds 80 extra tiles; "+
                      "defaults to "+str(context)+", which should fill the most screens")

    parser.add_option("-l", "--only-interesting-list", action="store", type="string", dest="listfile", 
                      help="write a GeoJSON-List of interesting places")

    parser.add_option("-D", "--db", action="store", type="string", dest="dsn", default="", 
                      help="database connection string used for finding interesting places")
    
    parser.add_option("-e", "--skip-existing", action="store_true", dest="skipexisting", 
                      help="skip existing tiles, only render missing")
    
    (options, args) = parser.parse_args()
    if options.style:
        style = options.style
    
    if options.dir:
        dir = options.dir
    
    if options.type:
        type = options.type
    
    if options.minzoom:
        minzoom = options.minzoom
    
    if options.maxzoom:
        maxzoom = options.maxzoom

    if options.threads:
        threads = options.threads

    if options.context != None:
        context = options.context
    
    queue = multiprocessing.JoinableQueue(32)
    lock = multiprocessing.Lock()

    renderers = {}
    print "Starting %u render-threads" % (threads)
    for i in range(threads):
        renderer = RenderThread(i, queue, style, scale, dir, type, lock)
        render_thread = multiprocessing.Process(target=renderer.run)
        render_thread.start()
        renderers[i] = render_thread

    if options.onlyinteresting:
        import psycopg2
        tileset = set()
        features = []
        con = psycopg2.connect(options.dsn)
        sql = """
        SELECT 'point' AS type, osm_id, name, ST_X(way), ST_Y(way), ST_X(ST_Transform(way, SRS)), ST_Y(ST_Transform(way, SRS)) FROM ant_point
            WHERE (place IS NOT NULL AND place IN ('hamlet', 'town', 'isolated_dwelling', 'cape', 'locality', 'island', 'islet'))
            OR building IS NOT NULL
            OR aeroway IS NOT NULL
            OR ("natural" IS NOT NULL AND "natural" IN ('volcano', 'ridge', 'cliff', 'cape', 'peak', 'valley', 'bay'))

        UNION  ALL

        SELECT 'line' AS type, osm_id, name, ST_X(ST_Centroid(way)), ST_Y(ST_Centroid(way)), ST_X(ST_Transform(ST_Centroid(way), SRS)), ST_Y(ST_Transform(ST_Centroid(way), SRS)) FROM ant_line
            WHERE (place IS NOT NULL AND place IN ('hamlet', 'town', 'isolated_dwelling', 'cape', 'locality', 'island', 'islet'))
            OR building IS NOT NULL
            OR aeroway IS NOT NULL

        UNION  ALL

        SELECT 'polygon' AS type, osm_id, name, ST_X(ST_Centroid(way)), ST_Y(ST_Centroid(way)), ST_X(ST_Transform(ST_Centroid(way), SRS)), ST_Y(ST_Transform(ST_Centroid(way), SRS)) FROM ant_polygon
            WHERE (name IS NOT NULL AND place IS NOT NULL AND place IN ('hamlet', 'town', 'isolated_dwelling', 'cape', 'locality', 'island', 'islet'))
            OR building IS NOT NULL
            OR aeroway IS NOT NULL;
        """;
        cur = con.cursor()
        cur.execute(sql)
        lock.acquire()
        print "found %u interesting nodes" % (cur.rowcount)
        lock.release()
        i = 0
        for record in cur:
            (obj_type, osm_id, name, lat, lng, xmeter, ymeter) = record
            lock.acquire()
            i += 1
            print "found interesting %s %u of %u: #%u (%s)" % (obj_type, i, cur.rowcount, osm_id, name)
            lock.release()
            if(options.listfile):
                features += ({
                    "type": "Feature",
                    "properties": {
                        "osm_id": osm_id,
                        "name": name
                    },
                    "geometry": {
                        "type": "Point",
                        "coordinates" : [ lat, lng ] 
                    }
                },)

            for z in range(minzoom, maxzoom+1):
                n = 2**z
                n2 = n/2
                tilesz = float(scale) / float(n)
                xoff = float(xmeter) / tilesz
                yoff = float(ymeter) / tilesz
                x = int(xoff + n2)
                y = int(n2 - yoff)
                for xctx in range(-context, context+1):
                    for yctx in range(-context, context+1):
                        absx = x+xctx
                        absy = y+yctx
                        t = (z, absx, absy)
                        if absx >= 0 and absx < n and absy >= 0 and absy < n and not t in tileset:
                            queue.put(t)
                            tileset.add(t)

        if(options.listfile):
            import json
            f = open(options.listfile, "w")
            f.write(json.dumps({
                "type": "FeatureCollection",
                "features": features
                }
            ))
            f.close()

    else:
        for z in range(minzoom, maxzoom+1):
            n = 2**z
            for x in range(0, n):
                for y in range(0, n):
                    if options.skipexisting and os.path.exists(dir + "/" + str(z) + "/" + str(x) + "/" + str(y) + "." + type):
                        continue
                    t = (z, x, y)
                    queue.put(t)

    # Signal render threads to exit by sending empty request to queue
    for i in range(threads):
        queue.put(None)

    # wait for pending rendering jobs to complete
    queue.join()
    for i in range(threads):
        renderers[i].join()

class RenderThread:
    def __init__(self, threadnum, queue, style, scale, dir, type, lock):
        self.threadnum = threadnum
        self.queue = queue
        self.scale = scale
        self.dir = dir
        self.type = type
        self.lock = lock
        self.style = style
        self.lock.acquire()
        print "Thread #%u created" % (threadnum)
        self.lock.release()

    def run(self):
        self.lock.acquire()
        print "Thread #%u started" % (self.threadnum)
        self.lock.release()

        m = mapnik.Map(256,256)
        mapnik.load_map(m, self.style, True)

        if(m.buffer_size < 32):
            m.buffer_size = 32

        while True:
            r = self.queue.get()
            if (r == None):
                self.queue.task_done()
                self.lock.acquire()
                print "Thread #%u: closing" % (self.threadnum)
                self.lock.release()
                break
            else:
                (z, x, y) = r

            render_tile(m, z, x, y, self.scale, self.dir, self.type, self.lock, self.threadnum)
            self.queue.task_done()


def render_tile(m, z, x, y, scale, dir, type, lock=None, threadnum=None):
    n = 2**z
    n2 = n/2
    x2n = x-n2
    y2n = (n-y-1)-n2

    tilesize = float(scale) / float(n);

    bbox = [
        tilesize * x2n,
        tilesize * y2n,
        tilesize * (x2n+1),
        tilesize * (y2n+1)
    ]
    pdir = dir + "/" + str(z) + "/" + str(x)

    if lock:
        lock.acquire()
        print "Thread #%u: z=%u x=%u y=%u -> (%f,%f,%f,%f)" % (threadnum, z, x, y, bbox[0], bbox[1], bbox[2], bbox[3])
        if not os.path.exists(pdir):
            os.makedirs(pdir)
        lock.release()
    else:
        if not os.path.exists(pdir):
            os.makedirs(pdir)
        print "z=%u x=%u y=%u -> (%f,%f,%f,%f)" % (z, x, y, bbox[0], bbox[1], bbox[2], bbox[3])

    if mapnik.Box2d:
        e = mapnik.Box2d(*bbox)
    else:
        e = mapnik.Envelope(*bbox)
    
    # zoom map to bounding box
    m.zoom_to_box(e)
    
    file = dir + "/" + str(z) + "/" + str(x) + "/" + str(y) + "." + type
    s = mapnik.Image(256, 256)
    
    mapnik.render(m, s)
    
    view = s.view(0, 0, 256, 256)
    view.save(file, type)

if __name__ == "__main__":
  main()
