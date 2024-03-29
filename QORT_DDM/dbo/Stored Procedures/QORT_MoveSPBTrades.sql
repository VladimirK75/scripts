CREATE     procedure [dbo].[QORT_MoveSPBTrades]
as
    begin
        set nocount on

drop table if exists #tmp_SPB_Trades
drop table if exists ##SPB_Trades_RENBR

select id=-1
    , t.TradeNum
    , TradeDate = t.EventDate
    , t.TSSection_Name
    , t.BuySell
    , t.Security_Code
    , t.Qty
    , t.InfoSource
    , t.PutAccount_ExportCode
    , t.PayAccount_ExportCode
    , t.SubAcc_Code
    , t.AgreeNum
    , t.SystemID
    , Modified_System_ID = t.SystemID
    , QFlags = 0
    , isProcessed = 1
    , isExecByCom = 'n'
    , ET_const = 4
into #tmp_SPB_Trades
  from QORT_TDB_PROD.dbo.Trades t with(nolock, index=I_Trades_TradeDate_SubaccCode)
inner join QORT_DB_PROD..TSSections ts with (nolock) on t.TSSection_Name=ts.Name and ts.TS_ID=11
where 1=1
and t.TradeDate >= QORT_DDM.dbo.DDM_fn_AddBusinessDay( null, -4, null )
and t.TradeDate != t.EventDate
and t.TradeTime < 015000000
order by t.id


insert into QORT_TDB_PROD.dbo.ImportTrades
( id
, TradeNum
, TradeDate
, TSSection_Name
, BuySell
, Security_Code
, Qty
, InfoSource
, PutAccount_ExportCode
, PayAccount_ExportCode
, SubAcc_Code
, AgreeNum
, SystemID
, Modified_System_ID
, QFlags
, IsProcessed
, IsExecByComm
, ET_Const
)
select * from #tmp_SPB_Trades

select QORT_ID = cast(SystemID as bigint)
, TradeNum
, AgreeNum
, SubAcc_Code
, TradeDate
into ##SPB_Trades_RENBR
from #tmp_SPB_Trades
where SubAcc_Code not in ('UMG873','RESEC')

declare         @recipients varchar(256)  = 'OZhirnikova@rencap.com; MTelesheva@rencap.com'
              , @Recipcopy  varchar(256)  = 'ITSupportBackQORT@rencap.com;ITSupportFinance@rencap.com;ExceptionManagementTeamMoscow@rencap.com'
              , @subject    varchar(256)
              , @body       nvarchar(max)

select @subject = concat('QORT: RENBR SPB Trades with a date change were found at ', format(getdate(), 'yyyy-MM-dd HH:mm:ss'))

select @body = concat('<html><body>',
(select concat(count(1) ,' - RENBR SPB Trades with a date change were found')
from ##SPB_Trades_RENBR)
,'<hr />
<p style="font-size: 9px">
Server:&nbsp; S-MSK01-SQL08\QORT_RENBR<br /> 
Job:&nbsp; Morning_Update_Trades_Orders.SPB_Trades<br />
Step:&nbsp;SPB move late trades into the next day<br />
Author: vkruglov@rencap.com
</p> 
</body></html>')


                if exists( select 1
                             from ##SPB_Trades_RENBR)
                    begin
                        exec msdb.dbo.sp_send_dbmail @profile_name = 'QORTMonitoring'
                                                   , @recipients = @recipients
                                                   , @copy_recipients = @Recipcopy
                                                   , @subject = @subject
                                                   , @body = @body
                                                   , @body_format = 'HTML'
                                                   , @query = 'select * from ##SPB_Trades_RENBR'
                                                   , @attach_query_result_as_file = 1
                                                   , @query_result_separator = ','
                                                   , @query_result_no_padding = 1


end
end
