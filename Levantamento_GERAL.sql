PRINT N'MAX MEMORY INSTANCE'
GO
SELECT name, value FROM sys.configurations where name = 'max server memory (MB)' 
go
PRINT N'AFFINITY MASK'
GO
SELECT name, value FROM sys.configurations where name = 'affinity mask'
go
PRINT N'MAXDOP'
GO
SELECT name, value FROM sys.configurations where name = 'max degree of parallelism'
go
PRINT N'CTFP'
GO
SELECT name, value FROM sys.configurations where name = 'cost threshold for parallelism'
go

--MONTA TABELA COM DADOS DOS DATABASES, ***DROP NO FINAL***
SELECT database_id,
 CONVERT(VARCHAR(25), DB.name) AS dbName,
 CONVERT(VARCHAR(10), DATABASEPROPERTYEX(name, 'status')) AS [Status],
 state_desc,
 collation_name,
 (SELECT COUNT(1) FROM sys.master_files WHERE DB_NAME(database_id) = DB.name AND type_desc = 'rows') AS DataFiles,
 (SELECT SUM((size*8)/1024) FROM sys.master_files WHERE DB_NAME(database_id) = DB.name AND type_desc = 'rows') AS [Data MB],
 (SELECT COUNT(1) FROM sys.master_files WHERE DB_NAME(database_id) = DB.name AND type_desc = 'log') AS LogFiles,
 (SELECT SUM((size*8)/1024) FROM sys.master_files WHERE DB_NAME(database_id) = DB.name AND type_desc = 'log') AS [Log MB],
 user_access_desc AS [User access],
 recovery_model_desc AS [Recovery model],
 CASE compatibility_level
 WHEN 60 THEN '60 (SQL Server 6.0)'
 WHEN 65 THEN '65 (SQL Server 6.5)'
 WHEN 70 THEN '70 (SQL Server 7.0)'
 WHEN 80 THEN '80 (SQL Server 2000)'
 WHEN 90 THEN '90 (SQL Server 2005)'
 WHEN 100 THEN '100 (SQL Server 2008)'
 WHEN 110 THEN '110 (SQL Server 2012)'
 WHEN 120 THEN '120 (SQL Server 2014)'
 WHEN 130 THEN '130 (SQL Server 2016)'
 END AS [compatibility level],
 CONVERT(VARCHAR(20), create_date, 103) + ' ' + CONVERT(VARCHAR(20), create_date, 108) AS [Creation date],
 -- last backup
 ISNULL((SELECT TOP 1
 CASE type WHEN 'D' THEN 'Full' WHEN 'I' THEN 'Differential' WHEN 'L' THEN 'Transaction log' END + ' � ' +
 LTRIM(ISNULL(STR(ABS(DATEDIFF(DAY, GETDATE(),backup_finish_date))) + ' days ago', 'NEVER')) + ' � ' +
 CONVERT(VARCHAR(20), backup_start_date, 103) + ' ' + CONVERT(VARCHAR(20), backup_start_date, 108) + ' � ' +
 CONVERT(VARCHAR(20), backup_finish_date, 103) + ' ' + CONVERT(VARCHAR(20), backup_finish_date, 108) +
 ' (' + CAST(DATEDIFF(second, BK.backup_start_date,
 BK.backup_finish_date) AS VARCHAR(4)) + ' '
 + 'seconds)'
 FROM msdb..backupset BK WHERE BK.database_name = DB.name ORDER BY backup_set_id DESC),'-') AS [Last backup],
 CASE WHEN is_fulltext_enabled = 1 THEN 'Fulltext enabled' ELSE '' END AS [fulltext],
 CASE WHEN is_auto_close_on = 1 THEN 'autoclose' ELSE '' END AS [autoclose],
 page_verify_option_desc AS [page verify option],
 CASE WHEN is_read_only = 1 THEN 'read only' ELSE '' END AS [read only],
 CASE WHEN is_auto_shrink_on = 1 THEN 'autoshrink' ELSE '' END AS [autoshrink],
 CASE WHEN is_auto_create_stats_on = 1 THEN 'auto create statistics' ELSE '' END AS [auto create statistics],
 CASE WHEN is_auto_update_stats_on = 1 THEN 'auto update statistics' ELSE '' END AS [auto update statistics],
 CASE WHEN is_in_standby = 1 THEN 'standby' ELSE '' END AS [standby],
 CASE WHEN is_cleanly_shutdown = 1 THEN 'cleanly shutdown' ELSE '' END AS [cleanly shutdown]
 into #DATABASES_DADOS
 FROM sys.databases DB
 ORDER BY 7 desc--dbName, [Last backup] DESC, NAME

PRINT N'TAMANHO TEMPDB INSTANCE'
GO
SELECT UPPER(dbName)AS DBNAME, [Data MB] from #DATABASES_DADOS where dbname = 'tempdb'
GO

PRINT N'TAMANHO TODAS AS BASES INSTANCE'
GO
SELECT SUM([Data MB]) AS DATABASES_MB from #DATABASES_DADOS
GO

PRINT N'COLLATION BASES INSTANCE'
GO
SELECT UPPER(dbName) AS DBANAME, collation_name from #DATABASES_DADOS
GO

PRINT N'COLLATION INSTANCE'
GO
SELECT SERVERPROPERTY('collation') AS SQL_COLLATION_INSTANCE
GO

PRINT N'VERSÃO E EDIÇÃO'
GO
SELECT @@VERSION
GO

PRINT N'QUANTIDADE DE BASES POR INSTANCE'
GO
SELECT COUNT(*) AS QUANTIDADE_DATABASES from #DATABASES_DADOS
GO

PRINT N'TAMANHO DATABASES INSTANCE'
GO
SELECT UPPER(dbName)AS DBNAME, [Data MB] from #DATABASES_DADOS where dbname <> 'tempdb' ORDER BY [Data MB] desc
GO

PRINT N'LANGUAGE DEFAULT'
GO
SELECT name, value FROM sys.configurations where name = 'default language' 
GO

--MONTA A TEMP TABLE
select DB_NAME() AS [DBNAME], feature_name, feature_id into #FEATURES from sys.dm_db_persisted_sku_features
GO
execute sp_msforeachdb '
    use [?]
    if db_id() not in (''0'')
        begin
		INSERT INTO #FEATURES
            select DB_NAME() AS [DBNAME] , * from sys.dm_db_persisted_sku_features
        end
    else
        print ''Backup do banco ? ignorado.'''		

PRINT N'FEATURE POR DATABASE'
GO
select DBNAME, FEATURE_NAME FROM #FEATURES ORDER BY DBNAME ASC
GO

PRINT N'DATABASES COM REPLICATION'
GO
select publisher_db as DATABASES_REPLICATIONS from distribution.dbo.MSdistribution_agents
union
select subscriber_db AS DATABASES_REPLICATIONS from distribution.dbo.MSdistribution_agents
GO

PRINT N'DATABASES COM CDC'
GO
SELECT NAME, IS_CDC_ENABLED FROM sys.databases WHERE is_cdc_enabled = 1
GO

PRINT N'FILESTREAM ACCESS LEVEL'
GO
SELECT NAME, VALUE FROM sys.configurations where name = 'filestream access level' 
GO

PRINT N'BUFFER POR DATABASE'
GO
SELECT
DB_NAME(database_id) AS DatabaseName, COUNT(*) AS cached_pages, (COUNT(*) * 8.0) / 1024 AS MBsInBufferPool
FROM sys.dm_os_buffer_descriptors GROUP BY database_id ORDER BY
DatabaseName DESC
GO

PRINT N'CPU POR DATABASE'
GO
WITH DB_CPU_Statistics
AS
(SELECT pa.DatabaseID, DB_NAME(pa.DatabaseID) AS [Database Name], SUM(qs.total_worker_time/1000) AS [CPU_Time_Ms]
FROM sys.dm_exec_query_stats AS qs WITH (NOLOCK)
CROSS APPLY (SELECT CONVERT(INT, value) AS [DatabaseID]
FROM sys.dm_exec_plan_attributes(qs.plan_handle)
WHERE attribute = N'dbid') AS pa
GROUP BY DatabaseID)
SELECT [Database Name], [CPU_Time_Ms] AS [CPU Time (ms)],
CAST([CPU_Time_Ms] * 1.0 / SUM([CPU_Time_Ms]) OVER() * 100.0 AS DECIMAL(5, 2)) AS [CPU Percent]
FROM DB_CPU_Statistics
ORDER BY [CPU Percent] DESC
GO

PRINT N'LISTA DE DATABASE NO AG'
GO
SELECT
AG.name AS [AvailabilityGroupName],
ISNULL(agstates.primary_replica, '') AS [PrimaryReplicaServerName],
ISNULL(arstates.role, 3) AS [LocalReplicaRole],
dbcs.database_name AS [DatabaseName],
ISNULL(dbrs.synchronization_state, 0) AS [SynchronizationState],
ISNULL(dbrs.is_suspended, 0) AS [IsSuspended],
ISNULL(dbcs.is_database_joined, 0) AS [IsJoined]
FROM master.sys.availability_groups AS AG
LEFT OUTER JOIN master.sys.dm_hadr_availability_group_states as agstates
   ON AG.group_id = agstates.group_id
INNER JOIN master.sys.availability_replicas AS AR
   ON AG.group_id = AR.group_id
INNER JOIN master.sys.dm_hadr_availability_replica_states AS arstates
   ON AR.replica_id = arstates.replica_id AND arstates.is_local = 1
INNER JOIN master.sys.dm_hadr_database_replica_cluster_states AS dbcs
   ON arstates.replica_id = dbcs.replica_id
LEFT OUTER JOIN master.sys.dm_hadr_database_replica_states AS dbrs
   ON dbcs.replica_id = dbrs.replica_id AND dbcs.group_database_id = dbrs.group_database_id
ORDER BY AG.name ASC, dbcs.database_name
GO

PRINT N'MODO ASSINCRONO E SICRONO AG'
GO

GO

PRINT N'SIM -> UTILIZA DTC'
GO

PRINT N'COMPATIBILIDADE LEVEL POR DATABASE'
GO
SELECT dbName, [compatibility level] FROM #DATABASES_DADOS ORDER BY DBNAME ASC
GO

PRINT N'TOP WAITS SERVIDOR'
GO
WITH [Waits] AS
    (SELECT
        [wait_type],
        [wait_time_ms] / 1000.0 AS [WaitS],
        ([wait_time_ms] - [signal_wait_time_ms]) / 1000.0 AS [ResourceS],
        [signal_wait_time_ms] / 1000.0 AS [SignalS],
        [waiting_tasks_count] AS [WaitCount],
        100.0 * [wait_time_ms] / SUM ([wait_time_ms]) OVER() AS [Percentage],
        ROW_NUMBER() OVER(ORDER BY [wait_time_ms] DESC) AS [RowNum]
    FROM sys.dm_os_wait_stats
    WHERE [wait_type] NOT IN (
        -- These wait types are almost 100% never a problem and so they are
        -- filtered out to avoid them skewing the results. Click on the URL
        -- for more information.
        N'BROKER_EVENTHANDLER', -- https://www.sqlskills.com/help/waits/BROKER_EVENTHANDLER
        N'BROKER_RECEIVE_WAITFOR', -- https://www.sqlskills.com/help/waits/BROKER_RECEIVE_WAITFOR
        N'BROKER_TASK_STOP', -- https://www.sqlskills.com/help/waits/BROKER_TASK_STOP
        N'BROKER_TO_FLUSH', -- https://www.sqlskills.com/help/waits/BROKER_TO_FLUSH
        N'BROKER_TRANSMITTER', -- https://www.sqlskills.com/help/waits/BROKER_TRANSMITTER
        N'CHECKPOINT_QUEUE', -- https://www.sqlskills.com/help/waits/CHECKPOINT_QUEUE
        N'CHKPT', -- https://www.sqlskills.com/help/waits/CHKPT
        N'CLR_AUTO_EVENT', -- https://www.sqlskills.com/help/waits/CLR_AUTO_EVENT
        N'CLR_MANUAL_EVENT', -- https://www.sqlskills.com/help/waits/CLR_MANUAL_EVENT
        N'CLR_SEMAPHORE', -- https://www.sqlskills.com/help/waits/CLR_SEMAPHORE
        N'CXCONSUMER', -- https://www.sqlskills.com/help/waits/CXCONSUMER
 
        -- Maybe comment these four out if you have mirroring issues
        N'DBMIRROR_DBM_EVENT', -- https://www.sqlskills.com/help/waits/DBMIRROR_DBM_EVENT
        N'DBMIRROR_EVENTS_QUEUE', -- https://www.sqlskills.com/help/waits/DBMIRROR_EVENTS_QUEUE
        N'DBMIRROR_WORKER_QUEUE', -- https://www.sqlskills.com/help/waits/DBMIRROR_WORKER_QUEUE
        N'DBMIRRORING_CMD', -- https://www.sqlskills.com/help/waits/DBMIRRORING_CMD
 
        N'DIRTY_PAGE_POLL', -- https://www.sqlskills.com/help/waits/DIRTY_PAGE_POLL
        N'DISPATCHER_QUEUE_SEMAPHORE', -- https://www.sqlskills.com/help/waits/DISPATCHER_QUEUE_SEMAPHORE
        N'EXECSYNC', -- https://www.sqlskills.com/help/waits/EXECSYNC
        N'FSAGENT', -- https://www.sqlskills.com/help/waits/FSAGENT
        N'FT_IFTS_SCHEDULER_IDLE_WAIT', -- https://www.sqlskills.com/help/waits/FT_IFTS_SCHEDULER_IDLE_WAIT
        N'FT_IFTSHC_MUTEX', -- https://www.sqlskills.com/help/waits/FT_IFTSHC_MUTEX
 
        -- Maybe comment these six out if you have AG issues
        N'HADR_CLUSAPI_CALL', -- https://www.sqlskills.com/help/waits/HADR_CLUSAPI_CALL
        N'HADR_FILESTREAM_IOMGR_IOCOMPLETION', -- https://www.sqlskills.com/help/waits/HADR_FILESTREAM_IOMGR_IOCOMPLETION
        N'HADR_LOGCAPTURE_WAIT', -- https://www.sqlskills.com/help/waits/HADR_LOGCAPTURE_WAIT
        N'HADR_NOTIFICATION_DEQUEUE', -- https://www.sqlskills.com/help/waits/HADR_NOTIFICATION_DEQUEUE
        N'HADR_TIMER_TASK', -- https://www.sqlskills.com/help/waits/HADR_TIMER_TASK
        N'HADR_WORK_QUEUE', -- https://www.sqlskills.com/help/waits/HADR_WORK_QUEUE
 
        N'KSOURCE_WAKEUP', -- https://www.sqlskills.com/help/waits/KSOURCE_WAKEUP
        N'LAZYWRITER_SLEEP', -- https://www.sqlskills.com/help/waits/LAZYWRITER_SLEEP
        N'LOGMGR_QUEUE', -- https://www.sqlskills.com/help/waits/LOGMGR_QUEUE
        N'MEMORY_ALLOCATION_EXT', -- https://www.sqlskills.com/help/waits/MEMORY_ALLOCATION_EXT
        N'ONDEMAND_TASK_QUEUE', -- https://www.sqlskills.com/help/waits/ONDEMAND_TASK_QUEUE
        N'PARALLEL_REDO_DRAIN_WORKER', -- https://www.sqlskills.com/help/waits/PARALLEL_REDO_DRAIN_WORKER
        N'PARALLEL_REDO_LOG_CACHE', -- https://www.sqlskills.com/help/waits/PARALLEL_REDO_LOG_CACHE
        N'PARALLEL_REDO_TRAN_LIST', -- https://www.sqlskills.com/help/waits/PARALLEL_REDO_TRAN_LIST
        N'PARALLEL_REDO_WORKER_SYNC', -- https://www.sqlskills.com/help/waits/PARALLEL_REDO_WORKER_SYNC
        N'PARALLEL_REDO_WORKER_WAIT_WORK', -- https://www.sqlskills.com/help/waits/PARALLEL_REDO_WORKER_WAIT_WORK
        N'PREEMPTIVE_XE_GETTARGETSTATE', -- https://www.sqlskills.com/help/waits/PREEMPTIVE_XE_GETTARGETSTATE
        N'PWAIT_ALL_COMPONENTS_INITIALIZED', -- https://www.sqlskills.com/help/waits/PWAIT_ALL_COMPONENTS_INITIALIZED
        N'PWAIT_DIRECTLOGCONSUMER_GETNEXT', -- https://www.sqlskills.com/help/waits/PWAIT_DIRECTLOGCONSUMER_GETNEXT
        N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP', -- https://www.sqlskills.com/help/waits/QDS_PERSIST_TASK_MAIN_LOOP_SLEEP
        N'QDS_ASYNC_QUEUE', -- https://www.sqlskills.com/help/waits/QDS_ASYNC_QUEUE
        N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',
            -- https://www.sqlskills.com/help/waits/QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP
        N'QDS_SHUTDOWN_QUEUE', -- https://www.sqlskills.com/help/waits/QDS_SHUTDOWN_QUEUE
        N'REDO_THREAD_PENDING_WORK', -- https://www.sqlskills.com/help/waits/REDO_THREAD_PENDING_WORK
        N'REQUEST_FOR_DEADLOCK_SEARCH', -- https://www.sqlskills.com/help/waits/REQUEST_FOR_DEADLOCK_SEARCH
        N'RESOURCE_QUEUE', -- https://www.sqlskills.com/help/waits/RESOURCE_QUEUE
        N'SERVER_IDLE_CHECK', -- https://www.sqlskills.com/help/waits/SERVER_IDLE_CHECK
        N'SLEEP_BPOOL_FLUSH', -- https://www.sqlskills.com/help/waits/SLEEP_BPOOL_FLUSH
        N'SLEEP_DBSTARTUP', -- https://www.sqlskills.com/help/waits/SLEEP_DBSTARTUP
        N'SLEEP_DCOMSTARTUP', -- https://www.sqlskills.com/help/waits/SLEEP_DCOMSTARTUP
        N'SLEEP_MASTERDBREADY', -- https://www.sqlskills.com/help/waits/SLEEP_MASTERDBREADY
        N'SLEEP_MASTERMDREADY', -- https://www.sqlskills.com/help/waits/SLEEP_MASTERMDREADY
        N'SLEEP_MASTERUPGRADED', -- https://www.sqlskills.com/help/waits/SLEEP_MASTERUPGRADED
        N'SLEEP_MSDBSTARTUP', -- https://www.sqlskills.com/help/waits/SLEEP_MSDBSTARTUP
        N'SLEEP_SYSTEMTASK', -- https://www.sqlskills.com/help/waits/SLEEP_SYSTEMTASK
        N'SLEEP_TASK', -- https://www.sqlskills.com/help/waits/SLEEP_TASK
        N'SLEEP_TEMPDBSTARTUP', -- https://www.sqlskills.com/help/waits/SLEEP_TEMPDBSTARTUP
        N'SNI_HTTP_ACCEPT', -- https://www.sqlskills.com/help/waits/SNI_HTTP_ACCEPT
        N'SP_SERVER_DIAGNOSTICS_SLEEP', -- https://www.sqlskills.com/help/waits/SP_SERVER_DIAGNOSTICS_SLEEP
        N'SQLTRACE_BUFFER_FLUSH', -- https://www.sqlskills.com/help/waits/SQLTRACE_BUFFER_FLUSH
        N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP', -- https://www.sqlskills.com/help/waits/SQLTRACE_INCREMENTAL_FLUSH_SLEEP
        N'SQLTRACE_WAIT_ENTRIES', -- https://www.sqlskills.com/help/waits/SQLTRACE_WAIT_ENTRIES
        N'WAIT_FOR_RESULTS', -- https://www.sqlskills.com/help/waits/WAIT_FOR_RESULTS
        N'WAITFOR', -- https://www.sqlskills.com/help/waits/WAITFOR
        N'WAITFOR_TASKSHUTDOWN', -- https://www.sqlskills.com/help/waits/WAITFOR_TASKSHUTDOWN
        N'WAIT_XTP_RECOVERY', -- https://www.sqlskills.com/help/waits/WAIT_XTP_RECOVERY
        N'WAIT_XTP_HOST_WAIT', -- https://www.sqlskills.com/help/waits/WAIT_XTP_HOST_WAIT
        N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG', -- https://www.sqlskills.com/help/waits/WAIT_XTP_OFFLINE_CKPT_NEW_LOG
        N'WAIT_XTP_CKPT_CLOSE', -- https://www.sqlskills.com/help/waits/WAIT_XTP_CKPT_CLOSE
        N'XE_DISPATCHER_JOIN', -- https://www.sqlskills.com/help/waits/XE_DISPATCHER_JOIN
        N'XE_DISPATCHER_WAIT', -- https://www.sqlskills.com/help/waits/XE_DISPATCHER_WAIT
        N'XE_TIMER_EVENT' -- https://www.sqlskills.com/help/waits/XE_TIMER_EVENT
        )
    AND [waiting_tasks_count] > 0
    )
SELECT
    MAX ([W1].[wait_type]) AS [WaitType],
    --CAST (MAX ([W1].[WaitS]) AS DECIMAL (16,2)) AS [Wait_S],
    --CAST (MAX ([W1].[ResourceS]) AS DECIMAL (16,2)) AS [Resource_S],
    --CAST (MAX ([W1].[SignalS]) AS DECIMAL (16,2)) AS [Signal_S],
    --MAX ([W1].[WaitCount]) AS [WaitCount],
    CAST (MAX ([W1].[Percentage]) AS DECIMAL (5,2)) AS [Percentage]
    --CAST ((MAX ([W1].[WaitS]) / MAX ([W1].[WaitCount])) AS DECIMAL (16,4)) AS [AvgWait_S],
    --CAST ((MAX ([W1].[ResourceS]) / MAX ([W1].[WaitCount])) AS DECIMAL (16,4)) AS [AvgRes_S],
    --CAST ((MAX ([W1].[SignalS]) / MAX ([W1].[WaitCount])) AS DECIMAL (16,4)) AS [AvgSig_S],
    --CAST ('https://www.sqlskills.com/help/waits/' + MAX ([W1].[wait_type]) as XML) AS [Help/Info URL]
FROM [Waits] AS [W1]
INNER JOIN [Waits] AS [W2] ON [W2].[RowNum] <= [W1].[RowNum]
GROUP BY [W1].[RowNum]
HAVING SUM ([W2].[Percentage]) - MAX( [W1].[Percentage] ) < 95; -- percentage threshold
GO

--DROP TABLE #FEATURES
--DROP TABLE #DATABASES_DADOS