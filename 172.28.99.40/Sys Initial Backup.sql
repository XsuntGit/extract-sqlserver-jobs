BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Sys_Initial_Backup', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Sys_Initial_Backup', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @dbname NVARCHAR(255)
DECLARE NewDBs CURSOR FAST_FORWARD LOCAL READ_ONLY FOR
SELECT d.name FROM sys.databases d
LEFT JOIN msdb.dbo.backupset b
    ON b.database_name = d.name
WHERE b.database_name IS NULL
	AND d.name NOT IN (''tempdb'')
OPEN NewDBs
FETCH NEXT FROM NewDBs INTO @dbname
WHILE @@FETCH_STATUS=0 
BEGIN
	EXEC [XsuntAdmin].[dbo].[sys_database_backup]
		@Databases = @dbname,
		@Directory = ''\\172.25.99.17\pa-bms-bck\DR-ONELOOK-DB'',
		@BackupType = ''FULL'',
		@Compress = ''Y'',
		@DatabasesInParallel = ''Y'',
		@NumberOfFiles = 10,
		@MinBackupSizeForMultipleFiles = 100000,
		@BlockSize = 65536,
		@MaxTransferSize = 4194304,
		@LogToTable = ''Y'',
		@Execute = ''Y''
	FETCH NEXT FROM NewDBs INTO @dbname
END
CLOSE NewDBs
DEALLOCATE NewDBs
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

