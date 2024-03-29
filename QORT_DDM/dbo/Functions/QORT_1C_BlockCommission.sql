CREATE     function [dbo].[QORT_1C_BlockCommission]
( @StartDate int
, @EndDate   int 
, @N smallint )
returns table
as
     return
     ( select distinct
	          QORT_ID = ebcot.BCT_SID
			, QORT_Date = ebcot.AccrualDate
            , QORT_TradeID = ebcot.Trade_SID
            , t.TradeNum
            , CommissionVolume = abs(ebcot.[Value])
            , CommissionCurrency = ebcot.Currency_ShortName
            , IsCancel=iif(bcot.id is null,'y',ebcot.IsCancel)
            , ebcot.CommissionName
            , ebcot.TSSection_Name
			, Client_BOCode = t.SubAccOwner_BOCode
            , ebcot.SubAccCode
            , ebcot.Account_ExportCode
            , TradeCP = t.CpFirm_BOCode
            , TradeAgreeNum = t.AgreeNum
            , ebcot.PhaseType
            , Direction = sign(ebcot.[Value])
            , Executed = nullif(p.[Date], 0)
			, Phase_ID = p.SystemID
			, Phase_IsCancel = iif(p.SystemID is null, null, isnull(p.IsCanceled,'n'))
            , TransferID = left(ebcot.BackID, charindex('/', concat(ebcot.BackID, '/')) - 1)
         from QORT_TDB_PROD..ExportBlockCommissionOnTrades ebcot with(nolock)
         inner join QORT_TDB_PROD..Trades t with(nolock) on t.SystemID = ebcot.Trade_SID
         left join QORT_TDB_PROD..Phases p with (nolock, index = I_Phases_TradeSID) on p.Trade_SID = ebcot.Trade_SID
                                                                                       and p.BackID = ebcot.BackID
         left join QORT_DB_PROD..BlockCommissionOnTrades bcot with(nolock) on bcot.id=ebcot.BCT_SID
        where 1 = 1
              and ebcot.CommissionName like 'AGENCY%'
              and ebcot.AccrualDate between @StartDate and @EndDate 
			  and @N= case when @N=2 then 2
			               when ebcot.SubAccCode = 'RENBR' then 0
						   else 1
					  end
			  )
