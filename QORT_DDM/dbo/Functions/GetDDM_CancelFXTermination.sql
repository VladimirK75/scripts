

CREATE FUNCTION [dbo].[GetDDM_CancelFXTermination](@intDate int, @LoroID varchar(6) = null, @ClientID varchar(5) = null, @NostroID varchar(50) = null)
RETURNS TABLE
AS
RETURN
 WITH DDM_CancelFXTermination(ID, TradeRef, TradeExchRef, FXTradeType, Direction,
  EntityID, ClientID, LoroID, NostroID, MaturityDate,
   ValueDate, PayAmount, PayCurrency, PutAmount, PutCurrency,
    IssueID, ExchangeSector, ExchangeID, ExchangeCode, MIC)
  AS
  (
    SELECT 
	  PUT.SystemID as ID,
	  TR.SystemID as TradeRef,
	  case
	    when TR.TT_Const = 8 then TR.TradeNum
		else TR.TradeNum-2
	  end AS TradeExchRef,
      TR.TT_Const as FXTradeType,
      case TR.BuySell
        when 1 then 'BUY'
		when 2 then 'SELL'
      end AS Direction,
	  'RENBR' AS EntityID,
      TR.SubAccOwner_BOCode as ClientID, 
      TR.SubAcc_Code as LoroID, -- SubAccCode
	  A.TradeCOde as NostroID, -- NOSTRO account 
      TR.PayPlannedDate as MaturityDate,
	  PAY.Date AS ValueDate, -- Date 
      PAY.QtyBefore AS PayAmount,
	  case
		when PAY.PhaseAsset_ShortName = 'RUR' then 'RUB'
		else PAY.PhaseAsset_ShortName
	  end AS PayCurrency, -- Currency 
      PUT.QtyBefore AS PutAmount,
	  case
		when PUT.PhaseAsset_ShortName = 'RUR' then 'RUB'
		else PUT.PhaseAsset_ShortName
	  end AS PutCurrency, -- Currency 
	  (select top 1 GrdbID from GRDBServices.Publication.CurrPairGrdbMap
		where FirstCurrency = (case
		when PUT.PhaseAsset_ShortName = 'RUR' then 'RUB'
		else PUT.PhaseAsset_ShortName
	    end)
		and SecondCurrency = (case
		when PAY.PhaseAsset_ShortName = 'RUR' then 'RUB'
		else PAY.PhaseAsset_ShortName
	    end)) AS IssueID, --FX IssueID
	  'MICEX' AS ExchangeSector,
	  'MICEX' AS ExchangeID,
	  'MICEX' AS ExchangeCode,
	  'MISX' AS MIC
    FROM QORT_TDB_PROD..Phases AS PAY with (nolock) 
   INNER JOIN QORT_TDB_PROD..Phases AS PUT with (nolock) ON PUT.Trade_SID = PAY.Trade_SID --AND PUT.PC_Const in (3,4) AND PUT.Date = PAY.Date
   INNER JOIN QORT_TDB_PROD..Trades AS TR with (nolock) ON PAY.Trade_SID = TR.SystemID --AND PAY.Date < TR.PayPlannedDate 
   INNER JOIN QORT_DB_PROD..Accounts AS A with (nolock) ON TR.PutAccount_ExportCode COLLATE Cyrillic_General_CI_AS = A.ExportCode COLLATE Cyrillic_General_CI_AS
    WHERE PAY.Date = @intDate
	  AND PUT.Date = @intDate
	  AND PAY.TT_Const in (8,12) -- FX and SWAP
      AND PAY.PC_Const in (5,7)
	  AND PUT.PC_Const in (3,4)
	  AND PAY.IsCanceled = 'y'
      AND PUT.IsCanceled = 'y'
      --AND TR.QUIKClassCode in ('CNGD', 'CETS', 'FUTS')
	  AND (TR.TSSection_Name in ('MICEX SELT FUTS', 'MICEX SWAP FUTS')
	  OR (TR.TSSection_Name in ('MICEX SWAP') and QFlags & 1048576 = 1048576))
      AND TR.PayPlannedDate >= PAY.Date
	  --AND TR.Systemid = 18460556
)

/* for Aggregated FX Trades ROL Only */
/*
SELECT NostroID COLLATE Cyrillic_General_CI_AS 
    + PutCurrency COLLATE Cyrillic_General_CI_AS 
    + PayCurrency COLLATE Cyrillic_General_CI_AS 
    + Direction COLLATE Cyrillic_General_CI_AS
    + cast(MaturityDate as varchar(20)) COLLATE Cyrillic_General_CI_AS 
    + cast(ValueDate as varchar(20)) COLLATE Cyrillic_General_CI_AS  as ID, 
	   null as TradeRef, 
       FXTradeType,
	   Direction,
	   EntityID,
       ClientID, 
       LoroID, -- SubAccCode
	   NostroID, 
	   MaturityDate, -- Date
       ValueDate, 
	   sum(PayAmount) as PayAmount, -- Currency
	   PayCurrency,
	   sum(PutAmount) as PutAmount, 
       PutCurrency
FROM DDM_FXTermination
WHERE (LoroID = @LoroID or @LoroID is null)
  AND (ClientID = @ClientID or @ClientID is null)
  AND (NostroID = @NostroID or @NostroID is null)
  AND FXTradeType = 8
GROUP BY FXTradeType, Direction, ClientID, LoroID, NostroID, MaturityDate, ValueDate, PayCurrency, PutCurrency
UNION
*/
SELECT 'BNT' + convert(varchar(20), cast(id as numeric(18,0))) COLLATE Cyrillic_General_CI_AS /*+ cast(ValueDate as varchar(30)) COLLATE Cyrillic_General_CI_AS*/ as ID,
	   'QR' + convert(varchar(20), cast(TradeRef as numeric(18,0))) COLLATE Cyrillic_General_CI_AS as TradeRef,
	   ltrim(str(TradeExchRef)) as TradeExchRef,
       FXTradeType,
       Direction,
	   EntityID,
	   EntityID AS EntityCode,
       ClientID,
	   ClientID AS ClientCode,
       case
	    when LoroID = 'RESEC' then 'UMG873'
		else LoroID
	   end as LoroID, -- SubAccCode
	   case
	    when LoroID = 'RESEC' then 'UMG873'
		else LoroID
	   end as LoroCode, -- SubAccCode
	   NostroID,
	   NostroID AS NostroCode,
	   MaturityDate, -- Date
       ValueDate, 
	   PayAmount as PayAmount, -- Currency
	   PayCurrency,
	   PutAmount as PutAmount, 
       PutCurrency,
	   IssueID,
	   ExchangeSector,
	   ExchangeID,
	   ExchangeCode,
	   MIC
FROM DDM_CancelFXTermination
WHERE (LoroID = @LoroID or @LoroID is null)
  AND (ClientID = @ClientID or @ClientID is null)
  AND (NostroID = @NostroID or @NostroID is null)
  --AND FXTradeType = 12
  --GROUP BY TradeRef, FXTradeType, Direction, ClientID, LoroID, NostroID, MaturityDate, ValueDate, PayCurrency, PutCurrency, IssueID

/*
select * from [dbo].[GetDDM_CancelFXTermination] (20160921, null, null, null)
*/
