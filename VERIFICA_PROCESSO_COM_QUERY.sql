--SCRIPT VERIFICA PROCESSO COM QUERY
SELECT session_id as SPID, DB_NAME(database_id) AS DBNAME, command, a.text AS Query, start_time, percent_complete, 
dateadd(second,estimated_completion_time/1000, getdate()) as estimated_completion_time 
FROM sys.dm_exec_requests r CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) a 
--where session_id in ('107')