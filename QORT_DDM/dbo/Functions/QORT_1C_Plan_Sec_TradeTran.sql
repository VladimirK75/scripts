/***********************
Author: Kirill
Date:   2019-05-21
***********************/
CREATE   FUNCTION [dbo].[QORT_1C_Plan_Sec_TradeTran](@start_date int, @finish_date int, @start_time int = null, @finish_time int = null)
RETURNS TABLE
as 
Return 
(
select 
				case 
					when trd.IsRepo2='y' then trd.RepoTrade_ID
					else trd.id
				end as 'id',
				--trd.id,
				trd.TradeDate,
				trd.created_date,
				trd.modified_date,
				trd.PutPlannedDate,
				ass.ShortName,
				trd.Qty,
				trd.Nullstatus,
				case when trd.TT_Const in (3, 6) then 'REPO'
                     else case when AssetClass_Const in (6, 7, 9) then 'BOND'
                               else case when AssetClass_Const in (8, 16) then 'ADR'
                                         else 'EQUITY'
                end end end as Product
from QORT_DB_PROD..trades trd with(nolock)
	join QORT_DB_PROD..Securities scr with(nolock)
	on scr.id=trd.Security_ID
	join QORT_DB_PROD..Assets ass with(nolock)
	on scr.Asset_ID=ass.id
	join QORT_DB_PROD..TSSections tss with(nolock)
	on tss.id=trd.TSSection_ID
	join QORT_DB_PROD..Accounts acc with(nolock)
	on acc.id=trd.PutAccount_ID
where trd.Enabled=0
	and trd.TT_Const in (1, 2, 3, 5, 6, 7, 14)
	and trd.TradeDate between @start_date and @finish_date
	and trd.TradeTime between isnull(@start_time,1) and isnull(@finish_time,235959999)
	and trd.SubAcc_ID = 2371 --RENBR
	and (trd.QFlags&67108864 = 0 or (trd.IsRepo2='y' and trd.QFlags&67108864 = 67108864))
--	and acc.AccountCode not like 'Non%'
)
