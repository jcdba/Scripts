DECLARE @query VARCHAR(MAX) = ''

SELECT
    @query = COALESCE(@query, ',') + 'KILL ' + CONVERT(VARCHAR, spid) + '; '
FROM
    master..sysprocesses
WHERE
    dbid = DB_ID('ab_renfix') -- Nome do database
    AND dbid > 4 -- N�o eliminar sess�es em databases de sistema
    AND spid <> '331' -- N�o eliminar a sua pr�pria sess�o


IF (LEN(@query) > 0)
    EXEC(@query)
