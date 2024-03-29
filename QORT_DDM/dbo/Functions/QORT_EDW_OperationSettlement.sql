CREATE function [dbo].[QORT_EDW_OperationSettlement] ( 
                @EventTimeFrom Datetime2(3), -- Timestamp in UTC format (yyyy-mm-ddThh:mi:ss.mmmZ)
				@EventTimeTo Datetime2(3)    -- Timestamp in UTC format (yyyy-mm-ddThh:mi:ss.mmmZ)
				) 
returns table
as
return
(
select  ID = case when left(O.ID,3) = 'STO' then concat ('SS', cast (O.TransactionRef as bigint))
				  when left(O.ID,3) = 'BNS' then replace (O.ID, 'BNS', 'QRST')
				  else concat ('CS', cast (O.TransactionRef as bigint))
			 end
  	  , O.EventTime
	  , O.EventStatus
	  , [SettlementType] = iif (O.ID like 'STO%', 'Security', 'Cash') 
      , O.TradeDate
	  , [OperationRef] = O.ID
	  , [ActualSettlementDate] = O.[Transfer.SettlementDate]
	  , [ActualSettlement.Direction] = O.[Transfer.Direction]
	  , [ActualSettlement.ChargeType] = O.[Transfer.ChargeType.ID]
from QORT_DDM..QORT_EDW_Operation (@EventTimeFrom, @EventTimeTo) O
where [Transfer.SettlementDate] is not null
      and O.[Transfer.ChargeType.ID]='VARIATION_MARGIN'
)
