CREATE PROCEDURE [dbo].[QORT_setSPBRepo2Fees]
AS
BEGIN
DECLARE @SessionDate int =(select session_date from QORT_DB_PROD..[Session]with(nolock))  -- дата, на которую подбираются 2-ые части СПБ РЕПО по PayPlannedDate!

--select top 10 IsProcessed,ErrorLog, *   FROM [QORT_TDB_PROD].[dbo].[Phases]with(nolock)  where PC_Const=8 order by id desc   -- where InfoSource='QS_WA_SPBREPO2_feesfix'

/*
'СПБ: РЕПО'
проверяем, если есть этапы биржевой комиссии на текущий опердень - ничего не делаем, не важно по 1ой или по 2ой ноге
Если этапов нет - переносим биржевую комиссию с 1-ой ноги на 2-ую и инсертим по 2ой ноге
*/
if not exists (select	p.id	from QORT_DB_PROD..trades tr2 with(nolock) 
						join QORT_DB_PROD..trades tr1 with(nolock) on tr2.RepoTrade_ID=tr1.id
						join QORT_DB_PROD..Phases p  with(nolock) on p.Trade_ID=tr2.id or p.Trade_ID=tr1.id 
								where 
								1=1
								and tr2.IsProcessed='y'
								and tr2.NullStatus='n'
								and tr2.IsDraft='n'
								and tr1.TSCommission<>0
								and tr2.TSSection_ID=(select id from QORT_DB_PROD..TSSections with(nolock) where [Name]='СПБ: РЕПО')
								and tr2.PayPlannedDate=@SessionDate
								and p.PC_Const=8
								and p.IsProcessed='y'
								and p.IsCanceled='n')
begin

-- переносим биржевую комиссию с 1-ой ноги на 2-ую
update 	tr2	
set tr2.TSCommission = tr1.TSCommission
	--,tr2.ClearingComission = tr1.ClearingComission  --если понадобится перносить клиринговую комиссию 
from QORT_DB_PROD..trades tr2 with(nolock) 
join QORT_DB_PROD..trades tr1 with(nolock) on tr2.RepoTrade_ID=tr1.id
where 
1=1
and tr2.IsProcessed='y'
and tr2.NullStatus='n'
and tr2.IsDraft='n'
and tr2.IsRepo2='y'
and tr1.TSCommission<>0
and tr2.TSSection_ID=(select id from QORT_DB_PROD..TSSections with(nolock) where [Name]='СПБ: РЕПО')
and tr2.PayPlannedDate=@SessionDate

-- инсертим биржевую комиссию по 2ой ноге
INSERT INTO QORT_TDB_PROD..[Phases]
(	[id]
           ,[PC_Const]
           ,[InfoSource]
           ,[BackID]
		   ,[SystemID]
           ,[Date]
           ,[Time]
           ,[Trade_SID]
		   ,[QtyBefore]
		   ,[QtyAfter]
		   ,[SubAcc_Code]
		   ,[IsProcessed])

select		[id]=-1
           ,[PC_Const]=8
           ,[InfoSource]='BackOffice'
           ,[BackID]=cast (newid() as varchar(max))
		   ,[SystemID]=-1
           ,[Date]=tr2.[PayPlannedDate]
           ,[Time]=format(getdate(),'HHmmssfff')
           ,[Trade_SID]=tr2.id
		   ,[QtyBefore]=tr1.TSCommission
		   ,[QtyAfter]=-1
		   ,[SubAcc_Code]=(select SubAccCode from QORT_DB_PROD..[Subaccs]with(nolock)where id=tr2.SubAcc_ID )
		   ,[IsProcessed]=1
--,tr2.id,tr2.TradeDate,tr2.PayPlannedDate,tr2.IsRepo2,tr1.TSCommission 
from QORT_DB_PROD..trades tr2 with(nolock) 
join QORT_DB_PROD..trades tr1 with(nolock) on tr2.RepoTrade_ID=tr1.id
where 
1=1
and tr2.IsProcessed='y'
and tr2.NullStatus='n'
and tr2.IsDraft='n'
and tr2.IsRepo2='y'
and tr1.TSCommission<>0
and tr2.TSSection_ID=(select id from QORT_DB_PROD..TSSections with(nolock) where [Name]='СПБ: РЕПО')
and tr2.PayPlannedDate=@SessionDate

end


END
