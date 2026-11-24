import importlib.util,json,tempfile,threading,unittest,urllib.request,urllib.error,sqlite3
from pathlib import Path
spec=importlib.util.spec_from_file_location('holiday_server',Path(__file__).with_name('server.py'));s=importlib.util.module_from_spec(spec);spec.loader.exec_module(s)
class HolidayTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.tmp=tempfile.TemporaryDirectory();s.DATA=Path(cls.tmp.name);s.init();cls.server=s.ThreadingHTTPServer(('127.0.0.1',0),s.Handler);threading.Thread(target=cls.server.serve_forever,daemon=True).start();cls.base=f'http://127.0.0.1:{cls.server.server_port}';cls.cookie=''
 @classmethod
 def tearDownClass(cls):cls.server.shutdown();cls.server.server_close();cls.tmp.cleanup()
 def request(self,path,body=None,cookie=True,origin=None):
  headers={'Content-Type':'application/json'}
  if cookie and self.cookie:headers['Cookie']=self.cookie
  if origin:headers['Origin']=origin
  r=urllib.request.urlopen(urllib.request.Request(self.base+path,data=json.dumps(body).encode() if body is not None else None,headers=headers));return json.loads(r.read()),r.headers
 def test_workflow(self):
  with sqlite3.connect(s.DATA/'holidays.sqlite3') as db:initial_history=db.execute('SELECT COUNT(*) FROM history').fetchone()[0]
  initial,_=self.request('/api/data');self.assertEqual(len(initial['trips']),124)
  for y in range(2020,2025):
   rows=[t for t in initial['trips'] if t['year']==y];ref=initial['summaries'][str(y)]
   for key in ['travel','accommodation','total','flights','days']:self.assertAlmostEqual(sum(t.get(key) or 0 for t in rows),ref[key],places=2)
  self.assertEqual(next(t for t in initial['trips'] if t['year']==2025 and t['start']=='2025-06-22')['end'],'2025-07-12')
  self.assertEqual(next(t for t in initial['trips'] if t['year']==2026 and t['name']=='Les Contamines')['start'],'2026-02-14')
  ghent=next(t for t in initial['trips'] if t['year']==2023 and t['name']=='Ghent');self.assertEqual(ghent['country'],'Belgium');self.assertAlmostEqual(ghent['lat'],51.0543)
  s.init();after,_=self.request('/api/data');self.assertEqual(len(after['trips']),124)
  t,_=self.request('/api/save',{'kind':'trips','record':{'name':'Test trip','start':'2027-05-01','end':'2027-05-04','year':2027,'travel':30,'accommodation':50,'total':80,'country':'France','lat':48.8,'lon':2.3,'pins':[{'name':'Paris','lat':48.8,'lon':2.3}]}})
  self.assertEqual(t['total'],80);self.assertEqual(t['pins'][0]['name'],'Paris')
  with sqlite3.connect(s.DATA/'holidays.sqlite3') as db:self.assertIn('Test trip',db.execute("SELECT payload FROM records WHERE kind='trips' AND id=?",(t['id'],)).fetchone()[0])
  t['notes']='Edited';edited,_=self.request('/api/save',{'kind':'trips','id':t['id'],'record':t});self.assertEqual(edited['pins'],t['pins'])
  with self.assertRaises(urllib.error.HTTPError) as e:self.request('/api/save',{'kind':'trips','record':{'name':'Bad','start':'2027-05-10','end':'2027-05-01','year':2027}})
  self.assertEqual(e.exception.code,400)
  with self.assertRaises(urllib.error.HTTPError) as e:self.request('/api/delete',{'kind':'trips','id':t['id']},origin='https://untrusted.example')
  self.assertEqual(e.exception.code,403)
  self.request('/api/delete',{'kind':'trips','id':t['id']});final,_=self.request('/api/data');self.assertEqual(len(final['trips']),124)
  exported,_=self.request('/api/export.json');self.assertEqual(len(exported['events']),270)
  with sqlite3.connect(s.DATA/'holidays.sqlite3') as db:self.assertEqual(db.execute('SELECT COUNT(*) FROM history').fetchone()[0],initial_history+2)
if __name__=='__main__':unittest.main()

class PlaceOverviewTests(unittest.TestCase):
 def test_summary_is_cached(self):
  from unittest.mock import patch
  import wiki
  with tempfile.TemporaryDirectory() as folder,patch.object(wiki,'fetch',return_value={'type':'standard','title':'Ghent','extract':'Ghent is a city in Belgium.','coordinates':{'lat':51.05,'lon':3.72},'content_urls':{'desktop':{'page':'https://en.wikipedia.org/wiki/Ghent'}}}) as remote:
   first=wiki.overview(Path(folder)/'cache.sqlite3','Ghent','Belgium',51.05,3.72)
   self.assertTrue(first['available']);self.assertEqual(first['title'],'Ghent')
   second=wiki.overview(Path(folder)/'cache.sqlite3','Ghent','Belgium',51.05,3.72)
   self.assertEqual(first,second);self.assertEqual(remote.call_count,1)
 def test_no_unrelated_or_failed_summary(self):
  from unittest.mock import patch
  import wiki
  self.assertFalse(wiki.acceptable({'extract':'Wrong city','coordinates':{'lat':-30,'lon':150}},51,3))
  self.assertFalse(wiki.acceptable({'type':'disambiguation','extract':'A list'},None,None))
  with tempfile.TemporaryDirectory() as folder,patch.object(wiki,'fetch',side_effect=OSError('offline')):
   result=wiki.overview(Path(folder)/'cache.sqlite3','Ghent','Belgium',51.05,3.72)
   self.assertFalse(result['available']);self.assertIn('wikipedia.org',result['url'])

class PlaceSearchTests(unittest.TestCase):
 def test_search_returns_english_name_and_home_nation(self):
  from unittest.mock import patch,MagicMock
  response=MagicMock();response.__enter__.return_value.read.return_value=json.dumps([{'name':'Glasgow','display_name':'Glasgow, Scotland, United Kingdom','lat':'55.86','lon':'-4.25','address':{'country':'United Kingdom','state':'Scotland'}}]).encode()
  s.GEOCODE_CACHE.clear()
  with patch.object(s,'urlopen',return_value=response):
   result=s.search_places('Glasgow, Scotland')
  self.assertEqual(result[0]['name'],'Glasgow');self.assertEqual(result[0]['country'],'Scotland');self.assertEqual(result[0]['lat'],55.86)
 def test_search_rejects_empty_query(self):
  with self.assertRaises(ValueError):s.search_places(' ')
