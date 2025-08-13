BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'1APS_AfterRealeasedailyJOB', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'XSUNT\prateek.singh', 
		@notify_email_operator_name=N'Job Failure', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'run the daily for any new db', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'Use [Master]
 go

Declare @V_Sql nvarchar (4000) , @dbname nvarchar(4000) 

DECLARE Db_cursor CURSOR FOR
Select distinct ''exec [XsuntAdmin].[dbo].[Sys_BackupAllDatabases] ''''\\172.25.99.17\pa-bms-bck\DR-OneLook-DB'''', ''''full'''', @DatabaseList = ''''''+name+''''''''  as sql1
from (
			Select distinct name,create_date from sys.databases
			where create_date > (Select top 1  format(dt ,''yyyy-MM-dd 00:00:00.000'') 
			from  BMSONC_867..dimdate where 1=1-- WeekDayName=''Friday''
			and dt <= cast(getdate()  as date)
			order by 1 desc
			) and  (name like ''BMSKARX%'' OR NAME LIKE ''BMSNLJX%''   )   
  ) t1
					


OPEN Db_cursor
FETCH NEXT
FROM
      Db_cursor
INTO
      @dbname
 
WHILE @@FETCH_STATUS = 0
Begin
print @dbname
		set @V_SQL = @dbname
		 	print @V_SQL 
			EXEC  master.dbo.sp_executesql @V_SQL
 FETCH NEXT
FROM
      Db_cursor
INTO
      @dbname

End

CLOSE Db_cursor
DEALLOCATE Db_cursor
  declare @var varchar(max), @qry varchar(max)
 

SELECT @var = (
    SELECT ''fil like ''''%'' + name + ''_backup_'' + CAST(YEAR(GETDATE()) AS VARCHAR) + ''_'' + 
           RIGHT(''00'' + CAST(MONTH(GETDATE()) AS VARCHAR), 2) + ''_'' +
           RIGHT(''00'' + CAST(DAY(GETDATE()) AS VARCHAR), 2) + ''%full%'''''' AS [data()]
    FROM sys.databases
    WHERE create_date > (
        SELECT TOP 1 FORMAT(dt, ''yyyy-MM-dd 00:00:00.000'')
        FROM BMSONC_867..dimdate 
        WHERE 1=1--  WeekDayName = ''Friday''
        AND dt <= CAST(GETDATE() AS DATE)
        ORDER BY 1 DESC
    )
	  and  (name like ''BMSKARX%'' OR NAME LIKE ''BMSNLJX%''   )   
    FOR XML PATH(''''), TYPE
).value(''.'', ''VARCHAR(MAX)'')

-- Replace the first occurrence of "fil like" with nothing (empty string)
SET @var = STUFF(@var, 1, 8, '''')

-- Now replace all other occurrences with " OR fil like"
SET @var = REPLACE(@var, ''fil like'', '' OR fil like'')

-- Now @var contains the full condition
PRINT @var
-- You can use @var in your query as needed

  
  if OBJECT_ID (N''TempdB..##Listfiles222'') is not null drop table TempdB..##Listfiles222
  if OBJECT_ID (N''TempdB..##Listfiles333'') is not null drop table TempdB..##Listfiles333
  Create Table TempdB..##Listfiles222 ( Fil varchar(8000), depth int,fildep int) 
 	insert into TempdB..##Listfiles222 (Fil , depth, fildep)
	    EXEC master..xp_dirtree
		''\\172.25.99.17\pa-bms-bck\DR-OneLook-DB''
        , 0
        , 2

		set @qry=''Select SUBSTRING(fil,1,CHARINDEX(''''backup'''',fil)-2) as DB
		,''''\\172.25.99.17\pa-bms-bck\DR-OneLook-DB\''''+
		SUBSTRING(fil,1,CHARINDEX(''''backup'''',fil)-2)+''''\''''+
		fil as FileName into TempdB..##Listfiles333 from TempdB..##Listfiles222
		where ''+@var
		print @qry
		exec(@qry)

DECLARE @html nvarchar(MAX), @body1 Nvarchar(max) 
EXEC [master].[dbo].[spQueryToHtmlTable]  @html = @html OUTPUT,  @query = N''
		Select  Name,cast( create_date as date) create_date, t2.FileName
				from (
						Select distinct name,create_date from sys.databases
			where create_date > (Select top 1  format(dt ,''''yyyy-MM-dd 00:00:00.000'''') 
			from  BMSONC_867..dimdate where   dt <= cast(getdate()  as date)
			order by 1 desc
			) and  (name like ''''BMSKARX%'''' OR NAME LIKE ''''BMSNLJX%''''   )   
	

					) t1
		left join TempdB..##Listfiles333  t2 on t1.name=t2.db

'' ,@orderBy = N''ORDER BY 1'';
print @html

set @body1 = case when @html is null then ''No DB Weekly Backup Available <br> Regards </br>  DB Admin Team''
 else ''List of Databases weekly for current release  <br> <br> ''+@html + ''<br> Regards </br>  DB Admin Team'' end 
 


EXEC master.dbo.sys_sp_send_dbmail
    @profile_name = ''XSUNT DR-OneLook-DB NOTIFICATION'',
    @recipients = ''prateek.singh@xsunt.com'',
	@subject = ''List of Databases weekly for current release AND Everyday for Neuro, NLJX '',
    @body = @body1 ,
    @body_format = ''HTML'',
    @query_no_truncate = 1,
    @attach_query_result_as_file = 0;
	 
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'run daily early morning 9 AM', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=31, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20250414, 
		@active_end_date=99991231, 
		@active_start_time=90001, 
		@active_end_time=235959, 
		@schedule_uid=N'1a7f3e38-8475-4bb0-8642-2a244b40aa38'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

