from pathlib import Path
import duckdb,json,hashlib,platform,sys,datetime,csv
root=Path(__file__).resolve().parents[1]; out=root/'02_Datos/perfil';out.mkdir(exist_ok=True)
c=duckdb.connect();c.execute("SET threads=4");c.execute("SET memory_limit='3GB'");c.execute("SET temp_directory='"+str(out/'temporal_duckdb')+"'")
files=str(root/'02_Datos/original/yellow_tripdata_2024-*.parquet')
c.execute(f"CREATE VIEW raw AS SELECT *,filename AS archivo FROM read_parquet('{files}',union_by_name=true,filename=true)")
print(c.execute('DESCRIBE raw').fetchall(),flush=True)
# Trips flagged by operational rules, no record is silently removed from the original.
c.execute('''CREATE VIEW flags AS SELECT *,
 tpep_pickup_datetime IS NULL OR tpep_dropoff_datetime IS NULL AS f_fechas_nulas,
 tpep_pickup_datetime < TIMESTAMP '2024-01-01' OR tpep_pickup_datetime >= TIMESTAMP '2025-01-01' AS f_fuera_2024,
 tpep_dropoff_datetime <= tpep_pickup_datetime AS f_duracion,
 trip_distance IS NULL OR trip_distance <= 0 AS f_distancia,
 fare_amount IS NULL OR fare_amount < 0 OR total_amount IS NULL OR total_amount <= 0 AS f_importe,
 PULocationID IS NULL OR PULocationID NOT BETWEEN 1 AND 263 OR DOLocationID IS NULL OR DOLocationID NOT BETWEEN 1 AND 263 AS f_zona,
 date_diff('second',tpep_pickup_datetime,tpep_dropoff_datetime)>14400 AS f_mayor_4h
 FROM raw''')
c.execute('''CREATE VIEW tagged AS SELECT *,
 coalesce(f_fechas_nulas OR f_fuera_2024 OR f_duracion OR f_distancia OR f_importe OR f_zona OR f_mayor_4h,true) AS cuarentena
 FROM flags''')
fields=['f_fechas_nulas','f_fuera_2024','f_duracion','f_distancia','f_importe','f_zona','f_mayor_4h']
rows=c.execute("SELECT count(*),"+','.join(f"count(*) FILTER (WHERE {f})" for f in fields)+",count(*) FILTER (WHERE cuarentena) FROM tagged").fetchone()
summary=dict(zip(['registros_originales']+fields+['cuarentena'],rows));summary['registros_elegibles']=rows[0]-rows[-1]
summary['porcentaje_cuarentena']=round(rows[-1]/rows[0]*100,5)
summary['bytes_originales_parquet']=sum(p.stat().st_size for p in (root/'02_Datos/original').glob('*.parquet'))
summary['campos']=c.execute('DESCRIBE raw').fetchall()
# physical-file monthly profile (file month vs timestamps handled separately)
c.execute("COPY (SELECT regexp_extract(archivo,'2024-([0-9]{2})',1) AS mes_archivo,count(*) registros,count(*) FILTER (WHERE cuarentena) cuarentena,count(*) FILTER (WHERE NOT cuarentena) elegibles FROM tagged GROUP BY 1 ORDER BY 1) TO '"+str(out/'perfil_mensual.csv')+"' (HEADER,DELIMITER ',')")
c.execute("COPY (SELECT column_name,column_type FROM (DESCRIBE raw)) TO '"+str(out/'esquema_original.csv')+"' (HEADER,DELIMITER ',')")
for name,q in {
 'nulos_campos':"SELECT "+','.join(f'count(*) FILTER (WHERE "{col}" IS NULL) AS "{col}"' for col in ['VendorID','passenger_count','RatecodeID','store_and_fwd_flag','congestion_surcharge','Airport_fee'])+' FROM raw',
 'resumen_comercial':"SELECT count(*) viajes_elegibles,round(sum(CAST(total_amount AS DECIMAL(18,2))),2) importe_total_usd,round(avg(CAST(total_amount AS DECIMAL(18,2))),4) importe_medio_usd,round(avg(date_diff('second',tpep_pickup_datetime,tpep_dropoff_datetime)/60.0),4) duracion_media_min,round(avg(trip_distance),4) distancia_media_millas FROM tagged WHERE NOT cuarentena",
 'actividad_mensual':"SELECT strftime(tpep_pickup_datetime,'%Y-%m') mes,count(*) viajes,round(sum(CAST(total_amount AS DECIMAL(18,2))),2) importe_usd FROM tagged WHERE NOT cuarentena GROUP BY 1 ORDER BY 1",
 'zonas_origen':"SELECT PULocationID,count(*) viajes,round(sum(CAST(total_amount AS DECIMAL(18,2))),2) importe_usd FROM tagged WHERE NOT cuarentena GROUP BY 1 ORDER BY viajes DESC",
 'patron_horario':"SELECT isodow(tpep_pickup_datetime) dia_semana,hour(tpep_pickup_datetime) hora,count(*) viajes,round(sum(CAST(total_amount AS DECIMAL(18,2))),2) importe_usd FROM tagged WHERE NOT cuarentena GROUP BY 1,2 ORDER BY 1,2"
}.items():
 c.execute(f"COPY ({q}) TO '{out/name}.csv' (HEADER,DELIMITER ',')")
 print('wrote',name,flush=True)
# Duplicate-content diagnostic includes all original columns, excluding source filename.
cols=[r[0] for r in c.execute('DESCRIBE raw').fetchall() if r[0] not in ['archivo','filename']]
expr=','.join('"'+v+'"' for v in cols)
dup=c.execute(f'SELECT sum(n-1),count(*) FROM (SELECT count(*) n FROM raw GROUP BY {expr} HAVING count(*)>1)').fetchone()
summary['filas_excedentes_contenido_duplicado']=dup[0] or 0;summary['grupos_contenido_duplicado']=dup[1]
summary['politica_duplicados']='Se conservan: sin identificador transaccional, igualdad de atributos no demuestra duplicación real. Se impide reingesta por SHA256 de archivo y fila física.'
summary['entorno']={'python':sys.version,'duckdb':duckdb.__version__,'plataforma':platform.platform(),'threads':4,'memory_limit':'3GB','fecha_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
(out/'resumen_perfil.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2,default=str),encoding='utf8')
c.close()
import shutil
shutil.rmtree(out/"temporal_duckdb",ignore_errors=True)
print(json.dumps(summary,ensure_ascii=False,default=str),flush=True)
