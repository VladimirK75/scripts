CREATE   function [dbo].[GetDDM_FXTermination] ( 
                @intDate  int
              , @LoroID   varchar(6)  = null
              , @ClientID varchar(5)  = null
              , @NostroID varchar(50) = null ) 
returns table
as
return
with DDM_FXTermination(ID
                     , TradeRef
                     , TradeExchRef
                     , FXTradeType
                     , Direction
                     , EntityID
                     , ClientID
                     , LoroID
                     , NostroID
                     , MaturityDate
                     , ValueDate
                     , PayAmount
                     , PayCurrency
                     , PutAmount
                     , PutCurrency
                     , IssueID
                     , ExchangeSector
                     , ExchangeID
                     , ExchangeCode
                     , MIC)
     as (select ID = PUT.SystemID
              , TradeRef = TR.SystemID
              , TradeExchRef = iif(TR.TT_Const = 8, TR.TradeNum, TR.TradeNum-2)
              , FXTradeType = TR.TT_Const
              , Direction = iif(TR.BuySell = 1, 'BUY', 'SELL')
              , EntityID = 'RENBR'
              , ClientID = TR.SubAccOwner_BOCode
              , LoroID = TR.SubAcc_Code /* SubAccCode*/              
              , NostroID = A.TradeCOde  /* NOSTRO account */              
              , MaturityDate = TR.PayPlannedDate
              , ValueDate = PAY.Date
              , PayAmount = PAY.QtyBefore
              , PayCurrency = replace(PAY.PhaseAsset_ShortName, 'RUR', 'RUB')
              , PutAmount = PUT.QtyBefore
              , PutCurrency = replace(PUT.PhaseAsset_ShortName, 'RUR', 'RUB')
              , IssueID = (select top 1 GrdbID
                             from GRDBServices.Publication.CurrPairGrdbMap
                            where FirstCurrency = replace(PUT.PhaseAsset_ShortName, 'RUR', 'RUB')
                                  and SecondCurrency = replace(PAY.PhaseAsset_ShortName, 'RUR', 'RUB'))
              , ExchangeSector = case
                                      when TR.TSSection_Name = 'MICEX SELT FUTS' then 'MICEX SELT FUTS'
                                      when TR.TSSection_Name = 'MICEX SWAP FUTS' then 'MICEX SWAP FUTS'
                                      when TR.TSSection_Name = 'MICEX SWAP' then 'SWAP'
                                    else 'MICEX SELT'
                                 end
              , ExchangeID = 'MICEX'
              , ExchangeCode = 'MICEX'
              , MIC = 'MISX'
           from QORT_TDB_PROD..Phases as PAY with(nolock)
           inner join QORT_TDB_PROD..Phases as PUT with(nolock) on PUT.Trade_SID = PAY.Trade_SID
           inner join QORT_TDB_PROD..Trades as TR with(nolock) on PAY.Trade_SID = TR.SystemID
           inner join QORT_DB_PROD..Accounts as A with(nolock) on TR.PutAccount_ExportCode collate Cyrillic_General_CI_AS = A.ExportCode collate Cyrillic_General_CI_AS
          where PAY.Date = @intDate
                and PUT.Date = @intDate
                and PAY.TT_Const in (8, 12) /* FX and SWAP*/        
                and PAY.PC_Const in (5, 7)
                and PUT.PC_Const in (3, 4)
                and isnull(PAY.IsCanceled,'n') = 'n'
                and isnull(PUT.IsCanceled,'n') = 'n'
                and iif(TR.TSSection_Name in ('MICEX SELT FUTS'), 1, 0) 
				  + iif(TR.TSSection_Name in ('MICEX SWAP FUTS') and TR.IsRepo2 = 'y', 1, 0) 
				  + iif(TR.TSSection_Name in ('MICEX SELT РПС') and QFlags&1048576 = 1048576, 1, 0) 
				  + iif(TR.TSSection_Name in ('MICEX SWAP') and QFlags&1048576 = 1048576 and TR.IsRepo2 = 'y', 1, 0)
				  > 0
                and TR.PayPlannedDate >= PAY.Date)
     select ID = 'BNT' + convert(varchar(20), cast(id as numeric(18, 0))) collate Cyrillic_General_CI_AS
          , TradeRef = 'QR' + convert(varchar(20), cast(TradeRef as numeric(18, 0))) collate Cyrillic_General_CI_AS
          , TradeExchRef = ltrim(str(TradeExchRef))
          , FXTradeType
          , Direction
          , EntityID
          , EntityID as  EntityCode
          , ClientID
          , ClientID as  ClientCode
          , LoroID = iif(LoroID = 'RESEC', 'UMG873', LoroID)
          , LoroCode = iif(LoroID = 'RESEC', 'UMG873', LoroID)
          , NostroID
          , NostroID as  NostroCode
          , MaturityDate /* Date*/          
          , ValueDate
          , PayAmount as PayAmount /* Currency*/          
          , PayCurrency
          , PutAmount as PutAmount
          , PutCurrency
          , IssueID
          , ExchangeSector
          , ExchangeID
          , ExchangeCode
          , MIC
       from DDM_FXTermination
      where 1 = 1
            and LoroID = isnull(@LoroID, LoroID)
            and ClientID = isnull(@ClientID, ClientID)
            and NostroID = isnull(@NostroID, NostroID)
