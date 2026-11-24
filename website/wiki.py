"""Wikipedia place overviews; fixed upstream hosts, bounded requests and local caching."""
import hashlib,json,math,re,sqlite3,time
from contextlib import contextmanager
from html import unescape
from urllib.parse import quote,urlencode,urlparse,unquote
from urllib.request import Request,urlopen
TITLES={'Blackford':'Wedmore','Hull':'Kingston upon Hull','Kelso':'Kelso, Scottish Borders','Les Issambres':'Les Issambres','Les Contamines':'Les Contamines-Montjoie','Les Bottières':'Les Bottières','Marseilles':'Marseille','San Fransisco':'San Francisco','Milan/JEESC':'Milan','Split':'Split, Croatia','Plitvice National Park':'Plitvice Lakes National Park','Stourport':'Stourport-on-Severn','Reading Festival':'Reading and Leeds Festivals','Hawkhurst Fish Farm':'Hawkhurst','New York':'New York City','Italy (Vatican)':'Vatican City','Whitesmith':'Whitesmith','Chalons':'Châlons-en-Champagne'}
def fetch(url):
 with urlopen(Request(url,headers={'User-Agent':'ElsewhereHolidayTracker/1.0 (personal travel journal; place summaries)','Accept':'application/json'}),timeout=7) as r:return json.loads(r.read(2_000_000))
def plain(v):return unescape(re.sub('<[^>]*>','',str(v or ''))).strip()
def distance(a,b,c,d):
 rad=math.pi/180;v=math.sin((c-a)*rad/2)**2+math.cos(a*rad)*math.cos(c*rad)*math.sin((d-b)*rad/2)**2
 return 12742*math.asin(min(1,math.sqrt(v)))
def acceptable(page,lat,lon):
 if page.get('type')=='disambiguation' or not page.get('extract'):return False
 coord=page.get('coordinates')
 return not(coord and lat is not None and lon is not None and distance(lat,lon,coord['lat'],coord['lon'])>180)
def image_credit(page):
 source=page.get('thumbnail',{}).get('source','')
 if not source or urlparse(source).hostname not in ['upload.wikimedia.org','thumb.wikimedia.org']:return None
 parts=urlparse(source).path.split('/');filename=unquote(parts[-2] if '/thumb/' in source else parts[-1])
 try:
  q=urlencode({'action':'query','titles':'File:'+filename,'prop':'imageinfo','iiprop':'extmetadata','format':'json'})
  pages=fetch('https://commons.wikimedia.org/w/api.php?'+q).get('query',{}).get('pages',{})
  metadata=next(iter(pages.values())).get('imageinfo',[{}])[0].get('extmetadata',{})
  artist=plain(metadata.get('Artist',{}).get('value'))[:180];license=plain(metadata.get('LicenseShortName',{}).get('value'))
  if not artist or not license:return None
  return {'url':source,'artist':artist,'license':license,'source':'https://commons.wikimedia.org/wiki/File:'+quote(filename.replace(' ','_'))}
 except Exception:return None

@contextmanager
def store(database):
 c=sqlite3.connect(database)
 try:
  with c:yield c
 finally:c.close()
def overview(database,name,country='',lat=None,lon=None):
 name=name.strip()[:150];country=country.strip()[:150]
 if not name:raise ValueError('Place name is required')
 if lat is not None and (not math.isfinite(lat) or abs(lat)>90):raise ValueError('Invalid latitude')
 if lon is not None and (not math.isfinite(lon) or abs(lon)>180):raise ValueError('Invalid longitude')
 key=hashlib.sha256(json.dumps([name,country,lat,lon]).encode()).hexdigest()
 with store(database) as c:
  c.execute('CREATE TABLE IF NOT EXISTS place_cache (key TEXT PRIMARY KEY,updated REAL,payload TEXT)')
  cached=c.execute('SELECT updated,payload FROM place_cache WHERE key=?',(key,)).fetchone()
  if cached and time.time()-cached[0]<604800:return json.loads(cached[1])
 title=TITLES.get(name,name);page=None
 try:
  candidate=fetch('https://en.wikipedia.org/api/rest_v1/page/summary/'+quote(title.replace(' ','_'),safe=''))
  if acceptable(candidate,lat,lon):page=candidate
 except Exception:pass
 if page is None:
  try:
   search=fetch('https://en.wikipedia.org/w/api.php?'+urlencode({'action':'query','list':'search','srsearch':title+' '+country,'srlimit':3,'format':'json'}))
   for item in search.get('query',{}).get('search',[])[:2]:
    candidate=fetch('https://en.wikipedia.org/api/rest_v1/page/summary/'+quote(item['title'].replace(' ','_'),safe=''))
    if acceptable(candidate,lat,lon):page=candidate;break
  except Exception:pass
 if page:
  result={'available':True,'title':page['title'],'description':page.get('description',''),'extract':page['extract'],'url':page.get('content_urls',{}).get('desktop',{}).get('page','https://en.wikipedia.org/wiki/'+quote(page['title'].replace(' ','_'))),'image':image_credit(page),'license':'CC BY-SA 4.0','license_url':'https://creativecommons.org/licenses/by-sa/4.0/'}
 else:
  result={'available':False,'title':name,'url':'https://en.wikipedia.org/wiki/Special:Search?'+urlencode({'search':name+' '+country})}
 with store(database) as c:c.execute('INSERT OR REPLACE INTO place_cache VALUES (?,?,?)',(key,time.time() if page else time.time()-601200,json.dumps(result)))
 return result
