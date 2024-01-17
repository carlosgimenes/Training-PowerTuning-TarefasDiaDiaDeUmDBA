/*******************************************************************************************************************************
(C) 2015, Fabr�cio Lima Solu��es em Banco de Dados

Site: http://www.fabriciolima.net/

Feedback: contato@fabriciolima.net
*******************************************************************************************************************************/

/*******************************************************************************************************************************
--	OBS:	Sempre utilizo uma database chamada "Traces" para a cria��o de rotinas administrativas
*******************************************************************************************************************************/

use Traces

--------------------------------------------------------------------------------------------------------------------------------
--	Cria��o das tabelas que v�o armazenar o nome das databases, servidores(caso queira fazer um reposit�rio central) e tabelas.
--------------------------------------------------------------------------------------------------------------------------------
if object_id('BaseDados') is not null
	drop table BaseDados
CREATE TABLE [dbo].[BaseDados](
	[Id_BaseDados] [int] IDENTITY(1,1) NOT NULL,
	[Nm_Database] [varchar](100) NULL
	 CONSTRAINT [PK_BaseDados] PRIMARY KEY CLUSTERED (Id_BaseDados)

) ON [PRIMARY]

if object_id('Tabela') is not null
	drop table Tabela

CREATE TABLE [dbo].[Tabela](
	[Id_Tabela] [int] IDENTITY(1,1) NOT NULL,
	[Nm_Tabela] [varchar](1000) NULL,
 CONSTRAINT [PK_Tabela] PRIMARY KEY CLUSTERED 
(
	[Id_Tabela] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

if object_id('Servidor') is not null
	drop table Servidor

	CREATE TABLE [dbo].[Servidor](
	[Id_Servidor] [int] IDENTITY(1,1) NOT NULL,
	[Nm_Servidor] [varchar](50) NOT NULL,
 CONSTRAINT [PK_Servidor] PRIMARY KEY CLUSTERED 
(
	[Id_Servidor] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]


--------------------------------------------------------------------------------------------------------------------------------
--	Cria��o da tabela que vai armazenar um hist�rico da fragmenta��o dos �ndices.
--------------------------------------------------------------------------------------------------------------------------------
if object_id('Historico_Fragmentacao_Indice') is not null
	drop table Historico_Fragmentacao_Indice

CREATE TABLE Historico_Fragmentacao_Indice(
	[Id_Hitorico_Fragmentacao_Indice] [int] IDENTITY(1,1) NOT NULL,
	[Dt_Referencia] [datetime] NULL,
	[Id_Servidor] [smallint] NULL,
	[Id_BaseDados] [smallint] NULL,
	[Id_Tabela] [int] NULL,
	[Nm_Indice] [varchar](1000) NULL,
	Nm_Schema varchar(50),
	[Avg_Fragmentation_In_Percent] [numeric](5, 2) NULL,
	[Page_Count] [int] NULL,
	[Fill_Factor] [tinyint] NULL,
	[Fl_Compressao] [tinyint] NULL
) ON [PRIMARY]


--------------------------------------------------------------------------------------------------------------------------------
--	Cria��o de uma VIEW para facilitar a visualiza��o da das informa��es de fragmenta��o dos �ndices
--------------------------------------------------------------------------------------------------------------------------------
if object_id('vwHistorico_Fragmentacao_Indice') is not null
	drop View vwHistorico_Fragmentacao_Indice
GO
create view vwHistorico_Fragmentacao_Indice
AS
select A.Dt_Referencia, B.Nm_Servidor, C.Nm_Database,D.Nm_Tabela ,A.Nm_Indice, A.Nm_Schema, 
	A.Avg_Fragmentation_In_Percent, A.Page_Count, A.Fill_Factor, A.Fl_Compressao
from Historico_Fragmentacao_Indice A
	join Servidor B on A.Id_Servidor = B.Id_Servidor
	join BaseDados C on A.Id_BaseDados = C.Id_BaseDados
	join Tabela D on A.Id_Tabela = D.Id_Tabela
GO

--------------------------------------------------------------------------------------------------------------------------------
--	Cria��o da procedure que vai verificar a fragmenta��o dos �ndices e armazenar nas tabelas anteriores
--------------------------------------------------------------------------------------------------------------------------------
if object_id('stpCarga_Fragmentacao_Indice') is not null
	drop procedure stpCarga_Fragmentacao_Indice
GO

CREATE procedure [dbo].[stpCarga_Fragmentacao_Indice]
AS
BEGIN
	SET NOCOUNT ON
	 
	
	IF object_id('tempdb..##Historico_Fragmentacao_Indice') IS NOT NULL DROP TABLE ##Historico_Fragmentacao_Indice
	
	CREATE TABLE ##Historico_Fragmentacao_Indice(
		[Id_Hitorico_Fragmentacao_Indice] [int] IDENTITY(1,1) NOT NULL,
		[Dt_Referencia] [datetime] NULL,
		[Nm_Servidor] VARCHAR(50) NULL,
		[Nm_Database] VARCHAR(100) NULL,
		[Nm_Tabela] VARCHAR(1000) NULL,
		[Nm_Indice] [varchar](1000) NULL,
		Nm_Schema varchar(50),
		[Avg_Fragmentation_In_Percent] [numeric](5, 2) NULL,
		[Page_Count] [int] NULL,
		[Fill_Factor] [tinyint] NULL,
		[Fl_Compressao] [tinyint] NULL
	) ON [PRIMARY]

 
	EXEC sp_MSforeachdb 'Use [?]; 
	declare @Id_Database int 
	set @Id_Database = db_id()
	insert into ##Historico_Fragmentacao_Indice
	select getdate(), @@servername Nm_Servidor,  DB_NAME(db_id()) Nm_Database, D.Name Nm_Tabela,  B.Name Nm_Indice,F.name Nm_Schema, avg_fragmentation_in_percent,
	page_Count,fill_factor,data_compression	
		from sys.dm_db_index_physical_stats(@Id_Database,null,null,null,null) A
			join sys.indexes B on A.object_id = B.Object_id and A.index_id = B.index_id
            JOIN sys.partitions C ON C.object_id = B.object_id AND C.index_id = B.index_id
            JOIN sys.sysobjects D ON A.object_id = D.id
                join sys.objects E on D.id = E.object_id
            join  sys.schemas F on E.schema_id = F.schema_id
            '
    -- select * from ##Historico_Fragmentacao_Indice

    DELETE FROM ##Historico_Fragmentacao_Indice
    WHERE Nm_Database IN ('master','msdb','tempdb')
    
    INSERT INTO Traces.dbo.Servidor(Nm_Servidor)
	SELECT DISTINCT A.Nm_Servidor 
	FROM ##Historico_Fragmentacao_Indice A
		LEFT JOIN Traces.dbo.Servidor B ON A.Nm_Servidor = B.Nm_Servidor
	WHERE B.Nm_Servidor IS null
		
	INSERT INTO Traces.dbo.BaseDados(Nm_Database)
	SELECT DISTINCT A.Nm_Database 
	FROM ##Historico_Fragmentacao_Indice A
		LEFT JOIN Traces.dbo.BaseDados B ON A.Nm_Database = B.Nm_Database
	WHERE B.Nm_Database IS null
	
	INSERT INTO Traces.dbo.Tabela(Nm_Tabela)
	SELECT DISTINCT A.Nm_Tabela 
	FROM ##Historico_Fragmentacao_Indice A
		LEFT JOIN Traces.dbo.Tabela B ON A.Nm_Tabela = B.Nm_Tabela
	WHERE B.Nm_Tabela IS null	
	
    INSERT INTO Traces..Historico_Fragmentacao_Indice(Dt_Referencia,Id_Servidor,Id_BaseDados,Id_Tabela,Nm_Indice,Nm_Schema,Avg_Fragmentation_In_Percent,
			Page_Count,Fill_Factor,Fl_Compressao)	
    SELECT A.Dt_Referencia,E.Id_Servidor, D.Id_BaseDados,C.Id_Tabela,A.Nm_Indice,A.Nm_Schema,A.Avg_Fragmentation_In_Percent,A.Page_Count,A.Fill_Factor,A.Fl_Compressao 
    FROM ##Historico_Fragmentacao_Indice A 
    	JOIN Traces.dbo.Tabela C ON A.Nm_Tabela = C.Nm_Tabela
		JOIN Traces.dbo.BaseDados D ON A.Nm_Database = D.Nm_Database
		JOIN Traces.dbo.Servidor E ON A.Nm_Servidor = E.Nm_Servidor 
    	LEFT JOIN Historico_Fragmentacao_Indice B ON E.Id_Servidor = B.Id_Servidor AND D.Id_BaseDados = B.Id_BaseDados  
    													AND C.Id_Tabela = B.Id_Tabela AND A.Nm_Indice = B.Nm_Indice 
    													AND CONVERT(VARCHAR, A.Dt_Referencia ,112) = CONVERT(VARCHAR, B.Dt_Referencia ,112)
	WHERE A.Nm_Indice IS NOT NULL AND B.Id_Hitorico_Fragmentacao_Indice IS NULL
    ORDER BY 2,3,4,5        			
end