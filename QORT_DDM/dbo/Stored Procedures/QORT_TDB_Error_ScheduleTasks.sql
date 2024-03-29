create   procedure dbo.QORT_TDB_Error_ScheduleTasks @ReportDateInt int null
                                                         , @Details       int = 0
as
    begin
        declare @Reportdate date = isnull(QORT_DDM.dbo.DDM_GetDateTimeFromInt( @ReportDateInt, 0 ), getdate())
        declare @ReportdateFrom  date
              , @ReportDateCount date
        select @ReportdateFrom = QORT_DDM.dbo.DDM_GetDateTimeFromInt( QORT_DDM.dbo.DDM_fn_AddBusinessDay( format(@Reportdate, 'yyyyMMdd'), -1, null ), 0 )
        select @ReportDateCount = @ReportdateFrom
        drop table if exists #ReportDatesErrorLists
        drop table if exists #ReportDates
        create table #ReportDates
        ( ReportDate int
        , ReportTime int )
        while @ReportDateCount <= @Reportdate
            begin
                insert into #ReportDates
                select ReportDate = format(@ReportDateCount, 'yyyyMMdd')
                     , ReportTime = iif(@ReportdateFrom = @ReportDateCount, 180000000, 0)
                set @ReportDateCount = dateadd(dd, 1, @ReportDateCount)
            end
        select rd.ReportDate
             , Epic = 'Schedule tasks'
             , Task = rqt.Description
             , Step = ltrim(substring(sr.ReiterationName, 12, 128))
               --     , sl.Progress
             , ITErrorLog = substring(concat(iif(sl.Progress = 4, ', QORT services off ', ''), iif(rqt.value = 11
                                                                                                   and patindex('Сверка с 0 отчетами%', sl.Log) > 0, ', File not found', ''), iif(sl.Progress in(23, 24, 45)
                                                                                                                                                                                  and patindex('%не удалось установить 0 лимитов%', sl.Log) > 0, ', QUIK Limit issue ', ''), ''), 2, 1024)
             , BusinessErrorLog = substring(concat(iif(sl.Progress = 4, ', QORT services off ', ''), ''), 2, 1024)
             , sl.Log
             , duration = format(dateadd(second, datediff(second, TIMEFROMPARTS( (sl.StartTime / 10000000) % 100, (sl.StartTime / 100000) % 100, (sl.StartTime / 1000) % 100, 0, 0 ), iif(sl.EndTime = 0, null, TIMEFROMPARTS( (sl.EndTime / 10000000) % 100, (sl.EndTime / 100000) % 100, (sl.EndTime / 1000) % 100, 0, 0 ))), '00:00:00'), 'HH:mm:ss')
                into #ReportDatesErrorLists
          from #ReportDates rd
          inner join QORT_DB_PROD..ScheduleLogs sl with(nolock) on sl.StartDate = rd.ReportDate
                                                                   and sl.StartTime >= rd.ReportTime
          inner join QORT_DB_PROD..ScheduleTasks st with(nolock) on sl.ScheduleTask_ID = st.id
          inner join QORT_DB_PROD..RQT_Const rqt with(nolock) on rqt.Value = st.RequestType
          inner join QORT_DB_PROD..ScheduleReiterations sr with(nolock) on sr.id = st.ScheduleReiteration_ID
        order by st.id
               , rd.ReportDate
        if @Details = 1
            select rdel.*
              from #ReportDatesErrorLists rdel
             else
            select rdel.Epic
                 , rdel.Task
                 , N = count(1)
                 , ITErrorLog = count(nullif(rdel.ITErrorLog, ''))
                 , BusinessErrorLog = count(nullif(rdel.BusinessErrorLog, ''))
              from #ReportDatesErrorLists rdel
             group by rdel.Epic
                    , rdel.Task
    end
