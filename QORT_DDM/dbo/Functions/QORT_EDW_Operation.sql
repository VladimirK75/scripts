CREATE   function [dbo].[QORT_EDW_Operation] ( 
                @EventTimeFrom Datetime2(3), -- Timestamp in UTC format (yyyy-mm-ddThh:mi:ss.mmmZ)
				@EventTimeTo Datetime2(3)    -- Timestamp in UTC format (yyyy-mm-ddThh:mi:ss.mmmZ)
				) 
returns table
as
return
(with tmp_CorrPos (
	-- DDM
	[ID],
	[EventTime],				-- ModifiedDate+ModifiedTime	
	[EventStatus],				    -- Active\Canceled
	[Type],						-- Operation Type
	[TransactingCapacity],
	[TradeDate],
	[TransactionRef],
	[Transfer.SettlementDate],
	[Transfer.Direction],
	[Transfer.ChargeType.ID],	--VARIATION_MARGIN\CHARGE_FEE\...
	--Additional Information --
	[Asset],
	[Comment],
	[Comment2],
	[BackID],
	[Priority]
)
as (select
        
        [ID] = case
		        when E.CT_Const in (51, 52) then concat ('BPV', cast (E.SystemID as bigint))
				when E.CT_Const = 11 then concat ('CTO', cast (E.SystemID as bigint))
				when E.CT_Const = 12 then concat ('STO', cast (E.SystemID as bigint))
				else concat ('BPF', cast (E.SystemID as bigint))
			 end										
	  , [EventTime] = DATEADD(hour, -3, (select QORT_DDM.dbo.DDM_GetDateTimeFromInt (E.ModifiedDate, E.ModifiedTime)))
 	  , [EventStatus] = iif (isnull(isCanceled,'n') <> 'y', 'Active', 'Canceled')
	  , [Type] = case
		          when R.ObjectType = 'FORTS_VARIATION_MARGIN' then 'VariationMarginOperation'
				  when R.ObjectType = 'CHARGE_FEE' then 'ChargeFeeOperation'
				  else 'Undefined'
				 end
      , [TransactingCapacity] = iif(E.SubaccOwnerFirm_BOCode = 'RENBR', 'Principal', 'Agency')
      , [TradeDate] = convert (date, (select QORT_DDM.dbo.DDM_GetDateTimeFromInt (E.RegistrationDate, 0)))
      , [TransactionRef] = E.SystemID 
      , [Transfer.SettlementDate] = iif (E.Date = 0, NULL, convert (date, (select QORT_DDM.dbo.DDM_GetDateTimeFromInt (E.Date, 0))) )
      , [Transfer.Direction] = iif (ObjectType <> 'CHARGE_FEE' OR E.CT_Const = 10 AND ChargeType = 'FORTS_FEES', iif (Size > 0, 'In', 'Out'), iif (Size > 0, 'Out', 'In'))
	  , [Transfer.ChargeType.ID] = ChargeType
      , Asset = iif (E.Asset_ShortName = 'RUR', 'RUB', E.Asset_ShortName)
	  , E.Comment
	  , E.Comment2
	  , E.BackID
	  , Priority = row_number() over (partition by E.SystemID order by concat (isnull(R.Commission_ID, 0), isnull(R.Commission_Comment,'')) desc)
   from QORT_TDB_PROD..ExportCorrectPositions E with (nolock)
   inner join QORT_DDM..ExpCorrPos_Rules R with (nolock)
   ON E.CT_Const = R.CT_Const 
      and E.Commission_SID = isnull (R.Commission_ID, E.Commission_SID) 
	  and E.Comment like concat(R.Commission_Comment,'%')
   where 1 = 1
        and E.ModifiedDate >= cast(format(@EventTimeFrom,'yyyyMMdd') as int)
		and E.ModifiedDate <= cast(format(@EventTimeTo,'yyyyMMdd') as int)
		and E.ModifiedDate >= cast(format(R.StartDate,'yyyyMMdd') as int)
		and E.ModifiedDate <= isnull(cast(format(R.EndDate,'yyyyMMdd') as int), E.ModifiedDate)
		and E.CT_Const in (51,52,10,27,28,32,55) 
		and ModifiedDate >= 20191101 /* release date */
		and Size <> 0
		and not ( /* to exclude case High Frequency Cancel */
		        e.IsCanceled = 'y'
		    and E.CT_Const in (51, 52)
			and exists (select 1 from QORT_TDB_PROD..DataAlerts da with(nolock) where da.Record_ID=e.id and da.RecordStatus=0)
			and not exists (select 1 from QORT_TDB_PROD..DataAlerts da with(nolock) where da.Record_ID=e.id and da.RecordStatus=1)
		    )
	union all
select 
        [ID] = concat ('BNS', cast (P.SystemID as bigint),'-',dd.capacity)
      , [EventTime] = DATEADD(hour, -3, (select QORT_DDM.dbo.DDM_GetDateTimeFromInt (P.ModifiedDate, P.ModifiedTime)))
      , [EventStatus] = iif (isnull(isCanceled,'n') <> 'y', 'Active', 'Canceled')
      , [Type] = 'VariationMarginOperation'
      , [TransactingCapacity] = iif(T.SubAccOwner_BOCode = 'RENBR', 'Principal', 'Agency')
      , [TradeDate] = convert (date, (select QORT_DDM.dbo.DDM_GetDateTimeFromInt (P.[Date], 0)))
      , [TransactionRef] = P.SystemID
      , [Transfer.SettlementDate] = convert (date, (select QORT_DDM.dbo.DDM_GetDateTimeFromInt (P.Date, 0)))
	  , [Transfer.Direction] = iif (P.QtyAfter*(dd.capacity-0.5) > 0, 'Out', 'In')
      , [Transfer.ChargeType.ID] = 'VARIATION_MARGIN'
      , Asset = iif (P.PhaseAsset_ShortName = 'RUR', 'RUB', P.PhaseAsset_ShortName)
      , P.Comment
      , [Comment2] = ''
      , P.BackID
      , Priority = 1
from QORT_TDB_PROD..Phases P with (nolock)
join (select capacity=0 union select capacity=1) dd on dd.capacity in (0,1)
join QORT_TDB_PROD..Trades T with (nolock) on T.SystemID = P.Trade_SID
       where 1 = 1
       and P.PC_Const = 21
       and P.TT_Const in (8,12)
       and P.Date >= 20200127 /* release date */
	   and P.Date >= cast(format(@EventTimeFrom,'yyyyMMdd') as int)
	   and P.Date <= cast(format(@EventTimeTo,'yyyyMMdd') as int)
)
select  CP.ID
	  , CP.EventTime			-- ModifiedDate+ModifiedTime	
	  , CP.EventStatus			-- Active\Canceled
	  , CP.Type					-- Operation Type
	  , TxnGid = iif (CP.Comment2 not like 'TRAN/%', 
	                  left(CP.ID, isnull(nullif(charindex('-',CP.ID),0),128)-1), 
	                  concat (left(CP.ID,3), 'TRAN', left (BackID, 
	                  isnull (nullif (charindex ('_', BackID), 0), len (BackID) + 1) - 1))) 
  	  , CP.TransactingCapacity
  	  , CP.TradeDate
   	  , CP.TransactionRef
  	  , [Transfer.SettlementDate] = CP.[Transfer.SettlementDate]
  	  , [Transfer.Direction] = CP.[Transfer.Direction]
  	  , [Transfer.ChargeType.ID] = CP.[Transfer.ChargeType.ID]	--VARIATION_MARGIN\CHARGE_FEE\...
	-- Additional Information --
  	  , CP.Asset
  	  , CP.Comment
  	  , CP.Comment2
  	  , CP.BackID
from tmp_CorrPos CP
where Priority=1 
  and EventTime >= @EventTimeFrom 
  and EventTime <= @EventTimeTo
)
