CREATE PROC dbo.sp_FindEFCorePlan
	@QueryText AS VARCHAR(MAX)
AS
/*
	For more info about DMVs see: 
		https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-query-plan-transact-sql?view=sql-server-ver15
	
	EXEC dbo.sMaint_FindEFCorePlan @QueryText='%Users%'
*/
BEGIN

DECLARE @DatabaseName AS NVARCHAR(128) = DB_NAME(),
	    @ResultCount AS INT = 0;

SELECT 
	SqlHandle = qs.[sql_handle], 
	[Text] = st.[text], 
	CreationDateTime = qs.creation_time, 
	ExecutionCnt = qs.execution_count,
	[Avg Duration (ms)]= CAST(ROUND((qs.total_elapsed_time / 1000.0) / qs.execution_count, 2) AS DECIMAL(18,2)),
	MoreInfo = 'EXEC dbo.sp_BlitzCache @DatabaseName=''' + @DatabaseName + ''', @OnlySqlHandles=''' + CONVERT(VARCHAR(MAX), qs.[sql_handle], 1) + ''''
INTO #sql_handles
FROM sys.dm_exec_cached_plans cp
CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) st
CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
JOIN sys.dm_exec_query_stats qs ON qs.plan_handle = cp.plan_handle
WHERE 1=1 
	AND st.[text] LIKE @QueryText
	AND cp.objtype= 'Prepared'
	AND DB_NAME(st.[dbid]) = @DatabaseName
	AND st.[text] NOT LIKE '%dm_exec_cached_plans%'
	AND st.[text] NOT LIKE '%##BlitzCacheProcs%'

SELECT @ResultCount = COUNT(*) FROM #sql_handles

IF @ResultCount = 0
BEGIN 
	SELECT Result = 'No plans found.'
END
ELSE IF @ResultCount = 1
BEGIN
	DECLARE @SqlHandle AS VARCHAR(MAX)
	SELECT @SqlHandle = CONVERT(VARCHAR(MAX), sh.SqlHandle, 1) FROM #sql_handles AS sh
	SELECT [Executing...] = 'EXEC dbo.sp_BlitzCache @DatabaseName=''' + @DatabaseName + ''', @OnlySqlHandles=''' + @SqlHandle + ''''
	EXEC dbo.sp_BlitzCache @DatabaseName=@DatabaseName, @OnlySqlHandles=@SqlHandle
END
ELSE 
BEGIN
	SELECT Result = 'More than 1 plan found. Try adding more text to your search so that only 1 plan is found.'
	SELECT sh.[Text],
           sh.CreationDateTime,
           sh.ExecutionCnt,
           sh.[Avg Duration (ms)],
           sh.MoreInfo 
	FROM #sql_handles AS sh 
	ORDER BY sh.ExecutionCnt DESC
END 

DROP TABLE #sql_handles

END

GO
