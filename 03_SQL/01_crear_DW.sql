/* T2 - Diseño físico para SQL Server 2022 Developer.
   Ejecutar en SSMS con permisos para crear la BD. No elimina datos existentes.
   Validación realizada: revisión estructural; motor SQL Server no disponible
   en el entorno de preparación. Ejecutar prueba de despliegue antes de entregar.
*/
USE master;
GO
IF DB_ID(N'TLC_DW') IS NULL CREATE DATABASE TLC_DW;
GO
USE TLC_DW;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF OBJECT_ID('dbo.DimFecha','U') IS NULL
CREATE TABLE dbo.DimFecha (
 FechaKey int NOT NULL CONSTRAINT PK_DimFecha PRIMARY KEY,
 Fecha date NOT NULL CONSTRAINT UQ_DimFecha UNIQUE,
 Anio smallint NOT NULL, Trimestre tinyint NOT NULL,
 Mes tinyint NOT NULL, Dia tinyint NOT NULL, DiaSemanaISO tinyint NOT NULL,
 CONSTRAINT CK_FechaMes CHECK(Mes BETWEEN 1 AND 12),
 CONSTRAINT CK_FechaTrim CHECK(Trimestre BETWEEN 1 AND 4),
 CONSTRAINT CK_FechaDiaSemana CHECK(DiaSemanaISO BETWEEN 1 AND 7));
IF OBJECT_ID('dbo.DimHora','U') IS NULL
CREATE TABLE dbo.DimHora (
 HoraKey tinyint NOT NULL CONSTRAINT PK_DimHora PRIMARY KEY,
 Franja varchar(12) NOT NULL, CONSTRAINT CK_Hora CHECK(HoraKey BETWEEN 0 AND 23));
IF OBJECT_ID('dbo.DimZona','U') IS NULL
CREATE TABLE dbo.DimZona (
 ZonaKey int NOT NULL CONSTRAINT PK_DimZona PRIMARY KEY,
 Borough nvarchar(60) NOT NULL,Zona nvarchar(120) NOT NULL,Servicio nvarchar(60) NULL);
IF OBJECT_ID('dbo.DimPago','U') IS NULL
CREATE TABLE dbo.DimPago (
 PagoKey smallint NOT NULL CONSTRAINT PK_DimPago PRIMARY KEY,Descripcion nvarchar(60) NOT NULL);
IF OBJECT_ID('dbo.DimTarifa','U') IS NULL
CREATE TABLE dbo.DimTarifa (
 TarifaKey smallint NOT NULL CONSTRAINT PK_DimTarifa PRIMARY KEY,Descripcion nvarchar(60) NOT NULL);
IF OBJECT_ID('dbo.DimProveedor','U') IS NULL
CREATE TABLE dbo.DimProveedor (
 ProveedorKey smallint NOT NULL CONSTRAINT PK_DimProveedor PRIMARY KEY,Descripcion nvarchar(100) NOT NULL);
IF OBJECT_ID('dbo.AuditoriaArchivo','U') IS NULL
CREATE TABLE dbo.AuditoriaArchivo (
 ArchivoKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Auditoria PRIMARY KEY,
 Nombre nvarchar(160) NOT NULL, SHA256 char(64) NOT NULL CONSTRAINT UQ_ArchivoHash UNIQUE,
 MesArchivo date NOT NULL,Estado varchar(16) NOT NULL CONSTRAINT DF_Estado DEFAULT 'Pendiente',
 InicioUTC datetime2(0) NULL,FinUTC datetime2(0) NULL,
 FilasOriginales bigint NOT NULL CONSTRAINT DF_Original DEFAULT 0,
 FilasElegibles bigint NOT NULL CONSTRAINT DF_Elegible DEFAULT 0,
 FilasCuarentena bigint NOT NULL CONSTRAINT DF_Cuarentena DEFAULT 0,
 VersionCodigo varchar(64) NOT NULL,Error nvarchar(2000) NULL,
 CONSTRAINT CK_AuditoriaEstado CHECK(Estado IN ('Pendiente','Cargando','Completado','Error')),
 CONSTRAINT CK_AuditoriaConteos CHECK(FilasOriginales>=0 AND FilasElegibles>=0 AND FilasCuarentena>=0),
 CONSTRAINT CK_AuditoriaMes CHECK(DAY(MesArchivo)=1));
IF OBJECT_ID('dbo.FactViaje','U') IS NULL
CREATE TABLE dbo.FactViaje (
 ViajeKey bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactViaje PRIMARY KEY,
 ArchivoKey int NOT NULL, FilaOrigen bigint NOT NULL,
 FechaKey int NOT NULL,HoraKey tinyint NOT NULL,ZonaOrigenKey int NOT NULL,ZonaDestinoKey int NOT NULL,
 PagoKey smallint NOT NULL,TarifaKey smallint NOT NULL,ProveedorKey smallint NOT NULL,
 InicioLocal datetime2(0) NOT NULL,FinLocal datetime2(0) NOT NULL,
 DuracionSegundos int NOT NULL,DistanciaMillas decimal(18,4) NOT NULL,Pasajeros smallint NULL,
 TarifaUSD decimal(18,2) NOT NULL,ImporteTotalUSD decimal(18,2) NOT NULL,PropinaTarjetaUSD decimal(18,2) NULL,
 CONSTRAINT UQ_FactFuente UNIQUE(ArchivoKey,FilaOrigen),
 CONSTRAINT FK_FactArchivo FOREIGN KEY(ArchivoKey) REFERENCES dbo.AuditoriaArchivo(ArchivoKey),
 CONSTRAINT FK_FactFecha FOREIGN KEY(FechaKey) REFERENCES dbo.DimFecha(FechaKey),
 CONSTRAINT FK_FactHora FOREIGN KEY(HoraKey) REFERENCES dbo.DimHora(HoraKey),
 CONSTRAINT FK_FactOrigen FOREIGN KEY(ZonaOrigenKey) REFERENCES dbo.DimZona(ZonaKey),
 CONSTRAINT FK_FactDestino FOREIGN KEY(ZonaDestinoKey) REFERENCES dbo.DimZona(ZonaKey),
 CONSTRAINT FK_FactPago FOREIGN KEY(PagoKey) REFERENCES dbo.DimPago(PagoKey),
 CONSTRAINT FK_FactTarifa FOREIGN KEY(TarifaKey) REFERENCES dbo.DimTarifa(TarifaKey),
 CONSTRAINT FK_FactProveedor FOREIGN KEY(ProveedorKey) REFERENCES dbo.DimProveedor(ProveedorKey),
 CONSTRAINT CK_FactFila CHECK(FilaOrigen>=0),
 CONSTRAINT CK_FactPeriodo CHECK(InicioLocal>='20240101' AND InicioLocal<'20250101'),
 CONSTRAINT CK_FactTiempo CHECK(DuracionSegundos BETWEEN 1 AND 14400 AND FinLocal>InicioLocal
 AND DuracionSegundos=DATEDIFF(SECOND,InicioLocal,FinLocal)),
 CONSTRAINT CK_FactDistancia CHECK(DistanciaMillas>0),
 CONSTRAINT CK_FactImporte CHECK(TarifaUSD>=0 AND ImporteTotalUSD>0),
 CONSTRAINT CK_FactZona CHECK(ZonaOrigenKey BETWEEN 1 AND 263 AND ZonaDestinoKey BETWEEN 1 AND 263));
IF OBJECT_ID('dbo.CuarentenaViaje','U') IS NULL
CREATE TABLE dbo.CuarentenaViaje (
 ArchivoKey int NOT NULL,FilaOrigen bigint NOT NULL,Motivos varchar(300) NOT NULL,
 CONSTRAINT PK_Cuarentena PRIMARY KEY(ArchivoKey,FilaOrigen),
 CONSTRAINT FK_CuarentenaArchivo FOREIGN KEY(ArchivoKey) REFERENCES dbo.AuditoriaArchivo(ArchivoKey));
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_Fact_FechaOrigen' AND object_id=OBJECT_ID('dbo.FactViaje'))
 CREATE INDEX IX_Fact_FechaOrigen ON dbo.FactViaje(FechaKey,ZonaOrigenKey)
 INCLUDE(ImporteTotalUSD,DuracionSegundos,DistanciaMillas);
GO
-- Calendario 2024, completo y sin dependencia de SET DATEFIRST.
;WITH n AS(SELECT 0 AS i UNION ALL SELECT i+1 FROM n WHERE i<365),
d AS(SELECT DATEADD(day,i,CONVERT(date,'20240101')) AS f FROM n)
INSERT dbo.DimFecha(FechaKey,Fecha,Anio,Trimestre,Mes,Dia,DiaSemanaISO)
SELECT CONVERT(int,CONVERT(char(8),f,112)),f,YEAR(f),DATEPART(quarter,f),MONTH(f),DAY(f),
 ((DATEDIFF(day,CONVERT(date,'19000101'),f)%7)+7)%7+1
FROM d WHERE NOT EXISTS(SELECT 1 FROM dbo.DimFecha x WHERE x.Fecha=d.f)
OPTION(MAXRECURSION 366);
;WITH n AS(SELECT 0 AS h UNION ALL SELECT h+1 FROM n WHERE h<23)
INSERT dbo.DimHora(HoraKey,Franja)
SELECT h,CASE WHEN h<6 THEN 'Madrugada' WHEN h<12 THEN 'Manana' WHEN h<18 THEN 'Tarde' ELSE 'Noche' END
FROM n WHERE NOT EXISTS(SELECT 1 FROM dbo.DimHora x WHERE x.HoraKey=n.h);
IF NOT EXISTS(SELECT 1 FROM dbo.DimZona WHERE ZonaKey=0)
 INSERT dbo.DimZona VALUES(0,N'Desconocido',N'Desconocido',NULL);
INSERT dbo.DimPago(PagoKey,Descripcion)
SELECT v.k,v.d FROM (VALUES(-1,N'No catalogado'),(0,N'Flex Fare'),(1,N'Tarjeta'),(2,N'Efectivo'),(3,N'Sin cargo'),(4,N'Disputa'),(5,N'Desconocido'),(6,N'Anulado'))v(k,d)
WHERE NOT EXISTS(SELECT 1 FROM dbo.DimPago t WHERE t.PagoKey=v.k);
INSERT dbo.DimTarifa(TarifaKey,Descripcion)
SELECT v.k,v.d FROM (VALUES(-1,N'Nulo / no catalogado'),(1,N'Estandar'),(2,N'JFK'),(3,N'Newark'),(4,N'Nassau / Westchester'),(5,N'Negociada'),(6,N'Grupo'),(99,N'Desconocido'))v(k,d)
WHERE NOT EXISTS(SELECT 1 FROM dbo.DimTarifa t WHERE t.TarifaKey=v.k);
INSERT dbo.DimProveedor(ProveedorKey,Descripcion)
SELECT v.k,v.d FROM (VALUES(-1,N'No catalogado'),(1,N'Creative Mobile Technologies'),(2,N'Curb Mobility'),(6,N'Myle Technologies'),(7,N'Helix'))v(k,d)
WHERE NOT EXISTS(SELECT 1 FROM dbo.DimProveedor t WHERE t.ProveedorKey=v.k);
GO
CREATE OR ALTER VIEW dbo.vw_DimZonaOrigen AS SELECT * FROM dbo.DimZona;
GO
CREATE OR ALTER VIEW dbo.vw_DimZonaDestino AS SELECT * FROM dbo.DimZona;
GO
CREATE OR ALTER VIEW dbo.vw_ActividadMensual AS
 SELECT d.Anio,d.Mes,COUNT_BIG(*) AS Viajes,SUM(f.ImporteTotalUSD) AS ImporteUSD,
 AVG(CONVERT(decimal(18,4),f.DuracionSegundos))/60 AS DuracionMediaMin
 FROM dbo.FactViaje f JOIN dbo.DimFecha d ON f.FechaKey=d.FechaKey GROUP BY d.Anio,d.Mes;
GO
IF DATABASE_PRINCIPAL_ID('rol_bi_lectura') IS NULL CREATE ROLE rol_bi_lectura;
GRANT SELECT ON dbo.FactViaje TO rol_bi_lectura;
GRANT SELECT ON dbo.DimFecha TO rol_bi_lectura;
GRANT SELECT ON dbo.DimHora TO rol_bi_lectura;
GRANT SELECT ON dbo.vw_DimZonaOrigen TO rol_bi_lectura;
GRANT SELECT ON dbo.vw_DimZonaDestino TO rol_bi_lectura;
GRANT SELECT ON dbo.DimPago TO rol_bi_lectura;
GRANT SELECT ON dbo.DimTarifa TO rol_bi_lectura;
GRANT SELECT ON dbo.DimProveedor TO rol_bi_lectura;
GRANT SELECT ON dbo.AuditoriaArchivo TO rol_bi_lectura;
GO
