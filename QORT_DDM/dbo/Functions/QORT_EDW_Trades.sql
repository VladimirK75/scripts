CREATE function dbo.QORT_EDW_Trades(@DateFrom int
                                 , @DateTo   int)
returns table
as
     return
     select _SystemID = Trade.SystemID
          , TradeGID = concat('QR', cast(Trade.SystemID as bigint))
            /*          , TradeID = concat('QR', cast(Trade.SystemID as bigint), '-', iif(Trade.Direction in('Reverse', 'Buy'), 0, 1))*/
          , TradeDate = stuff(stuff(Trade.TradeDate, 7, 0, '-'), 5, 0, '-')
          , _TradeNum = cast(Trade.TradeNum as bigint)
          , _ModifiedDate = stuff(stuff(Trade.ModifiedDate, 7, 0, '-'), 5, 0, '-')
          , _ModifiedTime = stuff(stuff(stuff(right(concat('0000000000', Trade.ModifiedTime), 9), 7, 0, '.'), 5, 0, ':'), 3, 0, ':')
          , EventTime = format(dateadd(hour, -3, ( select QORT_DDM.dbo.DDM_GetDateTimeFromInt( Trade.ModifiedDate, Trade.ModifiedTime ) )), 'yyyy-MM-ddTHH:mm:ss.fffZ')
          , Trade.Capacity as       Capacity
          , Trade.Product as        _Product
          , TradeType = concat(iif(Trade.Product = 'FXSwap', 'FxSwap', Trade.Product), 'Trade')
          , Trade.Direction as      Direction
          , Trade.AssetShortName as _AssetShortName
          , Trade.Asset_ISIN as     _Asset_ISIN
          , Trade.CancelStatus as   _CancelStatus
          , EventStatus = case Trade.CancelStatus
                              when 'y' then 'Canceled'
                              when 'n' then 'Active'
                               else '#N/A#'
                          end
       from QORT_DDM.dbo.QORT_EDW_Trade( @DateFrom, @DateTo ) Trade
