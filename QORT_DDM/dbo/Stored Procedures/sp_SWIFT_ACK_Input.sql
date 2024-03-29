--exec [sp_SWIFT_ACK_Input] 'TEST'

CREATE Proc [dbo].[sp_SWIFT_ACK_Input] (@TradeReference nvarchar(256))
as 
begin

insert into QORT_TDB_PROD.dbo.ImportTrades 
	(TradeNum, AgreeNum, TradeDAte, AddStatBroker, AddStatBrokerDate, ET_Const, TSSection_Name, BuySell,IsProcessed)
select
TradeNum, 
AgreeNum,
TradeDAte,
10 as AddStatBroker,  
convert(varchar(10), getdate(), 112) as AddStatBrokerDate, 
4 as ET_Const, 
Ts.Name, 
BuySell,
1 as IsProcessed
from QORT_DB_PROD.dbo.Trades Tr
inner join QORT_DB_PROD.dbo.TSSections Ts
	on Tr.TSSection_ID = Ts.id
where AgreeNum = @TradeReference
and Tr.Enabled = 0
and NullStatus = 'n'
and Tr.IsRepo2 = 'n'

/*EXEC msdb.dbo.sp_send_dbmail
		@profile_name		= 'QORTMonitoring',
		@recipients		= 'aleonov@rencap.com',
		@subject			= @TradeReference
		
declare @logevent varchar(1000)*/

--set @logevent = '[SWIFT ACK] Trade ' + @TradeReference + ' received'

--EXEC xp_logevent 60000, @logevent, informational;
end
