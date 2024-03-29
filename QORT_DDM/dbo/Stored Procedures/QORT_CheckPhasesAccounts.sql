create   procedure dbo.QORT_CheckPhasesAccounts @ReportDateFrom date, @ReportDateTo   date
as
    begin
        drop table if exists #tmp_report
        create table #tmp_report
        ( Trade_ID     bigint
        , TradeDate    int
        , TradeNum     float
        , AgreeNum     varchar(100)
        , TradeAccount varchar(32)
        , BackID       varchar(100)
        , PhaseAccount varchar(32)
        , Description  nvarchar(512)
        , PhaseDate    int
        , QtyBefore    float
        , QtyAfter     float
        , ShortName    varchar(48) )
        while @ReportDateFrom <= @ReportDateTo
            begin
                insert into #tmp_report
                select distinct 
                       p.Trade_ID
                     , t.TradeDate
                     , t.TradeNum
                     , t.AgreeNum
                     , TradeAccount = T_Acc.ExportCode
                     , p.BackID
                     , PhaseAccount = P_Acc.ExportCode
                     , pc.Description
                     , p.PhaseDate
                     , QtyBefore = p.QtyBefore * p.QtyAfter
                     , p.QtyAfter
                     , a.ShortName
                  from QORT_DB_PROD..Trades t with (nolock, index = I_Trades_ID)
                  inner join QORT_DB_PROD..TSSections ts with(nolock) on ts.id = t.TSSection_ID
                                                                         and ts.TS_ID = 6
                  inner join QORT_DB_PROD.dbo.Phases p with (nolock, index = I_Phases_PhaseDate_PCConst) on p.Trade_ID = t.id
                                                                                                            and p.PC_Const in(3, 4, 5, 7)
                                                                                                            and p.IsCanceled = 'n'
                                                                                                            and p.PhaseDate = format(@ReportDateFrom, 'yyyyMMdd')
                  inner join QORT_DB_PROD..Assets a with(nolock) on a.id = p.PhaseAsset_ID
                  inner join QORT_DB_PROD..PC_Const pc with(nolock) on pc.[Value] = p.PC_Const
                  inner join QORT_DB_PROD..Accounts T_Acc with(nolock) on T_Acc.id = iif(p.PC_Const in(3, 4), t.PutAccount_ID, t.PayAccount_ID)
                  inner join QORT_DB_PROD..Accounts P_Acc with(nolock) on P_Acc.id = p.PhaseAccount_ID
                 where 1 = 1
                       and t.NullStatus = 'n'
                       and t.TT_Const in ( 6, 8, 12, 13 )
                       and iif(p.PC_Const in ( 3, 4 )
                           and p.PhaseAccount_ID <> t.PutAccount_ID, 1, 0) + iif(p.PC_Const in ( 5, 7 )
                and p.PhaseAccount_ID <> t.PayAccount_ID, 1, 0) > 0
                select @ReportDateFrom = dateadd(dd, 1, @ReportDateFrom)
            end
        select *
          from #tmp_report tr
    end
