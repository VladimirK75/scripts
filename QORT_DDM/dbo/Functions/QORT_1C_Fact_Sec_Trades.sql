
CREATE   FUNCTION [dbo].[QORT_1C_Fact_Sec_Trades](@start_date int, @finish_date int)
RETURNS TABLE
as 
Return 
(
select P.id
     , P.PhaseDate
	 , T.TradeDate
	 , t.TradeNum
	 , t.AgreeNum
     , A.ShortName  Asset
     , QtyBefore Qty
     , iif(QtyAfter = -1, 'Sell', 'Buy') Direction
     , IsCanceled
  from QORT_DB_PROD..Phases P with(nolock)
  inner loop join QORT_DB_PROD..Trades T with(nolock) on P.Trade_ID = T.id
                                                         and T.Enabled = 0
                                                         and T.TT_Const in(1, 2, 3, 5, 6, 7, 14)
  inner loop join QORT_DB_PROD..Assets A with(nolock) on P.PhaseAsset_ID = A.id
where 1 = 1
       and P.PC_Const in (3, 4)
       and P.PhaseDate between @start_date and @finish_date
       and P.SubAcc_ID = 2371 /*RENBR*/
)

/*select * from [dbo].[QORT_1C_Fact_Sec_Trades](20190630, 20190701)	*/
