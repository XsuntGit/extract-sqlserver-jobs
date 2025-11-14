BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'1APS_Monthly Extract for call activity 2ndwed', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'XSUNT\prateek.singh', 
		@notify_email_operator_name=N'Job Failure Notification', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'step1 for run callactivity mothly extract', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'use Test_Prateek
go



-- Step 1: Create your dynamic table name
DECLARE @WeekDate DATE = GETDATE();
DECLARE @TableName NVARCHAR(128) = ''tblCall_Data_Extract_HCP_ONC_HEME_ZEPMS_final_'' + FORMAT(@WeekDate, ''yyyyMMdd'');
DECLARE @SQL NVARCHAR(MAX);


SET @SQL = ''
IF OBJECT_ID(''''dbo.'' + @TableName + '''''', ''''U'''') IS NOT NULL
    DROP TABLE dbo.'' + QUOTENAME(@TableName) + '';

CREATE TABLE dbo.'' + QUOTENAME(@TableName) + '' (
	[HCPID] [varchar](20) NULL,
	[CallDate] [varchar](20) NULL,
	[BU] [nvarchar](255) NULL,
	[Brand] [nvarchar](255) NULL,
	[Indication] [nvarchar](255) NULL,
	[PSETID] [varchar](20) NULL,
	[CallEventID] [nvarchar](255) NULL,
	[RepID] [varchar](20) NULL,
	[TerritoryID] [varchar](20) NULL,
	[TerritoryCode] [nvarchar](255) NULL,
	[DistrictCode] [nvarchar](255) NULL,
	[RegionCode] [nvarchar](255) NULL,
	[Channel] [nvarchar](255) NULL,
	[SFTeamCode] [varchar](20) NULL,
	[SFTeamName] [nvarchar](255) NULL,
	[IVAFlag] [nvarchar](255) NULL,
	[SmartAlertFlag] [nvarchar](255) NULL,
	[SmartAlertName] [nvarchar](255) NULL,
	[CallPosition] [nvarchar](255) NULL,
	[PDE] [nvarchar](255) NULL
);'';

EXEC sp_executesql @SQL;

-- Step 3: Drop old synonym if exists and create new one
IF OBJECT_ID(''dbo.CurrentWeekTable_forcallactivityextract'', ''SN'') IS NOT NULL
    DROP SYNONYM dbo.CurrentWeekTable_forcallactivityextract;

SET @SQL = ''CREATE SYNONYM dbo.CurrentWeekTable_forcallactivityextract FOR dbo.'' + QUOTENAME(@TableName);
EXEC sp_executesql @SQL;

print '' table name : CurrentWeekTable_forcallactivityextract''

delete from CurrentWeekTable_forcallactivityextract
insert into CurrentWeekTable_forcallactivityextract
select DISTINCT  cast(cast( [HCPID] as bigint) as varchar) [HCPID]
     , cast( cast( cast([CallDate]  as int) as varchar) as date)   [CallDate]
	 
	      ,''HEM''[BU]
     
      ,[Brand]
      ,[Indication]
	   ,cast(cast([PSETID] as bigint) as varchar) [PSETID]
	     ,[CallEventID]
      ,[RepID]
      ,[TerritoryID]
      ,[TerritoryCode]
      ,[DistrictCode]
      ,[RegionCode]
      ,[Channel]
      ,[SFTeamCode]
      ,[SFTeamName]
     -- ,[PODName]
     -- ,[LunchLearnFlag]
      ,[IVAFlag]
      --,[TPOAlertFlag]
      --,[CE3AlertFlag]
      ,isnull( cast(cast( cast( case when  [SmartAlertFlag] =''-'' then null else  [SmartAlertFlag] end 
	  as varchar) as date) as varchar),''-'')  [SmartAlertFlag]
	  ,case when isnull( cast(cast( cast( case when  [SmartAlertFlag] =''-'' then null else  [SmartAlertFlag] end 
	  as varchar) as date) as varchar),''-'') <>''-'' then alert_name else ''-'' end [SmartAlertName]
      ,[CallPosition]
      ,[PDE] from BMSRDATA_CSCAN_TEMP_UAT_TEST .. CallActivity_AllBU_Extract T1
	  left join ( 
Select * from (
Select dense_rank() over (partition by CALL_EVENT_ID order by ALERT_START_DT,alert_name ) rk,
* from (
sELECT CALL_EVENT_ID,  T2.ALERT_START_DT ,  alert_name  FROM  BMSRData..DW_Analytics_Smart_Alert   t2  
inner join bmsheme3..tblSmartAlertProductMapping t5 on t2.BRAND_NAME = t5.brand_name 
and t2.INDICATION = t5.indication
JOIN (Select * from 
BMSHEME3.DBO.tblSmartAlertByActType_Proc

where Alert_Type in (''Call-Account'',''Call-HCP'' ) 
and Alert_start_dt >=''20240101''
and ( ACTNTYP_ALERT_EXEC_ONTIME=''Y'' OR ACTNTYP_ALERT_EXECUTION=''Y'')) T44 ON T44.alert_ID=T2.ALERT_ID
WHERE T5.Mkt=''MDS''
AND   T2.ALERT_START_DT >= ''20240101'' and T2.ALERT_TYPE=''Action'' 
and T2.TERRITORY_CD in (select distinct Terr from bmsheme3.. tblgeo) 
 AND BPID_Type = ''INDV'' and isnull(BP_Terr_Align_Flg,'''') = ''''
and ALERT_NAME not like ''%NBA%''
GROUP BY CALL_EVENT_ID  ,alert_name,T2.ALERT_START_DT ) t1 ) t1 where rk=1
 

)t5 on t5.CALL_EVENT_ID=T1.[CallEventID]  
	  where bu=''HEME''



---cobenfy

 insert into CurrentWeekTable_forcallactivityextract

 select DISTINCT  cast(cast( [HCPID] as bigint) as varchar) [HCPID]
    
      , cast( cast( cast([CallDate]  as int) as varchar) as date)   [CallDate]
	 
	      ,''Neuro''[BU]
     
      ,[Brand]
      ,''SCZ''[Indication]
	   ,[PSETID]
	     ,[CallEventID]
      ,[RepID]
      ,[TerritoryID]
      ,[TerritoryCode]
      ,[DistrictCode]
      ,[RegionCode]
      ,[Channel]
      ,[SFTeamCode]
      ,[SFTeamName]
     -- ,[PODName]
     -- ,[LunchLearnFlag]
      ,''N'' [IVAFlag]
      --,[TPOAlertFlag]
      --,[CE3AlertFlag]
	  , isnull(cast( [SmartAlertFlag] as varchar),''-'') [SmartAlertFlag]
   --   ,isnull( cast(cast( cast( case when  [SmartAlertFlag] =''-'' then null else  [SmartAlertFlag] end 
	  --as varchar) as date) as varchar),''-'')  [SmartAlertFlag]
	  ,case when SmartAlertFlag is not null then  ''SMART ALERT: ALERTS FOR NEW COBENFY WRITER'' else ''-'' end [SmartAlertName]
      ,[CallPosition]
      ,0.0000 [PDE]  from [onelook-db-dr-1]. BMSNEURO.dbo.CallActivity_AllBU_Extract_Cobenfy
 


 ----cv
  
  --select *from  [onelook-db-dr-1].BMSCV3.dbo.CallActivity_AllBU_Extract_CV  where smartalertflag is not null
 
  insert into CurrentWeekTable_forcallactivityextract
 Select DISTINCT  cast(cast( [HCPID] as bigint) as varchar) [HCPID]
    
      , cast( cast( cast([CallDate]  as int) as varchar) as date)   [CallDate]
	 
	      ,[BU]
     
      ,[Brand]
      ,''All'' [Indication]
	   ,[PSETID]
	     ,[CallEventID]
      ,[RepID]
      ,[TerritoryID]
      ,[TerritoryCode]
      ,[DistrictCode]
      ,[RegionCode]
      ,[Channel]
      ,[SFTeamCode]
      ,[SFTeamName]
     -- ,[PODName]
     -- ,[LunchLearnFlag]
      , [IVAFlag]
      --,[TPOAlertFlag]
      --,[CE3AlertFlag]
	  , isnull(cast( [SmartAlertFlag] as varchar),''-'') [SmartAlertFlag]
   --   ,isnull( cast(cast( cast( case when  [SmartAlertFlag] =''-'' then null else  [SmartAlertFlag] end 
	  --as varchar) as date) as varchar),''-'')  [SmartAlertFlag]
	  ,case when SmartAlertFlag is not null then  ''-'' else ''-'' end [SmartAlertName]
      ,[CallPosition]
      ,0.0000 [PDE]  from [onelook-db-dr-1].BMSCV3.dbo.CallActivity_AllBU_Extract_CV

-----------------------------------------------------
------------------------ onc
--	   --drop table  ##test_Call_extract

--Select distinct   t1.BPID,t1.CallDate,ISNULL(t2.PSetID,t22.PSetID)  psetid 
----, t22.PSetID PSETOID2
--, isnull(t7.Brands,CASE WHEN t1.Product_Orig  LIKE ''%SBQ_KEY_MSG%'' THEN ''O+Y QVANTIG'' -- ''O+Y QVANTIG-KEYMSG'' 
--WHEN t1.Product_Orig  =''OPDIVO+YERVOY CRC'' THEN ''CRC'' WHEN t1.Product_Orig  =''OPDIVO+YERVOY HCC'' THEN ''HCC''
--ELSE t1.Product_Orig  END ) as Brands 
----, t7.Indications as Indication_Mapping
-- ,t1.Product_Orig as Indications
--,CASE WHEN t1.Product_Orig  LIKE ''%SBQ_KEY_MSG%'' THEN ''All'' 
--WHEN t1.Product_Orig   =''OPDIVO+YERVOY CRC'' THEN ''CRC'' WHEN t1.Product_Orig  =''OPDIVO+YERVOY HCC'' THEN ''HCC''
--ELSE   t7.Indications  END Indication
--  , T1.Mkt 
--, t1.SaleRepID 
--, ISNULL( T2.OrigTerrID, T22.OrigTerrID ) OrigTerrID2
 
--,t1.Terr
--, left(t1.terr,4)+''0000'' as Distcode
--, left(t1.terr,2)+''000000'' as regcode
--, DC
--, SFA_Orig
--, t4.SFAName as sfteam
--, t4.TerrNameLong as podname
--, ''N'' as Lunlerflag
--, case when t6.interaction_id is not null then ''Y'' else ''N'' end IVAflag
--,''N'' tpoflag
--,''N'' ce3flag
--,CASE WHEN t5.CALL_EVENT_ID IS NOT NULL THEN T5.ALERT_START_DT ELSE ''-'' END SmartAlertFlag
--,CASE DtlPos_Final
--    WHEN   1 THEN ''PRIM''
--    WHEN   2 THEN ''SEC''
--    WHEN   3 THEN ''TERT''
--    WHEN   4 THEN ''QUART''
--    ELSE ''OTHER''  end as DtlPos_Final
--, CASE DtlPos_Final
--    WHEN   1 THEN 1
--    WHEN   2 THEN 0.5
--    WHEN   3 THEN 0.25
--    WHEN   4 THEN 0
--    ELSE 0 end PDE
--,''ONC'' AS BU
--, Itcn_ID
----,NULL Reach
--into ##test_Call_extract
--from BMSONC3  .. tblONCCallRaw_Proc T1
--LEFT JOIN   bmsrdata.. tblCallPresentation_Daily  t2 
--on T1.Itcn_ID=t2.CallEventID and T1.Product_Orig=t2.PSetDesc
--LEFT JOIN   bmsrdata.. tblCallPresentation_Daily  t22 
--on T1.Itcn_ID=t22.CallEventID and replace(t1.Product_Orig,''SBQ_KEY_MSG_'','''')=t22.PSetDesc
 
--left join BMSONC3  ..tblgeo t3 on t3.Terr=T1.Terr
--left join BMSRData_CSCAN  .. tblRosterIMP  t4 on t4.TerritoryCode=T1.Terr
--left join ( 
--sELECT CALL_EVENT_ID, MIN(ALERT_START_DT) ALERT_START_DT FROM  BMSRData..DW_Analytics_Smart_Alert   t2  
--inner join bmsonc3..tblSmartAlertProductMapping t5 on t2.BRAND_NAME = t5.brand_name 
--and t2.INDICATION = t5.indication
--WHERE T5.Mkt in (''NSC'',''RCC'',''UGI'',''KRS'',''BLA'', ''NPA'', ''UGA'', ''ROS'',''YER'',''CRC'',''HCC'')
--AND   ALERT_START_DT >= ''20240101'' and ALERT_TYPE=''Action'' 
--and TERRITORY_CD in (select distinct Terr from BMSONC3.. tblgeo) 
--AND BPID_Type = ''INDV'' and isnull(BP_Terr_Align_Flg,'''') = ''''
--  and t5.product not in(''Meso'' ,''BRAF'')  -- need to remove?
--and t2.alert_name not like ''%AIE ALERT:%''
--GROUP BY CALL_EVENT_ID
 
--) t5 on t5.CALL_EVENT_ID=T1.Itcn_ID  
---- Add IVA - 2025/05/09
--left join 
--(
--	select distinct interaction_id,prd_brd_nm from BMSRData_CSCAN..tblIVA_Calls 
--	where cast(duration as decimal(19,6)) between ''5'' and ''1800'' and presn_cald_dt_sk>=''20240101''
--) t6
--on t1.Itcn_ID = t6.interaction_id and t1.Product_Orig = t6.prd_brd_nm
--left join BMSONC3..CallActivity_Extract_BrandIndication_Mapping t7
--on t1.Product_Orig = t7.PSetDesc
--WHERE --t7.PSetDesc is not null
--t1.Mkt in (''NSC'',''RCC'',''UGI'',''KRS'',''BLA'', ''NPA'', ''UGA'', ''ROS'',''YER'',''CRC'',''HCC'', ''SBQ'')
--and isnull(t1.Mkt_Sub,'''') not in (''ROA'',''RTO'')
--AND T1.CallDate>=''20240101''
 
---- view result
--  --insert into CurrentWeekTable_forcallactivityextract
-- Select DISTINCT  cast(cast( [BPID] as bigint) as varchar) [HCPID]
    
--      , cast( cast( cast([CallDate]  as int) as varchar) as date)   [CallDate]
	 
--	      ,[BU]
     
--      , Brands [Brand]
--      , [Indication]
--	   ,[PSETID]
--	     , Itcn_ID  [CallEventID]
--      , SaleRepID  [RepID]
--      , OrigTerrID2 [TerritoryID]
--      , Terr [TerritoryCode]
--      ,Distcode [DistrictCode]
--      , regcode  [RegionCode]
--      ,DC [Channel]
--      ,SFA_Orig [SFTeamCode]
--      ,sfteam  [SFTeamName]
--     -- ,[PODName]
--     -- ,[LunchLearnFlag]
--      , [IVAFlag]
--      --,[TPOAlertFlag]
--      --,[CE3AlertFlag]
--	  --, isnull(cast( [SmartAlertFlag] as varchar),''-'') [SmartAlertFlag]
--      ,isnull( cast(cast( cast( case when  [SmartAlertFlag] =''-'' then null else  [SmartAlertFlag] end 
--	   as varchar) as date) as varchar),''-'')  [SmartAlertFlag]
--	  	  ,case when isnull( cast(cast( cast( case when  [SmartAlertFlag] =''-'' then null else  [SmartAlertFlag] end 
--	  as varchar) as date) as varchar),''-'') <>''-'' then alert_name else ''-'' end [SmartAlertName]
--      ,DtlPos_Final [CallPosition]
--      , [PDE]
--from ##test_Call_extract t1

--	  left join ( 
--Select * from (
--Select dense_rank() over (partition by CALL_EVENT_ID order by ALERT_START_DT,alert_name ) rk,
--* from (
--sELECT CALL_EVENT_ID,   ALERT_START_DT ,alert_name FROM  BMSRData..DW_Analytics_Smart_Alert   t2  
--inner join bmsonc3..tblSmartAlertProductMapping t5 on t2.BRAND_NAME = t5.brand_name 
--and t2.INDICATION = t5.indication
--WHERE T5.Mkt in (''NSC'',''RCC'',''UGI'',''KRS'',''BLA'', ''NPA'', ''UGA'', ''ROS'',''YER'',''CRC'',''HCC'')
--AND   ALERT_START_DT >= ''20240101'' and ALERT_TYPE=''Action'' 
--and TERRITORY_CD in (select distinct Terr from BMSONC3.. tblgeo) 
--AND BPID_Type = ''INDV'' and isnull(BP_Terr_Align_Flg,'''') = ''''
--  and t5.product not in(''Meso'' ,''BRAF'')  -- need to remove?
--and t2.alert_name not like ''%AIE ALERT:%''
--GROUP BY CALL_EVENT_ID,alert_name,ALERT_START_DT  ) t1 ) t1 where rk=1
 
--)t5 on t5.CALL_EVENT_ID=T1.[Itcn_ID]  
--where  cast(cast( [BPID] as bigint) as varchar)  <>''0''

------------------------------------------*************
-----************ONC2*****

INSERT INTO CurrentWeekTable_forcallactivityextract
select DISTINCT  cast(cast( [HCPID] as bigint) as varchar) [HCPID]
     , cast( cast( cast([CallDate]  as int) as varchar) as date)   [CallDate]
	 
	      ,''ONC''[BU]
     
      ,[Brand]
      ,[Indication]
	   ,cast(cast([PSETID] as bigint) as varchar) [PSETID]
	     ,[CallEventID]
      ,[RepID]
      ,[TerritoryID]
      ,[TerritoryCode]
      ,[DistrictCode]
      ,[RegionCode]
      ,[Channel]
      ,[SFTeamCode]
      ,[SFTeamName]
     -- ,[PODName]
     -- ,[LunchLearnFlag]
      ,[IVAFlag]
      --,[TPOAlertFlag]
      --,[CE3AlertFlag]
      ,isnull( cast(cast( cast( case when  [SmartAlertFlag] =''-'' then null else  [SmartAlertFlag] end 
	  as varchar) as date) as varchar),''-'')  [SmartAlertFlag]
	  ,case when isnull( cast(cast( cast( case when  [SmartAlertFlag] =''-'' then null else  [SmartAlertFlag] end 
	  as varchar) as date) as varchar),''-'') <>''-'' then alert_name else ''-'' end [SmartAlertName]
      ,[CallPosition]
      ,[PDE] from BMSRDATA_CSCAN_TEMP_UAT_TEST .. CallActivity_AllBU_Extract T1
	  left join ( 
Select * from (
Select dense_rank() over (partition by CALL_EVENT_ID order by ALERT_START_DT,alert_name ) rk,
* from (
sELECT CALL_EVENT_ID,  T2. ALERT_START_DT ,alert_name FROM  BMSRData..DW_Analytics_Smart_Alert   t2  
inner join bmsonc3..tblSmartAlertProductMapping t5 on t2.BRAND_NAME = t5.brand_name 
and t2.INDICATION = t5.indication

JOIN (
Select * from 
BMSONC3.DBO.tblSmartAlertByActType_Proc

where Alert_Type in (''Int HCPs – F2F'',''Account* – F2F'' ) 
and Alert_start_dt >=''20240101''
and ( ACTNTYP_ALERT_EXEC_ONTIME=''Y''  )
) T44 ON  T44.ALERT_ID=T2.ALERT_ID

WHERE T5.Mkt in (''NSC'',''RCC'',''UGI'',''KRS'',''BLA'', ''NPA'', ''UGA'', ''ROS'',''YER'',''CRC'',''HCC'')
AND   T2.ALERT_START_DT >= ''20240101'' and T2.ALERT_TYPE=''Action'' 
and T2.TERRITORY_CD in (select distinct Terr from BMSONC3.. tblgeo) 
AND BPID_Type = ''INDV'' and isnull(BP_Terr_Align_Flg,'''') = ''''
  and t5.product not in(''Meso'' ,''BRAF'')  -- need to remove?
and t2.alert_name not like ''%AIE ALERT:%''
GROUP BY CALL_EVENT_ID,alert_name,T2.ALERT_START_DT  ) t1 


) t1 where rk=1
 
)t5 on t5.CALL_EVENT_ID=T1.[CallEventID]  
where  cast(cast( T1.[HCPID] as bigint) as varchar)  <>''0''
	  AND  bu=''ONC''





 
-----Zeposia 


 
 
drop table Test_Prateek.. CallActivity_AllBU_Extract_zepms
go
SELECT a.BPID,CallDate,PSetID,PSetDesc,PSetDesc as psetdesc2 ,SaleRepID
,OrigTerrID as TerritoryID
,terr
,left(terr,4)+''0000'' Dist
,left(terr,2)+''000000'' Reg
,case when a.CallSubTypeCD = 9  then ''F2F''
       when a.CallSubTypeCD = 41  then ''Remote''
	   when a.CallSubTypeCD = 1  then ''Phone'' end Channel
,SFA,SFAName
,NULL POD
,case when ll.covr_rpnt_bp_id is not null  then ''Y'' else ''N'' end as  LunchLearnFlag
 ,case when i.interaction_id is not null then ''Y'' else ''N'' end IVAflag
 ,null as TPOAlertFlag
,null as CE3AlertFlag
 ,case when smt.CALL_EVENT_ID is not null then AlertDate else '' '' end as SmartAlertFlag
,AlertName
,a.CallType as CallPosition
,null as PDE
,''Zeposia'' as BU
,a.CallEventID
into Test_Prateek.. CallActivity_AllBU_Extract_zepms
FROM BMSRData_CSCAN.dbo.tblCallPresentation_daily A 
left join BMSRData_CSCAN.dbo.tblCallPresentation_Daily_KeyMsg b
on a.CallEventID = b.call_event_id_18 
inner join 
(select distinct SFCD as SFA,SFAName,terrID,territorycode as terr,TerrNameLong as TerrName 
from bmsrdata_cscan.dbo.tblRosterIMP
        where busUnit=''018'' and SFCD in (''403'',''404'',''405'',''406'')  
        ) t3
on  A.OrigTerrID=t3.terrid
left join (select distinct covr_rpnt_bp_id from bmsrdata_cscan..tblbmslunchlearn where pgm_dt>=''20240201'') ll
on a.BPID=ll.covr_rpnt_bp_id
left join ( 
	select distinct interaction_id,presentation_name,bms_id,key_message from BMSRData_CSCAN..tblIVA_Calls 
	where cast(duration as decimal(19,6)) between ''5'' and ''1800'' and presn_cald_dt_sk>=''20240903''
	) i
on CallEventID = i.interaction_id
left join (
				select distinct CALL_EVENT_ID, ALERT_START_DT as AlertDate, ALERT_NAME as AlertName from  bmsrdata_CSCAN..DW_ANALYTICS_SMART_ALERT_CSCAN where BRAND_NAME=''Zeposia'' and INDICATION=''Zeposia MS'' --and DATA_SOURCE_TYPE=''MS''
and Alert_Type=''Action'' --and isnull(BP_Terr_Align_Flg,'''')=''''    ---20220712change
and Alert_Name not like ''%AIE Alert%'' and ALERT_NAME <> ''Dynamic Targeting Alert: Upward Movement in Dynamic targeting tier''
and ( (Action_Type = ''FACE TO FACE'' and  BPID_Type =''INDV'' and isnull(ActnTyp_AFF_Ind,'''') in (''INDV'',''INDV_BY_POD'','''') )
		or
	  ( Action_Type = ''EMAIL'' and isnull(ActnTyp_AFF_Ind,'''') in (''INDV'',''INDV_BY_HCP'','''') ) 
	)
) smt
on a.CallEventID=smt.CALL_EVENT_ID
Where a.CallDate >= ''20240201'' and 
	a.CallDate <=(select WkDate from BMSZep_CSCAN..tblWeekList4Call where WkSeq =  1)
	--and left(a.CallDate,6)>=(select Month from tblMonthList4Call where MonSeq =  24)
	and (psetdesc like ''%Zeposia%'' or psetdesc=''NON-BRANDED ACTIVITY'')
	and a.CallType in (''Prim'') 
	and isnull(CallSubTypeCD,'''') not in (''2''/*,''36''*/)
	and ( b.key_msg_nm is null 
		or isnull(b.key_msg_nm,'''') not in (''NON-PRESCRIBER (OFFICE STAFF)'',''IN-OFFICE SPEAKER PROGRAM'',''MATERIAL WITHOUT DETAIL'',''SAMPLE WITHOUT DETAIL'') 
		)



  
  
   insert into CurrentWeekTable_forcallactivityextract
  Select DISTINCT  cast(cast( BPID as bigint) as varchar) [HCPID]
    
      , cast( cast( cast([CallDate]  as int) as varchar) as date)   [CallDate]
	 
	      ,''IMM'' [BU]
     
      ,''ZEPOSIA'' [Brand]
      ,''MS'' [Indication]
	   ,[PSETID]
	     ,[CallEventID]
      ,SaleRepID  [RepID]
      ,  [TerritoryID]
      ,TERR  [TerritoryCode]
      ,DIST [DistrictCode]
      ,REG [RegionCode]
      ,[Channel]
      ,SFA [SFTeamCode]
      ,SFAName [SFTeamName]
     -- ,[PODName]
     -- ,[LunchLearnFlag]
      , [IVAFlag]
      --,[TPOAlertFlag]
      --,[CE3AlertFlag]
	 -- , isnull(cast( [SmartAlertFlag] as varchar),''-'') [SmartAlertFlag]
      ,isnull( cast(cast( cast( case when  [SmartAlertFlag] ='' '' then null else  [SmartAlertFlag] end 
	  as varchar) as date) as varchar),''-'')  [SmartAlertFlag]
	  ,case when SmartAlertFlag <>'' '' then AlertName   else ''-'' end [SmartAlertName]
      ,[CallPosition]
      ,0.0000 [PDE] 
	  
	  from Test_Prateek.. CallActivity_AllBU_Extract_zepms
 
 where  cast(cast( [BPID] as bigint) as varchar)  <>''0''


	Declare @sql varchar(8000)  		
	DECLARE @html nvarchar(MAX), @body1 Nvarchar(max) 

	select convert(varchar(50), getdate())+'': Monthly Activity Extract  Processing completed...''
	set @body1 = ''Monthly Activity Extract  Process completed : ''+ convert(varchar(50), getdate()) 
    EXEC msdb.dbo.sp_send_dbmail 
    @profile_name = ''XSUNT ONELOOK-DB-1 SQL Notification'',
    @recipients = ''prateek.singh@xsunt.com;yancheng.zhou@xsunt.com'',
    @subject = ''Monthly Activity Extract  Process completed'',
    @body = @body1 ,
   ------------------ @from_address = ''prateek.singh@xsunt.com'',
    @body_format = ''HTML'',
    @query_no_truncate = 1, 
    @attach_query_result_as_file = 0    

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

