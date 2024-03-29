/***********************
Author: K.Bolshesolsky
Date:   2019-05-23
Modified: I.Kharkova
Modified On: 2019-07-24
***********************/
CREATE     FUNCTION [dbo].[QORT_1C_Sec_Position](@date date, @time int = null)
RETURNS TABLE
as 
Return 
(

select	ass.ShortName,
        ass.ISIN,
        ass.Marking,
        sum(asd.TheorPos) as TheorPos
from 
(
select ph.Subacc_ID
     , ph.Asset_ID
     , TheorPos = sum(ph.volfree) + sum(ph.volblocked) + sum(ph.VolForward)
  from QORT_DB_PROD..PositionHist ph with(nolock)
where ph.Subacc_ID = 2371 /*-RENBR*/
       and ph.OldDate = convert(varchar(8),dateadd(dd,-1,@date),112)
--	   and ph.Account_ID not in (3177,2279,3178,3179,2180)
group by ph.Subacc_ID
        ,ph.Asset_ID
having (sum(ph.volfree) + sum(ph.volblocked) + sum(ph.VolForward)) <> 0
union 

select cp.Subacc_ID
     , cp.Asset_ID
     , TheorPos = sum(cp.size)
  from QORT_DB_PROD..CorrectPositions cp with(nolock)
where cp.Subacc_id = 2371
       and cp.created_date = convert(varchar(8),@date,112)
       and cp.enabled = 0
       and cp.date = 0
       and cp.created_time < isnull(@time, 1)
--	   and cp.Account_ID not in (3177,2279,3178,3179,2180)
	   and cp.IsCanceled='n'
group by cp.Subacc_ID
     , cp.Asset_ID

union
select trd.Subacc_ID
		, sec.Asset_ID
		, sum((3-2*trd.BuySell)*trd.Qty) as TheorPos
  from QORT_DB_PROD..Trades trd with(nolock)
  inner loop join QORT_DB_PROD..Securities sec with (nolock, index = I_Securities_ID) 
  on sec.id = trd.Security_ID
where trd.SubAcc_ID = 2371
       and trd.created_date = convert(varchar(8),@date,112)
       and trd.created_time < isnull(@time, 1)
       and trd.Enabled = 0
       and trd.NullStatus='n'
--	   and trd.PutAccount_ID not in (3177,2279,3178,3179,2180)
group by trd.Subacc_ID,
		sec.Asset_ID

) asd
inner join QORT_DB_PROD..assets ass with (nolock)
       on asd.Asset_id = ass.id
       and ass.AssetClass_Const not in (1,2)
group by ass.ShortName,
        ass.ISIN,
        ass.Marking
)
