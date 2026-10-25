-- Diseñadas para ejecutar tras implementar la carga en la siguiente etapa.
USE TLC_DW;
GO
-- T-03: antes de la carga, el número de hechos será cero, no es evidencia de aceptación.
SELECT COUNT_BIG(*) AS Hechos,COUNT(DISTINCT FechaKey/100) AS Meses FROM dbo.FactViaje;
-- T-02: debe devolver cero lotes incoherentes.
SELECT * FROM dbo.AuditoriaArchivo WHERE Estado='Completado'
 AND FilasOriginales<>FilasElegibles+FilasCuarentena;
-- T-04: la restricción única impide repetir el mismo archivo/fila.
SELECT ArchivoKey,FilaOrigen,COUNT_BIG(*) n FROM dbo.FactViaje
 GROUP BY ArchivoKey,FilaOrigen HAVING COUNT_BIG(*)>1;
-- T-14: comparar el resultado con actividad_mensual.csv (mismas reglas).
SELECT * FROM dbo.vw_ActividadMensual ORDER BY Anio,Mes;
-- T-01: deben existir doce lotes completados para publicar el año.
SELECT COUNT(DISTINCT MesArchivo) AS Meses FROM dbo.AuditoriaArchivo WHERE Estado='Completado';
-- OLAP: roll-up de mes a trimestre y año.
SELECT d.Anio,d.Trimestre,d.Mes,COUNT_BIG(*) Viajes,SUM(f.ImporteTotalUSD) ImporteUSD
FROM dbo.FactViaje f JOIN dbo.DimFecha d ON d.FechaKey=f.FechaKey
GROUP BY ROLLUP(d.Anio,d.Trimestre,d.Mes);
-- Slice: enero; dice: origen y pago; drill-down se realiza en Power BI.
SELECT z.Borough,p.Descripcion,COUNT_BIG(*) Viajes
FROM dbo.FactViaje f JOIN dbo.DimFecha d ON d.FechaKey=f.FechaKey
JOIN dbo.DimZona z ON z.ZonaKey=f.ZonaOrigenKey JOIN dbo.DimPago p ON p.PagoKey=f.PagoKey
WHERE d.Anio=2024 AND d.Mes=1 GROUP BY z.Borough,p.Descripcion;
