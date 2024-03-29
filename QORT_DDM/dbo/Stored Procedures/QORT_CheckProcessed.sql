CREATE procedure [dbo].[QORT_CheckProcessed] @ReportDate int = null
                                      , @Details    int = 0
as
    begin
        set @ReportDate = isnull(@ReportDate, format(getdate(), 'yyyyMMdd'))
        drop table if exists #tmp_DB_Objects
        create table #tmp_DB_Objects
        ( RowId          bigint identity(1, 1) primary key
        , TypeObject     varchar(32)
        , Stage          varchar(32)
        , SystemID       bigint
        , Record_ID      bigint null
        , EventTimeStamp datetime )
        create index IX_SystemID on #tmp_DB_Objects( SystemID )
        create index IX_Record_ID on #tmp_DB_Objects( Record_ID )
        create index IX_TypeObject on #tmp_DB_Objects( TypeObject )
        create index IX_Stage on #tmp_DB_Objects( Stage )
        drop table if exists #tmp_Report
        create table #tmp_Report
        ( TypeObject   varchar(32)
        , SystemID     bigint
        , QORT_DB_PROD datetime
        , DataAlerts   datetime
        , Latency      int )
        insert into #tmp_DB_Objects
        select TypeObject = 'Сделки'
             , Stage = 'QORT_DB_PROD'
             , SystemID = t.id
             , Record_ID = null
             , EventTimeStamp = dateadd(hour, (t.modified_time / 10000000) % 100, dateadd(minute, (t.modified_time / 100000) % 100, dateadd(second, (t.modified_time / 1000) % 100, dateadd(millisecond, t.modified_time % 1000, cast(cast(t.modified_date as char) as datetime)))))
          from QORT_DB_PROD..Trades t with (nolock, index = PK_Trades)
         where t.TradeDate = @ReportDate
        insert into #tmp_DB_Objects
        select TypeObject = 'Сделки'
             , Stage = 'QORT_TDB_PROD'
             , SystemID = t.SystemID
             , Record_ID = t.id
             , EventTimeStamp = dateadd(hour, (t.ModifiedTime / 10000000) % 100, dateadd(minute, (t.ModifiedTime / 100000) % 100, dateadd(second, (t.ModifiedTime / 1000) % 100, dateadd(millisecond, t.ModifiedTime % 1000, cast(cast(t.ModifiedDate as char) as datetime)))))
          from QORT_TDB_PROD..Trades t with(nolock)
         where t.TradeDate = @ReportDate
        insert into #tmp_DB_Objects
        select TypeObject = 'Корректировки позиций'
             , Stage = 'QORT_DB_PROD'
             , SystemID = cp.ID
             , Record_ID = null
             , EventTimeStamp = dateadd(hour, (cp.modified_time / 10000000) % 100, dateadd(minute, (cp.modified_time / 100000) % 100, dateadd(second, (cp.modified_time / 1000) % 100, dateadd(millisecond, cp.modified_time % 1000, cast(cast(cp.modified_date as char) as datetime)))))
          from QORT_DB_PROD..CorrectPositions cp with (nolock, index = I_CorrectPositions_Date)
         where cp.modified_date = @ReportDate
        insert into #tmp_DB_Objects
        select TypeObject = 'Корректировки позиций'
             , Stage = 'QORT_TDB_PROD'
             , SystemID = ecp.SystemID
             , Record_ID = ecp.id
             , EventTimeStamp = dateadd(hour, (ModifiedTime / 10000000) % 100, dateadd(minute, (ModifiedTime / 100000) % 100, dateadd(second, (ModifiedTime / 1000) % 100, dateadd(millisecond, ModifiedTime % 1000, cast(cast(ModifiedDate as char) as datetime)))))
          from QORT_TDB_PROD..ExportCorrectPositions ecp with (nolock, index = RC_IX_ExportCorrectPositions_Date)
         where ecp.ModifiedDate = @ReportDate
        insert into #tmp_DB_Objects
        select TypeObject = tc.Description
             , Stage = 'DataAlerts'
             , SystemID = tdo.SystemID
             , Record_ID = t.Record_ID
             , EventTimeStamp = dateadd(hour, (t.[Time] / 10000000) % 100, dateadd(minute, (t.[Time] / 100000) % 100, dateadd(second, (t.[Time] / 1000) % 100, dateadd(millisecond, t.[Time] % 1000, cast(cast(t.[Date] as char) as datetime)))))
          from QORT_TDB_PROD..DataAlerts t with(nolock)
          inner join QORT_DB_PROD.dbo.TC_Const tc with(nolock) on tc.[Value] = t.TC_Const
          inner join #tmp_DB_Objects tdo with(nolock) on t.Record_ID = tdo.Record_ID
         where 1 = 1
               and not exists( select 1
                                 from QORT_TDB_PROD..DataAlerts t0 with(nolock)
                                where t0.Record_ID = t.Record_ID
                                      and t0.TC_Const = t.TC_Const
                                      and t0.id > t.id )
        insert into #tmp_Report
        select *
             , Latency = datediff(second, QORT_DB_PROD, isnull(DataAlerts, getdate()))
          from( select tdo.TypeObject
                     , tdo.SystemID
                     , tdo.Stage
                     , tdo.EventTimeStamp
                  from #tmp_DB_Objects tdo
                 where tdo.Stage in ( 'QORT_DB_PROD', 'DataAlerts' )
                 group by tdo.TypeObject
                        , tdo.SystemID
                        , tdo.Stage
                        , tdo.EventTimeStamp ) t pivot(min(EventTimeStamp) for Stage in(QORT_DB_PROD, DataAlerts)) as pvt
        if @Details = 0
            begin
                select distinct 
                       TypeObject
                     , EventCount = count_big(tr.SystemID) over(partition by tr.TypeObject)
                     , RBreaks = count_big(tr.QORT_DB_PROD) over(partition by tr.TypeObject) - count_big(DataAlerts) over(partition by tr.TypeObject)
                     , FirstEvent = min(isnull(DataAlerts, getdate())) over(partition by tr.TypeObject)
                     , LastEvent  = max(isnull(DataAlerts, getdate())) over(partition by tr.TypeObject)
                     , AvgLatency = cast(avg(isnull(convert(numeric(20, 0), tr.Latency), 0)) over(partition by tr.TypeObject) as bigint)
                     , EndLatency = last_value(convert(numeric(20, 0), isnull(tr.Latency, 0))) over(order by tr.TypeObject)
                  from #tmp_Report tr
        end
        if @Details = 1
            begin
                select *
                  from #tmp_Report tr
                 where DataAlerts is null
        end
        if @Details = 2
            begin
                select *
                  from #tmp_Report tr
                order by QORT_DB_PROD
        end
        drop table if exists #tmp_DB_Objects
        drop table if exists #tmp_Report
    end
