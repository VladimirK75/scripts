/***********************
Author: Kirill
Date:   2018-06-04
***********************/
CREATE    procedure [dbo].[QORT_to_1C] (@date nchar(8))
as 
BEGIN 						

select	ac.FactCode,
		ac.AccountCode,
		sum (ph.VolFree)/*+ph.VolForward)*/ as Balance,
		a.ShortName as Currency
from [QORT_DB_PROD].dbo.PositionHist ph with(nolock)
	join [QORT_DB_PROD].dbo.accounts ac with(nolock)
	on ac.id = ph.Account_ID
	join [QORT_DB_PROD].dbo.assets a with(nolock)
	on a.id=ph.Asset_ID
	and a.AssetSort_Const in (15,16)
where OldDate = @date
	and (ph.VolFree)/*+ph.VolForward)*/<>0
group by ac.AccountCode,ac.FactCode,ShortName
order by ac.FactCode,ac.AccountCode,a.ShortName

END
