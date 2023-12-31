﻿BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'1APS_BackupStored Proc', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'Job Failure Notification', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'backupstoredproc', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @sql nvarchar(max),@proc varchar(400) 
DECLARE @Name varchar(100)=''BMSOnelook_AUTODATAPROCESS'' 
 DECLARE c CURSOR FOR  
  SELECT   
        pr.name+''_BAK'' as SP_Name,replace(mod.definition,pr.name,pr.name+''_BAK'') as Def
FROM [Master].sys.procedures pr 
INNER JOIN [Master].sys.sql_modules mod ON pr.object_id = mod.object_id 
WHERE pr.Is_MS_Shipped = 0 AND pr.name LIKE ''%sp_createweekly%'' 
 
OPEN c 
 
FETCH NEXT FROM c INTO @proc, @sql 
 
WHILE @@FETCH_STATUS = 0  
BEGIN 
 
   if exists( Select 1 from BMSOnelook_AUTODATAPROCESS.sys.procedures where [name]=@proc)
   BEGIN 
   print ''alter  proc''
   SET @sql = REPLACE(replace(@sql,''CREATE PROCEDURE'',''ALTER PROCEDURE''),'''''''','''''''''''')
   --SET    @sql =REPLACE(@sql,''CREATE  PROCEDURE'',''ALTER  PROCEDURE'')
   ---print @sql
   SET @sql = ''USE ['' + @Name + '']; EXEC('''''' + @sql + '''''')'' 
 
   EXEC(@sql) 
   END
   ELSE
   if not exists( Select 1 from BMSOnelook_AUTODATAPROCESS.sys.procedures where [name]=@proc)
   BEGIN 
   print ''create  proc''
   SET @sql = REPLACE(@sql,'''''''','''''''''''')
   --SET    @sql =REPLACE(@sql,''CREATE  PROCEDURE'',''ALTER  PROCEDURE'')
  -- print @sql
   SET @sql = ''USE ['' + @Name + '']; EXEC('''''' + @sql + '''''')'' 
 
   EXEC(@sql) 
   END
 
   FETCH NEXT FROM c INTO  @proc, @sql 
END              
 
CLOSE c 
DEALLOCATE c 


-----------------------------------------------
 
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'BAckp Stored Proc in master to autodataprocess', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20200724, 
		@active_end_date=99991231, 
		@active_start_time=90001, 
		@active_end_time=235959, 
		@schedule_uid=N'0c5e643a-3d03-47f2-b0b5-c2408dde13fc'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

