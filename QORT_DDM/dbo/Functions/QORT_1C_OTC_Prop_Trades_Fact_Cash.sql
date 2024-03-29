/***********************
Author: K.Bolshesolsky
Date:   2019-08-02
Modified: 
Modified On: 
***********************/
CREATE       FUNCTION [dbo].[QORT_1C_OTC_Prop_Trades_Fact_Cash](@Startdate date, @Finishdate date)
RETURNS TABLE
as 
Return 

(
select phs.id
     , phs.PhaseDate
       , iif(PC_Const in (5,7), 'Principal/Interest', 'Fee') Type
     , A.ShortName  Asset
     , QtyBefore Qty
     , iif(QtyAfter = -1, 'Out', 'In') Direction
     , IsCanceled
from QORT_DB_PROD..phases phs with(nolock)
       join QORT_DB_PROD..Trades trd with(nolock)
       on trd.id = phs.Trade_ID
          inner join QORT_DB_PROD..Assets A with(nolock)
          on phs.PhaseAsset_ID = A.id
where phs.SubAcc_ID=2371 /*RENBR*/
       and phs.CurrencyAsset_ID <> 71273 /*RUR*/
       and phs.PC_Const in (5,7,8,9)
       and trd.TT_Const in (5,6)
	   and trd.TradeDate > 20190731
       and phs.PhaseDate between Convert(varchar(8),@Startdate,112) and Convert(varchar(8),@Finishdate,112)
)
