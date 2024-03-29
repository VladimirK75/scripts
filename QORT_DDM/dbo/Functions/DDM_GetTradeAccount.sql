create   function dbo.DDM_GetTradeAccount(@LoroAccount varchar(6))
returns varchar(50)
as
     begin
         declare @TradeCode varchar(50) = null
         select @TradeCode = a.TradeCOde
           from QORT_DB_PROD..Subaccs s with(nolock)
           inner join QORT_DB_PROD..PayAccs pa with(nolock) on pa.SubAcc_ID = s.id
           inner join QORT_DB_PROD..Accounts a with(nolock) on a.id in(pa.PutAccount_ID, pa.PayAccount_ID)
                                                               and a.TS_ID != 6
                                                               and a.IsTrade = 'y'
                                                               and a.IsAnalytic = 'n'
                                                               and a.AssetType = 1
          where s.SubAccCode = @LoroAccount
         return @TradeCode
     end
