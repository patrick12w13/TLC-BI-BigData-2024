from concurrent.futures import ThreadPoolExecutor,as_completed
from pathlib import Path
import urllib.request,hashlib,json,datetime,time
root=Path(__file__).resolve().parents[1]
base=root/'02_Datos/original'
base.mkdir(parents=True,exist_ok=True)
items=[(f'yellow_tripdata_2024-{m:02}.parquet',f'https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2024-{m:02}.parquet') for m in range(1,13)]
items += [('taxi_zone_lookup.csv','https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv'),('diccionario_TLC.pdf','https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_yellow.pdf')]
def run(item):
 name,url=item;p=base/name
 for i in range(3):
  try:
   if not p.exists():
    with urllib.request.urlopen(url,timeout=120) as r, open(str(p)+'.part','wb') as o:
     while b:=r.read(1024*1024):o.write(b)
    Path(str(p)+'.part').replace(p)
   h=hashlib.file_digest(open(p,'rb'),'sha256').hexdigest()
   print(name,p.stat().st_size,flush=True)
   return dict(archivo=name,url=url,bytes=p.stat().st_size,sha256=h,fecha_descarga_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
  except Exception as e:
   if i==2:raise
   time.sleep(1)
with ThreadPoolExecutor(max_workers=4) as pool:
 results=[f.result() for f in as_completed([pool.submit(run,x) for x in items])]
(root/'02_Datos/manifest_fuentes.json').write_text(json.dumps(sorted(results,key=lambda x:x['archivo']),indent=2),encoding='utf8')
