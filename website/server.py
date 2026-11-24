import argparse,csv,io,json,math,os,sqlite3,threading,time
from datetime import date
from http.server import ThreadingHTTPServer,BaseHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlparse,parse_qs,urlencode
from urllib.request import Request,urlopen
import wiki
from contextlib import contextmanager,closing
ROOT=Path(__file__).resolve().parent
DATA=Path(os.environ.get('HOLIDAY_DATA_DIR',ROOT/'data'));DATA.mkdir(parents=True,exist_ok=True)
PHOTOS=Path(os.environ.get('HOLIDAY_PHOTOS_DIR',ROOT.parent/'holiday-tracker-source'))
LOCK=threading.RLock()
GEOCODE_LOCK=threading.Lock()
GEOCODE_LAST=0.0
GEOCODE_CACHE={}
@contextmanager
def db():
 c=sqlite3.connect(DATA/'holidays.sqlite3');c.row_factory=sqlite3.Row
 try:
  with c:yield c
 finally:c.close()
def backup():
 target=DATA/'backups'/f'holidays-{date.today().isoformat()}.sqlite3'
 if target.exists() or not (DATA/'holidays.sqlite3').exists():return
 target.parent.mkdir(exist_ok=True)
 with db() as source,closing(sqlite3.connect(target)) as dest:source.backup(dest)
 target.chmod(0o600)
 for old in sorted(target.parent.glob('holidays-*.sqlite3'))[:-30]:old.unlink()
def init():
 with db() as c:
  c.executescript('CREATE TABLE IF NOT EXISTS records (kind TEXT,id INTEGER,payload TEXT,PRIMARY KEY(kind,id)); CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY,value TEXT); CREATE TABLE IF NOT EXISTS history (id INTEGER PRIMARY KEY,at TEXT DEFAULT CURRENT_TIMESTAMP,kind TEXT,record_id INTEGER,payload TEXT);')
  if not c.execute("SELECT 1 FROM settings WHERE key='seeded'").fetchone():
   for kind in ['trips','events']:
    for row in json.loads((ROOT/'import'/f'{kind}.json').read_text()): c.execute('INSERT INTO records VALUES (?,?,?)',(kind,row['id'],json.dumps(row)))
   for key in ['summaries','calendar-overrides']:
    c.execute('INSERT INTO settings VALUES (?,?)',(key,(ROOT/'import'/f'{key}.json').read_text()))
   c.execute("INSERT INTO settings VALUES ('seeded','true')")
  # User-confirmed corrections; once only, preserving later edits.
  if not c.execute("SELECT 1 FROM settings WHERE key='date-corrections-v1'").fetchone():
   for row in c.execute("SELECT id,payload FROM records WHERE kind='trips'").fetchall():
    t=json.loads(row['payload'])
    if t['year']==2025 and t['name']=='Les Issambres' and t['end']=='2025-06-12':
     t['end']='2025-07-12';t['review']=False;t['notes']='User confirmed end date 12 July 2025. Photo reads 12/06; corrected during import. Calendar starts 28 June; table starts 22 June.'
    elif t['year']==2026 and t['name']=='Les Contamines' and t['start']=='2026-01-14':
     t['start']='2026-02-14';t['review']=False;t['notes']='User confirmed start date 14 February 2026. Photo reads 14/01; corrected during import.'
    c.execute("UPDATE records SET payload=? WHERE kind='trips' AND id=?",(json.dumps(t),t['id']))
   c.execute("INSERT INTO settings VALUES ('date-corrections-v1','true')")
  if not c.execute("SELECT 1 FROM settings WHERE key='ghent-correction-v1'").fetchone():
   for row in c.execute("SELECT id,payload FROM records WHERE kind='trips'").fetchall():
    t=json.loads(row['payload'])
    if t.get('year')==2023 and t.get('name')=='Belgium':
     c.execute('INSERT INTO history(kind,record_id,payload) VALUES (?,?,?)',('trips',t['id'],row['payload']))
     t['name']='Ghent';t['country']='Belgium';t['lat']=51.0543;t['lon']=3.7174
     t['notes']=(t.get('notes','')+' User confirmed the 2023 Belgium destination was Ghent.').strip()
     c.execute("UPDATE records SET payload=? WHERE kind='trips' AND id=?",(json.dumps(t),t['id']))
   c.execute("INSERT INTO settings VALUES ('ghent-correction-v1','true')")
 (DATA/'holidays.sqlite3').chmod(0o600)
 backup()
def all_data():
 with db() as c:
  result={k:[json.loads(r[0]) for r in c.execute('SELECT payload FROM records WHERE kind=? ORDER BY id',(k,))] for k in ['trips','events']}
  for k in ['summaries','calendar-overrides']:result[k]=json.loads(c.execute('SELECT value FROM settings WHERE key=?',(k,)).fetchone()[0])
  result['places']=json.loads((ROOT/'import'/'places.json').read_text())
  result['map_config']={'url':os.environ.get('HOLIDAY_TILE_URL',''),'attribution':os.environ.get('HOLIDAY_TILE_ATTRIBUTION','&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">OpenStreetMap</a> contributors')}
  result['photos']=sorted({p.name for folder in (PHOTOS,DATA/'import-sources') for p in folder.glob('*.jpeg')})
  return result
def search_places(query):
 global GEOCODE_LAST
 query=query.strip()
 if len(query)<2 or len(query)>160:raise ValueError('Enter a place to search for')
 key=query.casefold()
 with GEOCODE_LOCK:
  if key in GEOCODE_CACHE:return GEOCODE_CACHE[key]
  delay=1.05-(time.monotonic()-GEOCODE_LAST)
  if delay>0:time.sleep(delay)
  GEOCODE_LAST=time.monotonic()
  params=urlencode({'q':query,'format':'jsonv2','limit':7,'addressdetails':1,'accept-language':'en'})
  request=Request('https://nominatim.openstreetmap.org/search?'+params,headers={'User-Agent':'HolidaysLocalTracker/1.0 (personal travel journal)','Accept':'application/json'})
  try:
   with urlopen(request,timeout=10) as response:items=json.loads(response.read(250000))
   results=[]
   for item in items:
    lat=float(item['lat']);lon=float(item['lon']);address=item.get('address') or {};country=address.get('country','')
    if address.get('country_code','').lower() in ('hk','mo'):country={'hk':'Hong Kong','mo':'Macau'}[address['country_code'].lower()]
    if country=='United Kingdom' and address.get('state') in ('England','Scotland','Wales','Northern Ireland'):country=address['state']
    if math.isfinite(lat) and math.isfinite(lon) and abs(lat)<=90 and abs(lon)<=180:
     display=str(item.get('display_name',''))[:500];name=str(item.get('name') or display.split(',')[0])[:200]
     if name and display:results.append({'name':name,'display':display,'lat':lat,'lon':lon,'country':country})
   if len(GEOCODE_CACHE)>=100:GEOCODE_CACHE.clear()
   GEOCODE_CACHE[key]=results;return results
  except Exception:raise ValueError('Place search is unavailable. Please try again or choose a pin on the map.')
def validate(kind,t):
 if not isinstance(t,dict):raise ValueError('Invalid record')
 allowed={'name','start','end','notes','review'}
 allowed |= {'locations','country','lat','lon','pins','calendar_confirmed','journey_name','trip_role','shared_fields','year','travel','accommodation','total','flights','days','leave','group','region','source'} if kind=='trips' else {'kind'}
 t={k:v for k,v in t.items() if k in allowed}
 if not isinstance(t.get('name'),str) or not t['name'].strip():raise ValueError('A name is required')
 if len(t['name'])>200 or len(t.get('notes',''))>10000:raise ValueError('Text is too long')
 for k in ['start','end']:
  t[k]=t.get(k) or None
  if t[k]:date.fromisoformat(t[k])
 if t['start'] and t['end'] and t['end']<t['start']:raise ValueError('End date must be on or after start date')
 if kind=='trips':
  t['year']=int(t.get('year') or t['start'][:4]);
  if not 1900<=t['year']<=2200:raise ValueError('Invalid year')
  for k in ['travel','accommodation','total','flights','days','leave']:
   v=t.get(k);t[k]=None if v is None or v=='' else float(v)
   if t[k] is not None and (not math.isfinite(t[k]) or t[k]<0):raise ValueError('Numbers must be zero or positive')
  
  for k,limit in [('lat',90),('lon',180)]:
   if k in t:
    t[k]=None if t[k] in ['',None] else float(t[k])
    if t[k] is not None and (not math.isfinite(t[k]) or abs(t[k])>limit):raise ValueError('Invalid coordinates')
  if 'trip_role' in t and t['trip_role'] not in ('stop','day-trip'):raise ValueError('Invalid trip type')
  if 'journey_name' in t and (not isinstance(t['journey_name'],str) or len(t['journey_name'])>200):raise ValueError('Invalid journey name')
  if 'shared_fields' in t and (not isinstance(t['shared_fields'],list) or any(x not in ['travel','flights','days','leave'] for x in t['shared_fields'])):raise ValueError('Invalid shared costs')
  if 'calendar_confirmed' in t:
   if not isinstance(t['calendar_confirmed'],bool):raise ValueError('Invalid calendar confirmation')
  if 'pins' in t:
   if not isinstance(t['pins'],list) or len(t['pins'])>50:raise ValueError('Invalid places')
   pins=[]
   for pin in t['pins']:
    if not isinstance(pin,dict) or not isinstance(pin.get('name'),str) or not pin['name'].strip() or len(pin['name'])>200:raise ValueError('Invalid place name')
    try:lat=float(pin['lat']);lon=float(pin['lon'])
    except (KeyError,ValueError,TypeError):raise ValueError('Invalid place coordinates')
    if not math.isfinite(lat) or not math.isfinite(lon) or abs(lat)>90 or abs(lon)>180:raise ValueError('Invalid place coordinates')
    pins.append({'name':pin['name'].strip(),'lat':lat,'lon':lon})
   t['pins']=pins
  t.setdefault('group','');t.setdefault('source','');t.setdefault('region','Europe')
 else:t.setdefault('kind','event')
 return t
class Handler(BaseHTTPRequestHandler):
 def send(self,status,value,ctype='application/json',headers=None):
  data=value if isinstance(value,bytes) else (json.dumps(value).encode() if ctype=='application/json' else value.encode())
  self.send_response(status);self.send_header('Content-Type',ctype);self.send_header('Content-Length',str(len(data)));self.send_header('X-Content-Type-Options','nosniff');self.send_header('Cache-Control','no-store');self.send_header('X-Frame-Options','DENY')
  for k,v in (headers or {}).items():self.send_header(k,v)
  self.end_headers();self.wfile.write(data)
 def do_GET(self):
  path=urlparse(self.path).path
  if path=='/health':return self.send(200,{'ok':True})
  if path.startswith('/api/') or path.startswith('/photos/'):
   if path=='/api/place-search':
    try:return self.send(200,search_places(parse_qs(urlparse(self.path).query).get('q',[''])[0]))
    except ValueError as e:return self.send(400,{'error':str(e)})
   if path=='/api/place':
    try:
     q=parse_qs(urlparse(self.path).query);lat=q.get('lat',[''])[0];lon=q.get('lon',[''])[0]
     return self.send(200,wiki.overview(DATA/'holidays.sqlite3',q.get('name',[''])[0],q.get('country',[''])[0],float(lat) if lat else None,float(lon) if lon else None))
    except (ValueError,TypeError) as e:return self.send(400,{'error':str(e)})
   if path=='/api/data':return self.send(200,all_data())
   if path=='/api/export.json':return self.send(200,all_data(),headers={'Content-Disposition':'attachment; filename=holidays.json'})
   if path=='/api/export.csv':
    rows=all_data()['trips'];s=io.StringIO();keys=list(dict.fromkeys(k for r in rows for k in r)) if rows else ['name','start','end'];w=csv.DictWriter(s,fieldnames=keys,extrasaction='ignore');w.writeheader()
    for r in rows:w.writerow({k:("'"+v if isinstance(v,str) and v.startswith(('=','+','-','@')) else v) for k,v in r.items()})
    return self.send(200,s.getvalue(),'text/csv; charset=utf-8',{'Content-Disposition':'attachment; filename=holidays.csv'})
   if path.startswith('/photos/'):
    name=path.rsplit('/',1)[-1]
    files={p.name:p for folder in (PHOTOS,DATA/'import-sources') for p in folder.glob('*.jpeg')}
    if name not in files:return self.send(404,{'error':'Photo not found'})
    return self.send(200,files[name].read_bytes(),'image/jpeg')
   return self.send(404,{'error':'Not found'})
  static={'/trip-editor.js':'trip-editor.js','/english-map-style.json':'english-map-style.json','/vendor/maplibre/maplibre-gl.js':'vendor/maplibre/maplibre-gl.js','/vendor/maplibre/maplibre-gl.css':'vendor/maplibre/maplibre-gl.css','/vendor/maplibre/leaflet-maplibre-gl.js':'vendor/maplibre/leaflet-maplibre-gl.js','/ui.js':'ui.js','/maps.js':'maps.js','/vendor/leaflet/leaflet.js':'vendor/leaflet/leaflet.js','/vendor/leaflet/leaflet.css':'vendor/leaflet/leaflet.css','/vendor/markercluster/leaflet.markercluster.js':'vendor/markercluster/leaflet.markercluster.js','/vendor/markercluster/MarkerCluster.css':'vendor/markercluster/MarkerCluster.css','/fonts/dm-sans.ttf':'fonts/dm-sans.ttf','/fonts/manrope.ttf':'fonts/manrope.ttf','/world.geojson':'world.geojson','/':'index.html','/app.js':'app.js','/style.css':'style.css'}
  if path not in static:return self.send(404,'Not found','text/plain')
  file=ROOT/'static'/static[path];return self.send(200,file.read_bytes(),{'html':'text/html; charset=utf-8','js':'text/javascript','css':'text/css','geojson':'application/geo+json','json':'application/json','ttf':'font/ttf'}[file.suffix[1:]])
 def do_POST(self):
  origin=self.headers.get('Origin')
  if origin and urlparse(origin).netloc!=self.headers.get('Host'):return self.send(403,{'error':'Invalid origin'})
  if self.headers.get('Content-Type','').split(';')[0]!='application/json':return self.send(415,{'error':'JSON required'})
  try:
   size=int(self.headers.get('Content-Length',0))
   if not 0<size<100000:raise ValueError('Invalid request size')
   body=json.loads(self.rfile.read(size));path=urlparse(self.path).path
   with LOCK:
    if path not in ['/api/save','/api/delete','/api/summary','/api/save-journey']:return self.send(404,{'error':'Not found'})
    backup()
    with db() as c:
     if path=='/api/summary':
      y=str(int(body['year']));v=body['values']
      if not isinstance(v,dict):raise ValueError('Invalid annual values')
      current=json.loads(c.execute("SELECT value FROM settings WHERE key='summaries'").fetchone()[0]);current[y]=v
      c.execute("UPDATE settings SET value=? WHERE key='summaries'",(json.dumps(current),));return self.send(200,{'ok':True})
     if path=='/api/save-journey':
      records=body.get('records');group=body.get('group')
      if not isinstance(group,str) or not group.startswith('journey-') or len(group)>100 or not isinstance(records,list) or not 2<=len(records)<=50:raise ValueError('A journey needs a name and at least two stops')
      existing=[json.loads(row[0]) for row in c.execute("SELECT payload FROM records WHERE kind='trips'")]
      if any(r.get('group')==group for r in existing):raise ValueError('This journey has already been saved')
      validated=[]
      for record in records:
       if not isinstance(record,dict) or record.get('group')!=group:raise ValueError('Invalid journey stop')
       item=validate('trips',record)
       if not item.get('start') or not item.get('end'):raise ValueError('Choose start and end dates for each stop')
       validated.append(item)
      rid=c.execute("SELECT COALESCE(MAX(id),0)+1 FROM records WHERE kind='trips'").fetchone()[0]
      for item in validated:
       item['id']=rid;rid+=1;c.execute('INSERT INTO records VALUES (?,?,?)',('trips',item['id'],json.dumps(item)))
      c.commit();return self.send(200,{'ok':True,'trips':validated})
     kind=body.get('kind')
     if kind not in ['trips','events']:raise ValueError('Invalid kind')
     rid=int(body.get('id') or 0)
     old=c.execute('SELECT payload FROM records WHERE kind=? AND id=?',(kind,rid)).fetchone()
     if old:c.execute('INSERT INTO history(kind,record_id,payload) VALUES (?,?,?)',(kind,rid,old[0]))
     if path=='/api/delete':
      c.execute('DELETE FROM records WHERE kind=? AND id=?',(kind,rid));return self.send(200,{'ok':True})
     record=validate(kind,body['record'])
     if not rid:rid=c.execute('SELECT COALESCE(MAX(id),0)+1 FROM records WHERE kind=?',(kind,)).fetchone()[0]
     record['id']=rid;c.execute('INSERT OR REPLACE INTO records VALUES (?,?,?)',(kind,rid,json.dumps(record)))
     return self.send(200,record)
  except (ValueError,TypeError,KeyError) as e:return self.send(400,{'error':str(e)})
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--host',default='0.0.0.0');p.add_argument('--port',type=int,default=8000);args=p.parse_args();init();ThreadingHTTPServer((args.host,args.port),Handler).serve_forever()
