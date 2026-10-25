"""Comprobar los originales y la reconciliación. Ejecutar desde cualquier carpeta."""
from pathlib import Path
import json,hashlib,csv,sys
import pyarrow.parquet as pq
root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'02_Datos/manifest_fuentes.json').read_text(encoding='utf8'))
errors=[];n=0
for item in manifest:
 p=root/'02_Datos/original'/item['archivo']
 if not p.is_file():errors.append(f'Falta {p.name}');continue
 with p.open('rb') as f:h=hashlib.file_digest(f,'sha256').hexdigest()
 if h!=item['sha256']:errors.append(f'Hash incorrecto: {p.name}')
 if p.stat().st_size!=item['bytes']:errors.append(f'Tamaño incorrecto: {p.name}')
 if p.suffix=='.parquet':n+=pq.ParquetFile(p).metadata.num_rows
s=json.loads((root/'02_Datos/perfil/resumen_perfil.json').read_text())
if n!=s['registros_originales']:errors.append('Conteo físico no coincide con perfil')
if s['registros_originales']!=s['registros_elegibles']+s['cuarentena']:errors.append('Falla reconciliación anual')
with (root/'02_Datos/perfil/perfil_mensual.csv').open() as f:monthly=list(csv.DictReader(f))
if [r['mes_archivo'] for r in monthly]!=[f'{i:02}' for i in range(1,13)]:errors.append('Falla cobertura anual')
if sum(int(r['registros']) for r in monthly)!=n:errors.append('Falla suma mensual')
with (root/'02_Datos/original/taxi_zone_lookup.csv').open(encoding='utf-8-sig') as f:zones=list(csv.DictReader(f))
keys=[int(r['LocationID']) for r in zones]
if len(keys)!=len(set(keys)):errors.append('LocationID duplicado en catálogo')
if not set(range(1,264)).issubset(keys):errors.append('Faltan zonas 1..263')
print(json.dumps({'estado':'ERROR' if errors else 'OK','archivos_verificados':len(manifest),'meses':len(monthly),'registros_originales':n,'catalogo_zonas':len(keys),'errores':errors},ensure_ascii=False,indent=2))
sys.exit(bool(errors))
