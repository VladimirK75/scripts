CREATE procedure dbo.QORT_TDB_Error_CheckList @ReportDate int null
                                           , @Details    int = 0
as
    begin
        declare @ReportFarBack int
              , @Environment   varchar(6)    = 'RENBR'
              , @ImportTable   varchar(32)
			  , @TC_Const 	   smallint
              , @tmpSQLQuery   nvarchar(max)
        select @ReportFarBack = isnull(@ReportDate, 14)
        drop table if exists #tmp_MonitoringTableErrors
        create table #tmp_MonitoringTableErrors
        ( RowId         int identity(1, 1)
        , Line          varchar(16) null
        , ImportTable   varchar(48)
        , ID            bigint
        , isProcessed   smallint
        , ErrorLog      varchar(1024)
        , EventDateTime datetime null )
        drop table if exists #tmp_MonitoringTableList
        create table #tmp_MonitoringTableList
        ( RowID       int identity(1, 1)
        , Line        varchar(16) null
        , TC_Const    smallint
        , Epic        varchar(32)
        , Task        varchar(16)
        , Step        varchar(16)
        , ImportTable varchar(48)
        , AllRowCount bigint default 0
        , ErrRowCount bigint default 0 );
        insert into #tmp_MonitoringTableList
        ( TC_Const
        , Line
        , Epic
        , Task
        , Step
        , ImportTable
        )
        values
        ( -1
        , 'Business'
        , 'Processing'
        , 'Trades'
        , ''
        , 'Trades'
        ),
        ( -1
        , 'Import'
        , 'Queue'
        , ''
        , ''
        , ''
        ),
        ( 1
        , 'Import'
        , 'Transactional data'
        , 'Trades'
        , ''
        , 'ImportTrades'
        ),
        ( 5
        , 'Import'
        , 'Transactional data'
        , 'Correctpositions'
        , 'Amend'
        , 'Correctpositions'
        ),
        ( 6
        , 'Import'
        , 'Transactional data'
        , 'Clearings'
        , ''
        , 'Clearings'
        ),
        ( 7
        , 'Import'
        , 'Transactional data'
        , 'Phases'
        , 'Amend'
        , 'Phases'
        ),
        ( 8
        , 'Import'
        , 'Transactional data'
        , 'Phases'
        , 'Cancel'
        , 'PhaseCancelations'
        ),
        ( 11
        , 'Import'
        , 'Transactional data'
        , 'Commissions'
        , ''
        , 'ImportBlockCommissionOnTrades'
        ),
        ( 16
        , 'Import'
        , 'Transactional data'
        , 'CorrectPositions'
        , 'Cancel'
        , 'CancelCorrectPositions'
        ),
        ( 17
        , 'Import'
        , 'Transactional data'
        , 'Clearings'
        , 'Cancel'
        , 'CancelClearings'
        ),
        ( 18
        , 'Import'
        , 'Transactional data'
        , 'ClientInstr'
        , ''
        , 'ImportClientInstr'
        ),
        ( 21
        , 'Import'
        , 'Static Data'
        , 'Assets'
        , ''
        , 'Assets'
        ),
        ( 99
        , 'Import'
        , 'Static Data'
        , 'Coupons'
        , ''
        , 'Coupons'
        ),
        ( 22
        , 'Import'
        , 'Static Data'
        , 'Firms'
        , ''
        , 'Firms'
        ),
        ( 23
        , 'Import'
        , 'Static Data'
        , 'ClientAgrees'
        , ''
        , 'ClientAgrees'
        ),
        ( 24
        , 'Import'
        , 'Static Data'
        , 'Subaccs'
        , ''
        , 'Subaccs'
        ),
        ( 26
        , 'Import'
        , 'Static Data'
        , 'PayAccs'
        , ''
        , 'PayAccs'
        )
        update #tmp_MonitoringTableList
           set #tmp_MonitoringTableList.AllRowCount = iec.AllRows
          from( select iec.TC_Const
                     , AllRows = count(distinct iec.Oper_ID)
                  from QORT_TDB_PROD..ImportExecutionCommands iec with(nolock)
                 where 1 = 1
                       and datediff(dd, iec.ExecutionDateTime, getdate()) >= @ReportFarBack
                 group by iec.TC_Const ) iec
         where iec.TC_Const = #tmp_MonitoringTableList.TC_Const
        insert into #tmp_MonitoringTableErrors
        ( Line
        , ImportTable
        , ID
        , isProcessed
        , ErrorLog
        , EventDateTime
        )
        select line = 'Import'
             , ImportTable = tc.[Description(eng.)]
             , ID = iec.Oper_ID
             , iec.IsProcessed
             , iec.ErrorLog
             , EventDateTime = iif(len(ltrim(rtrim(substring(iec.Comment, patindex('% at %', iec.Comment) + 4, 100)))) > 0, cast(ltrim(rtrim(substring(iec.Comment, patindex('% at %', iec.Comment) + 4, 23))) as datetime), null)
          from QORT_TDB_PROD..ImportExecutionCommands iec with(nolock)
          inner join QORT_DB_PROD..TC_Const tc with(nolock) on tc.[Value] = iec.TC_Const
         where iec.IsProcessed < 3
        declare tmp_checkErrors cursor local fast_forward
        for select tmtl.ImportTable, tmtl.TC_Const
              from #tmp_MonitoringTableList tmtl
             where tmtl.Line = 'Import' 
                   and tmtl.ImportTable <> ''
        open tmp_checkErrors
        fetch next from tmp_checkErrors into @ImportTable , @TC_Const
        while @@FETCH_STATUS = 0
            begin
                set @tmpSQLQuery = concat(N'
				insert into #tmp_MonitoringTableErrors (Line,ImportTable,ID,isProcessed,ErrorLog,EventDateTime)
				select Line = ''Import'', Section = ''' , @ImportTable , ''', q.id, q.IsProcessed, q.ErrorLog, EventDateTime = iec.ExecutionDateTime
from QORT_TDB_PROD..' , @ImportTable , ' q
left join QORT_TDB_PROD..ImportExecutionCommands iec with(nolock) on q.id=iec.Oper_ID
and iec.TC_Const = ''' , @TC_Const , '''
where q.IsProcessed in (4)')
                exec (@tmpSQLQuery)
                fetch next from tmp_checkErrors into @ImportTable,@TC_Const
            end
        close tmp_checkErrors
        deallocate tmp_checkErrors
        /*		*/        ;
        with tmp_Processing
             as (select tw.Trade_ID
                      , tw.TradeDate
                      , BusinessErrMessage = substring(concat(iif(t.TSSection_ID is null, ',QuikClassCode not found', ''), iif(t.Security_ID is null, ',Security not found', ''), iif(a.id is null, ',TradeCode not found', ''), iif(s.id is null, ',SubAcc not found', ''), iif(fc.id is null, ',CpFirmCode not found', ''), iif(t.CurrPriceAsset_ID is null, ',Currency not found', ''), iif(payAcc.id is null, ',Pay account not found', ''), iif(putAcc.id is null, ',Put account not found', '')), 2, 255)
                      , ITErrMessage = substring(concat(iif(t.TSSection_ID is null, ',QuikClassCode not found', ''), ''), 2, 255)
                      , EventTimeStamp = qort_ddm.dbo.DDM_GetDateTimeFromInt( tw.created_date, tw.created_time )
                   from QORT_DB_PROD..TradeWarnings tw with(nolock)
                   inner join QORT_DB_PROD..Trades t with(nolock) on t.id = tw.Trade_ID
                                                                     and t.IsProcessed = 'n'
                                                                     and t.Enabled = 0
                   left join QORT_DB_PROD..Accounts a with(nolock) on tw.AccountCode = a.TradeCOde collate Cyrillic_General_CI_AS
                                                                      and a.Enabled = 0
                                                                      and a.IsTrade = 'y'
                   left join QORT_DB_PROD..Subaccs s with(nolock) on s.SubAccCode = tw.ClientCode collate Cyrillic_General_CI_AS
                                                                     and s.Enabled = 0
                                                                     and s.IsAnalytic = 'n'
                   left join QORT_DB_PROD..Accounts payAcc with(nolock) on t.PayAccount_ID = payAcc.id
                   left join QORT_DB_PROD..Accounts putAcc with(nolock) on t.PutAccount_ID = putAcc.id
                   left join QORT_DB_PROD..FirmCodes fc with(nolock) on tw.CpFirmCode = fc.Code
                                                                        and not exists( select 1
                                                                                          from QORT_DB_PROD..FirmCodes fc2 with(nolock)
                                                                                         where tw.CpFirmCode = fc2.Code
                                                                                               and fc2.id > fc.id ))
             insert into #tmp_MonitoringTableErrors
             ( Line
             , ImportTable
             , ID
             , isProcessed
             , ErrorLog
             , EventDateTime
             )
             select Line = 'Business'
                  , ImportTable = 'Trades' -- ImportTable - varchar
                  , tp.Trade_ID -- ID - bigint
                  , isProcessed = 4 -- isProcessed - smallint
                  , ErrorLog = tp.BusinessErrMessage -- ErrorLog - varchar
                  , tp.EventTimeStamp
               from tmp_Processing tp
              where tp.BusinessErrMessage <> ''
        /*		*/
        update #tmp_MonitoringTableList
           set #tmp_MonitoringTableList.ErrRowCount = err.N
          from( select tmte.Line
                     , tmte.ImportTable
                     , N = count(1)
                  from #tmp_MonitoringTableErrors tmte
                 group by tmte.Line
                        , tmte.ImportTable ) err
         where err.ImportTable = #tmp_MonitoringTableList.ImportTable
               and err.Line = #tmp_MonitoringTableList.Line
        if @Details = 0
            begin
                select Environment = @Environment
                     , tmtl.Line
                     , tmtl.Epic
                     , tmtl.Task
                     , tmtl.Step
                     , tmtl.ErrRowCount
                  from #tmp_MonitoringTableList tmtl
                order by tmtl.Line
                       , tmtl.Epic
                       , tmtl.TC_Const
        end
        if @Details = 1
            begin
                select Environment = @Environment
                     , tmte.Line
                     , tmte.ImportTable
                     , tmte.ID
                     , tmte.ErrorLog
                     , tmte.EventDateTime
                  from #tmp_MonitoringTableErrors tmte
        end
    end
