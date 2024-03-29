/***********************
Author: Kirill
Date:   2019-11--19
QORT-1187
***********************/
CREATE function [dbo].[QORT_1C_Plan_FORTSPropTrades](
               @start_date  int
             , @finish_date int
             , @start_time  int = null
             , @finish_time int = null)
returns table
as
return
(select trd.id
      , concat('QR', cast(trd.id as bigint)) as 'internal_reference'
      , [trade_date]=trd.tradedate
      , trd.created_date
      , trd.modified_date
      , trd.modified_time
      , entity = 'RENBR'
      , product = case
                       when ass1.AssetClass_Const in(5, 8, 16) then 'Equity'
                       when ass1.AssetClass_Const in(6, 7, 9) then 'Bond'
                     else 'Else'
                  end
      , maturity_date = ass.CancelDate
      , contract_id = ass.ShortName
	  , Nullstatus=isnull(trd.Nullstatus,'n')
   from QORT_DB_PROD..Trades trd with(nolock)
   join QORT_DB_PROD..Securities scr with(nolock) on scr.id = trd.Security_ID
   join QORT_DB_PROD..Assets ass with(nolock) on scr.Asset_ID = ass.id
   left join QORT_DB_PROD..Assets ass1 with(nolock) on ass1.ID = ass.BaseAsset_ID
   join QORT_DB_PROD..TSSections tss with(nolock) on tss.id = trd.TSSection_ID
   join QORT_DB_PROD..subaccs sub with(nolock) on trd.SubAcc_ID = sub.id
                                                  and sub.OwnerFirm_ID = 70746
   left join QORT_DB_PROD..AssetClass_Const acc with(nolock) on acc.Value = ass1.AssetClass_Const
  where trd.TradeDate > 20190000
        and trd.tt_const = 4
        and trd.TradeDate between @start_date and @finish_date
        and trd.tradetime between iif(trd.TradeDate = @start_date, isnull(@start_time, 0), 0) and iif(trd.TradeDate = @finish_date, isnull(@finish_time, 235959999), 235959999))
