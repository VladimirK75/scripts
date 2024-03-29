

/*
select * from [dbo].[GetDDM_TradeFees_VN] (20180419, NULL, NULL, NULL) where NostroID = 'NKCKB_ANY_RENBR_TE.04'
GO
sp_helptext  [GetDDM_TradeFees_VN]
*/


CREATE FUNCTION [dbo].[GetDDM_TradeFees_VN](@intDate int, @LoroID varchar(6) = null, @ClientID varchar(5) = null, @ChargeType varchar(50) = null)
RETURNS TABLE
AS
RETURN
 WITH DDM_TradeFees(ID, EntityID, BookID, CounterpartyID, ClientID,
  SubAccCode, LoroID, NostroID, TraderID, UserID,
   TradeDate, Direction, Currency, TechCenterCom, ExchangeCom,
    ClearingCom, BackOfficeNotes, ChargeType, TransactingCapacity, TSSection,
	 TCA, ExchangeSector, ExchangeID, ExchangeCode, MIC,
	  IsCanceled, ExpenseBook)
  AS
  (
    SELECT  
	  PH.SystemID AS ID,
	  --isnull(TR.BrokerFirm_BOCode, 'RENBR') AS EntityID,
	  isnull(nullif(TR.BrokerFirm_BOCode,''), 'RENBR')  AS EntityID,
      case
	    when TR.SubAcc_Code like 'RB%' then 'ETWARB'	--WASH Book for ETG Clients!!!
		else 'UAGNRB'									--WASH Book for non-ETG Clients!!! MUREX Book!
	  end
	   AS BookID,										--Mapping depending on Entity, Client and/or Market is required
      MM.PartyID AS CounterpartyID,
      TR.SubAccOwner_BOCode AS ClientID,
	  TR.SubAcc_Code AS SubAccCode,						--SubAccCode
      case
	    when TR.SubAccOwner_BOCode = 'RENBR' then ''
		when TR.SubAccOwner_BOCode = 'RESEC' and TR.SubAcc_Code not in ('RB0331', 'RB0441', 'RB0446', 'RB0447', 'RB0448')
		 then 'UMG873'
		else TR.SubAcc_Code
	  end as LoroID,									--SubAccCode
	  A.AccountCode AS NostroID,						--NOSTRO logic changed 20161223
--	  TR.PayAccount_ExportCode AS NostroID,				--NOSTRO account
	  'NONE' AS TraderID,
	  'NONE' AS UserID,
       TR.TradeDate AS TradeDate,						-- Date
 	  -1 AS Direction,
	  case
		when PH.PhaseAsset_ShortName  = 'RUR' then 'RUB'
		else PH.PhaseAsset_ShortName
	  end AS Currency,									--Currency
	  case when PH.IsCanceled = 'n' then
	  TR.TechCenterComission
	  else 0 end AS TechCenterCom,						--'EXCH_INFTECS_FEE' 'MICEX TechCenter Commission'
	  case when PH.IsCanceled = 'n' then
	  TR.ExchangeComission
	  else 0 end AS ExchangeCom,						--'EXCH_TRADE_FEE' 'MICEX Exchange Commission'
	  case when PH.IsCanceled = 'n' then
	  TR.ClearingComission
	  else 0 end AS ClearingCom,						--'EXCH_CLEAR_FEE' 'MICEX Clearing Commission'
      '' AS BackOfficeNotes,
	  '' AS ChargeType,
	  case
		when TR.SubAccOwner_BOCode = 'RENBR' then 'Principal'
		else 'Agency'
	  end AS TransactingCapacity,
	  '' AS TSSection,									--TR.TSSection_Name (deleted 20170109)
	  '' AS TCA,										--TR.QUIKClassCode (deleted 20170109)
	  MM.ExchangeSector AS ExchangeSector,
	  MM.MarketPlace AS ExchangeID,
	  MM.MarketPlace AS ExchangeCode,
	  MM.MIC AS MIC,
	  PH.IsCanceled AS IsCanceled,
      case
		when TR.SubAcc_Code like 'RB%' and TR.SubAccOwner_BOCode  = 'RESEC' then
		case 
			when TR.TT_Const in (8, 12) then  'ETWARC'  --ETG SELT DMC from 20180312
			when TR.TT_Const in (1, 2, 7) and
				(TR.Comment like '%DMC181%' 
				or TR.Comment like '%DMC310%'
				or TR.Comment like '%DMC340%'
				or TR.Comment like '%DMC404%'
				or TR.Comment like '%DMC415%'
				or TR.Comment like '%DMC416%'
				or TR.Comment like '%DMC437%'
				or TR.Comment like '%DMC438%'
				or TR.Comment like 'RB331/EX%') 
			then 'ETS0RC'								--ETG SPOT ExecutionOnly
			when TR.TT_Const in (1, 2, 7) and
				(TR.Comment not like '%DMC181%' 
				and TR.Comment not like '%DMC310%'
				and TR.Comment not like '%DMC340%'
				and TR.Comment not like '%DMC404%'
				and TR.Comment not like '%DMC415%'
				and TR.Comment not like '%DMC416%'
				and TR.Comment not like '%DMC437%'
				and TR.Comment not like '%DMC438%'
				and TR.Comment not like 'RB331/EX%')
			then 'ET00RC'								--ETG SPOT DMC from 20180221
--			when TR.TT_Const = 3
--			then 'ETR1RC'								--ETG REPO DMC
		else ''											--empty for non-ETG Clients and RB clients
	  end 
      when  TR.SubAcc_Code like 'RB%' and TR.SubAccOwner_BOCode  <> 'RESEC' then 
/*        case 
			when TR.TT_Const in (8, 12) then  'ETWARC'  --ETG SELT RB
            when TR.TT_Const = 3 then 'ETR1RB'		    --REPO RB
            else 'ETCMRB'
        end
*/   '' end as ExpenseBook
	FROM       QORT_TDB_PROD..Trades AS TR with (nolock)
	INNER JOIN QORT_DB_PROD..Accounts AS A with (nolock)
			   ON TR.PayAccount_ExportCode COLLATE Cyrillic_General_CI_AS = A.ExportCode COLLATE Cyrillic_General_CI_AS
	LEFT OUTER JOIN QORT_DDM..MarketMap MM with (nolock)
			   ON TR.TSSection_Name = MM.Name
    INNER JOIN QORT_TDB_PROD..Phases AS PH with (nolock)
			   ON TR.SystemID = PH.Trade_SID
	WHERE
     TR.TradeDate = @intDate
	 AND ((TR.SubAcc_Code like 'RB%' and TR.SubAccOwner_BOCode not in ('RESEC', 'FOGGI'))
        or (TR.SubAccOwner_BOCode = 'RESEC' and
	(TR.Comment like '%/D%' or TR.Comment like '%/C%' or TR.Comment like '%/EX%'))
	 and tr.Comment not like '%colibri%')

 --  AND PH.IsCanceled = 'n'							--To deploy without this filtration!!!
	 AND (TR.TechCenterComission <> 0 OR TR.ExchangeComission <> 0 OR TR.ClearingComission <> 0)
     AND TR.TT_Const in (1, 2, 3, 7, 8, 12)				--SPOT, REPO, SELT
	 AND PH.PC_Const in (8)								--Payment of exchange commissions

UNION
    SELECT  
	  PH.SystemID AS ID,
	  --isnull(TR.BrokerFirm_BOCode, 'RENBR') AS EntityID,
	  isnull(nullif(TR.BrokerFirm_BOCode,''), 'RENBR')  AS EntityID,
      case
	    when TR.SubAcc_Code like 'DC%' then 'ETWARB'	--WASH Book for ETG Clients!!!
		else 'UAGNRB'									--WASH Book for non-ETG Clients!!!
	  end
	   AS BookID,	
	  'NKCKB' AS CounterpartyID,							--20180315
      TR.SubAccOwner_BOCode AS ClientID,
	  TR.SubAcc_Code AS SubAccCode,						--SubAccCode
      case
	    when TR.SubAccOwner_BOCode = 'RENBR' then ''
		when TR.SubAccOwner_BOCode = 'RESEC' and TR.SubAcc_Code not like 'DC%' then 'UMG873'
		when TR.SubAccOwner_BOCode = 'RESEC' and TR.SubAcc_Code like 'DC%' then 'RBF331'
		else TR.SubAcc_Code
	  end as LoroID,									--SubAccCode
	  A.AccountCode AS NostroID,						--NOSTRO logic changed 20161223
--	  TR.PayAccount_ExportCode AS NostroID,				--NOSTRO account
	  'NONE' AS TraderID,
	  'NONE' AS UserID,
       PH.Date AS TradeDate,							--Date was changed from TR.TradeDate (20170106)
 	  -1 AS Direction,
	  case
		when PH.PhaseAsset_ShortName  = 'RUR' then 'RUB'
		else PH.PhaseAsset_ShortName
	  end AS Currency,									--Currency
	  0 AS TechCenterCom,								--No TechCenter Commission on FORTS
	  case when TR.FunctionType <> 7 and PH.IsCanceled = 'n' then
	  PH.QtyBefore
	  else 0 end AS ExchangeCom,						--'EXCH_TRADE_FEE' 'FORTS Exchange Commission'
	  case when TR.FunctionType = 7 and PH.IsCanceled = 'n' then
	  PH.QtyBefore
	  else 0 end AS ClearingCom,						--'EXCH_CLEAR_FEE' 'FORTS Clearing Commission'
      '' AS BackOfficeNotes,
	  '' AS ChargeType,
	  case
		when TR.SubAccOwner_BOCode = 'RENBR' then 'Principal'
		else 'Agency'
	  end AS TransactingCapacity,
	  '' AS TSSection,									--TR.TSSection_Name (deleted 20170109)
	  '' AS TCA,										--TR.QUIKClassCode (deleted 20170109)
	  MM.ExchangeSector AS ExchangeSector,
	  MM.MarketPlace AS ExchangeID,
	  MM.MarketPlace AS ExchangeCode,
	  MM.MIC AS MIC,
	  PH.IsCanceled AS IsCanceled,
	  'ETWARC' AS ExpenseBook							--from 20180312
	FROM       QORT_TDB_PROD..Trades AS TR with (nolock)
	INNER JOIN QORT_DB_PROD..Accounts AS A with (nolock)
			   ON TR.PayAccount_ExportCode COLLATE Cyrillic_General_CI_AS = A.ExportCode COLLATE Cyrillic_General_CI_AS
	LEFT OUTER JOIN QORT_DDM..MarketMap MM with (nolock)
			   ON TR.TSSection_Name = MM.Name
    INNER JOIN QORT_TDB_PROD..Phases AS PH with (nolock)
			   ON TR.SystemID = PH.Trade_SID
    WHERE
     PH.Date = @intDate									--Date was changed from TR.TradeDate (20170106)
     AND (TR.SubAcc_Code like 'DC%'						--To deploy with this filtration!!!
	 OR TR.SubAcc_Code = 'SPBFUT00TSS'
	 OR (TR.SubAcc_Code like 'RBF%' and TR.SubAccOwner_BOCode  <> 'RESEC'))						--To deploy with this filtration!!!
--   AND PH.IsCanceled = 'n'							--To deploy without this filtration!!!
     AND TR.TT_Const = 4								--FORTS
	 AND PH.PC_Const in (8)								--Payment of exchange commissions
)

SELECT replace('QRTCC_'+ SubAccCode + '_' + NostroID COLLATE Cyrillic_General_CS_AS + '_' + BookID + '_' + ExpenseBook + '_' + ExchangeSector COLLATE Cyrillic_General_CS_AS + '_' +right(TradeDate,6) COLLATE Cyrillic_General_CS_AS,' ','_')  as ID,
	   -- + convert(varchar(20), cast(min(ID) as numeric(18,0))), 
	   EntityID,
	   EntityID AS EntityCode,
       BookID,
	   BookID AS BookCode,
       'MICEX' AS CounterpartyID,						--20180315
	   'MICEX' AS CounterpartyCode,						--20180315
	   ClientID,
	   ClientID AS ClientCode,
	   SubAccCode,
	   LoroID,
	   LoroID AS LoroCode,
	   NostroID,
	   NostroID AS NostroCode,
	   TraderID,
	   TraderID AS TraderName,
	   UserID,
	   UserID AS UserName,
	   TradeDate AS TradeDate,
	   TradeDate AS SettleDate,
	   Direction,
	   Currency,
	   sum(TechCenterCom) AS Amount,
	   'MICEX TechCenter Commission' AS BackOfficeNotes,
	   'EXCH_INFTECS_FEE' AS ChargeType,
	   TransactingCapacity,
	   TSSection,
	   TCA,
	   ExchangeSector,
	   ExchangeID,
	   ExchangeCode,
	   MIC,
	   ExpenseBook
FROM DDM_TradeFees
WHERE (LoroID = @LoroID or @LoroID is null)
  AND (ClientID = @ClientID or @ClientID is null)
  AND (ChargeType = @ChargeType or @ChargeType is null)
--  AND TechCenterCom <> 0
GROUP BY EntityID, BookID, CounterpartyID, ClientID,
  SubAccCode, LoroID, NostroID, TraderID, UserID,
   Direction, TradeDate, Currency, BackOfficeNotes, ChargeType, TransactingCapacity,
	 TSSection, TCA, ExchangeSector, ExchangeID, ExchangeCode, MIC, ExpenseBook

UNION ALL
SELECT replace('QREXC_'+ SubAccCode + '_' + NostroID COLLATE Cyrillic_General_CS_AS + '_' + BookID + '_' + ExpenseBook + '_' + ExchangeSector COLLATE Cyrillic_General_CS_AS + '_' +right(TradeDate,6) COLLATE Cyrillic_General_CS_AS,' ','_')  as ID,
	   EntityID,
	   EntityID AS EntityCode,
       BookID,
	   BookID AS BookCode,
       case
	    when CounterpartyID = 'NKCKB' then 'NKCKB'
		else 'MICEX'
	   end AS CounterpartyID,							--20180315
	   case
	    when CounterpartyID = 'NKCKB' then 'NKCKB'
	   else 'MICEX'
	   end AS CounterpartyCode,							--20180315
	   ClientID,
	   ClientID AS ClientCode,
	   SubAccCode,
	   LoroID,
	   LoroID AS LoroCode,
	   NostroID,
	   NostroID AS NostroCode,
	   TraderID,
	   TraderID AS TraderName,
	   UserID,
	   UserID AS UserName,
	   TradeDate AS TradeDate,
	   TradeDate AS SettleDate,
	   Direction,
	   Currency,
	   sum(ExchangeCom) AS Amount,
	   case
			when CounterpartyID = 'MICEX' then 'MICEX Exchange Commission'
			when CounterpartyID = 'NKCKB' then 'FORTS Exchange Commission'
	   else 'Exchange Commission' end
		AS BackOfficeNotes,
	   'EXCH_TRADE_FEE' AS ChargeType,
	   TransactingCapacity,
	   TSSection,
	   TCA,
	   ExchangeSector,
	   ExchangeID,
	   ExchangeCode,
	   MIC,
	   ExpenseBook
FROM DDM_TradeFees
WHERE (LoroID = @LoroID or @LoroID is null)
  AND (ClientID = @ClientID or @ClientID is null)
  AND (ChargeType = @ChargeType or @ChargeType is null)
--  AND ExchangeCom <> 0
GROUP BY EntityID, BookID, CounterpartyID, ClientID,
  SubAccCode, LoroID, NostroID, TraderID, UserID,
   Direction, TradeDate, Currency, BackOfficeNotes, ChargeType, TransactingCapacity,
	 TSSection, TCA, ExchangeSector, ExchangeID, ExchangeCode, MIC, ExpenseBook

	UNION ALL
SELECT replace('QRCLC_'+ SubAccCode + '_' + NostroID COLLATE Cyrillic_General_CS_AS + '_' + BookID + '_' + ExpenseBook + '_' + ExchangeSector COLLATE Cyrillic_General_CS_AS + '_' +right(TradeDate,6) COLLATE Cyrillic_General_CS_AS,' ','_')  as ID,
	   EntityID,
	   EntityID AS EntityCode,
       BookID,
	   BookID AS BookCode,
       'NKCKB' AS CounterpartyID,						--20180315
	   'NKCKB' AS CounterpartyCode,						--20180315
	   ClientID,
	   ClientID AS ClientCode,
	   SubAccCode,
	   LoroID,
	   LoroID AS LoroCode,
	   NostroID,
	   NostroID AS NostroCode,
	   TraderID,
	   TraderID AS TraderName,
	   UserID,
	   UserID AS UserName,
	   TradeDate AS TradeDate, -- Date
	   TradeDate AS SettleDate,
	   Direction,
	   Currency,
	   sum(ClearingCom),
	   'MICEX Clearing Commission' AS BackOfficeNotes,
	   'EXCH_CLEAR_FEE' AS ChargeType,
	   TransactingCapacity,
	   TSSection,
	   TCA,
	   ExchangeSector,
	   ExchangeID,
	   ExchangeCode,
	   MIC,
	   ExpenseBook
FROM DDM_TradeFees
WHERE (LoroID = @LoroID or @LoroID is null)
  AND (ClientID = @ClientID or @ClientID is null)
  AND (ChargeType = @ChargeType or @ChargeType is null)
--  AND ClearingCom <> 0
GROUP BY EntityID, BookID, CounterpartyID, ClientID,
  SubAccCode, LoroID, NostroID, TraderID, UserID,
   Direction, TradeDate, Currency, BackOfficeNotes, ChargeType, TransactingCapacity,
	 TSSection, TCA, ExchangeSector, ExchangeID, ExchangeCode, MIC, ExpenseBook

/*
select * from [QORT_DB_PROD]..[TSSections] where
Name like '%SELT%'
or Name like '%SWAP%'
or Name like '%FORTS%'
order by id

select * from [dbo].[MarketMap] where
Name like '%SELT%'
or Name like '%SWAP%'
or Name like '%FORTS%'
*/
