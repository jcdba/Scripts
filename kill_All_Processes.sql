DECLARE @query VARCHAR(MAX) = ''

SELECT
    @query = COALESCE(@query, ',') + 'KILL ' + CONVERT(VARCHAR, r.session_id) + '; '
FROM sys.dm_exec_requests r
JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE 
	r.database_id = DB_ID('DW') -- FILTRA BANCO
	AND s.login_name = 'automacao' -- FILTRA USUARIO
	AND DATEDIFF(MINUTE, r.start_time, GETDATE()) > 10 -- FILTRA TEMPO DE EXECUÇÃO EX: +10 MINUTOS
ORDER BY r.start_time;


IF (LEN(@query) > 0)
    EXEC(@query)

