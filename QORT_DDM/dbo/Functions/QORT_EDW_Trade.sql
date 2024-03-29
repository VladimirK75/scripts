CREATE function [dbo].[QORT_EDW_Trade](@DateFrom int
                                , @DateTo   int)
returns table
as
     return
     ( select T.SystemID
            , T.TradeDate
            , T.TradeNum
            , ModifiedDate = T.ModifiedDate
            , T.ModifiedTime
            , Capacity = iif(SubAcc_Code = 'RENBR', 'Principal', 'Agency')
            , Product = iif(TT_Const in(3, 6), 'Repo', iif(PT_Const = 1, 'FixedIncome', 'Equity'))
            , Direction = iif(TT_Const in(3, 6), iif(DD.Direction = 'Sell', 'Direct', 'Reverse'), DD.Direction)
            , T.AssetShortName
            , T.Asset_ISIN
            , CancelStatus = isnull(T.NullStatus, 'n')
         from QORT_TDB_PROD..Trades T with (nolock, index(I_Trades_ModifiedDate))
         inner loop join( select Direction = 'Buy'
                          union all
                          select Direction = 'Sell' ) DD on iif(T.SubAcc_Code = 'RENBR', iif(T.BuySell = 1, 'Buy', 'Sell'), DD.Direction) = DD.Direction
        where 1 = 1
              and T.ModifiedDate >= @DateFrom
			  and T.ModifiedDate < @DateTo
              and TT_Const in ( 1, 2, 3, 5, 6, 7, 14 )
              and T.IsRepo2 = 'n'
              and TradeDate >= 20190701 /* release date*/
       union all
       select T.SystemID
            , T.TradeDate
            , T.TradeNum
            , ModifiedDate = T.ModifiedDate
            , T.ModifiedTime
            , Capacity = iif(T.SubAccOwner_BOCode = 'RENBR', 'Principal', 'Agency')
            , Product = iif(QUIKClassCode in('SPBFUT', 'PSFUT'), 'Future', iif(QUIKClassCode in('SPBOPT', 'PSOPT'), 'Option', 'Undefined'))
            , DD.Direction
            , T.AssetShortName
            , T.Asset_ISIN
            , CancelStatus = isnull(T.NullStatus, 'n')
         from QORT_TDB_PROD..Trades T with (nolock, index(I_Trades_ModifiedDate))
         inner loop join( select Direction = 'Buy'
                          union all
                          select Direction = 'Sell' ) DD on iif(T.SubAccOwner_BOCode = 'RENBR', iif(T.BuySell = 1, 'Buy', 'Sell'), DD.Direction) = DD.Direction
        where 1 = 1
              and T.ModifiedDate >= @DateFrom
			  and T.ModifiedDate < @DateTo
              and TT_Const = 4
              and TradeDate >= 20191101 /* release date */
       union all
       select T.SystemID
            , T.TradeDate
            , T.TradeNum
            , ModifiedDate = T.ModifiedDate
            , T.ModifiedTime
            , Capacity = iif(T.SubAccOwner_BOCode = 'RENBR', 'Principal', 'Agency')
            , Product = iif(TT_Const = 8, 'FX', 'FXSwap')
            , DD.Direction
            , T.AssetShortName
            , T.Asset_ISIN
            , CancelStatus = isnull(T.NullStatus, 'n')
         from QORT_TDB_PROD..Trades T with (nolock, index(I_Trades_ModifiedDate))
         inner loop join( select Direction = 'Buy'
                          union all
                          select Direction = 'Sell' ) DD on iif(T.SubAccOwner_BOCode = 'RENBR', iif(T.BuySell = 1, 'Buy', 'Sell'), DD.Direction) = DD.Direction
        where 1 = 1
              and T.ModifiedDate >= @DateFrom
			  and T.ModifiedDate < @DateTo
              and TT_Const in ( 8, 12 )
              and T.IsRepo2 = 'n'
              and TSSection_Name not like '%OTC%'
              and TradeDate >= 20200120 /* release date */
     )
