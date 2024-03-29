CREATE 
  function [dbo].[QORT_Analytic_TradeSettlement] (@Date int) 
returns table
as
return
(select E.*, 
		P.PhaseAccount_ExportCode as Account,
		QtyBefore as Amount,
		iif (P.TT_Const in (3,6), 'REPO',  
		iif (TT.PT_Const = 1, 'BOND', 'EQUITY')) as Product,
		P.PhaseAsset_ShortName as Asset,
		P.TSSection_Name as TSectionName
		from QORT_DDM.dbo.QORT_EDW_TradeSettlement (@Date, @Date) E
inner loop join QORT_TDB_PROD..Phases P with (nolock, index (PK_Phases))
ON P.SystemID = E.SystemID
inner loop join QORT_TDB_PROD..Trades TT with (nolock, index (PK_Trades)) ON TT.SystemID = P.Trade_SID
)

/*select * from [QORT_DDM].[dbo].[QORT_Analytic_TradeSettlement](20190529) order by SystemID, Direction*/
