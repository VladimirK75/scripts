CREATE   function [dbo].[GetDDM_TradeVM] ( 
                @intDate  int
              , @LoroID   varchar(6)  = null
              , @ClientID varchar(5)  = null
              , @NostroID varchar(50) = null ) 
returns table
as
return
with DDM_TradeVM(ID
               , EntityID
               , BookID
               , CounterpartyID
               , ClientID
               , SubAccCode
               , LoroID
               , NostroID
               , TraderID
               , UserID
               , TradeDate
               , Direction
               , Currency
               , Amount
               , BackOfficeNotes
               , ChargeType
               , TransactingCapacity
               , TradeType
               , ExchangeSector
               , ExchangeID
               , ExchangeCode
               , MIC
               , IsCanceled)
     as (select ID = PH.SystemID
              , EntityID = isnull(TR.BrokerFirm_BOCode, 'RENBR')
              , BookID = 'NONE'
              , CounterpartyID = 'NKCKB'
              , ClientID = TR.SubAccOwner_BOCode
              , SubAccCode = TR.SubAcc_Code
              , LoroID = case
                              when TR.SubAccOwner_BOCode = 'RENBR' then ''
                              when TR.SubAcc_Code = 'RESEC' then 'UMG873'
                            else TR.SubAcc_Code
                         end
              , NostroID = TR.PutAccount_ExportCode
              , TraderID = 'NONE'
              , UserID = 'NONE'
              , TradeDate = PH.Date
              , Direction = PH.QtyAfter
              , Currency = replace(PH.PhaseAsset_ShortName, 'RUR', 'RUB')
              , PH.QtyBefore as Amount
              , BackOfficeNotes = case
                                       when PH.TT_Const = 8 then 'SELT FUTS Variation margin'
                                       when PH.TT_Const = 12 then 'SELT SWAP Variation margin'
                                  end
              , ChargeType = 'VARIATION_MARGIN'
              , TransactingCapacity = iif(TR.SubAccOwner_BOCode = 'RENBR', 'Principal', 'Agency')
              , TradeType = PH.TT_Const
              , ExchangeSector = case
                                      when PH.TT_Const = 8 then 'MICEX SELT FUTS'
                                      when TR.TSSection_Name = 'MICEX SWAP' then 'SWAP'
                                      when TR.TSSection_Name = 'MICEX SWAP FUTS' then 'SWAP FUTS'
                                 end
              , ExchangeID = 'MICEX'
              , ExchangeCode = 'MICEX'
              , MIC = 'MISX'
              , IsCanceled = isnull(PH.IsCanceled, 'n')
           from QORT_TDB_PROD..Phases as PH with(nolock)
           inner join QORT_TDB_PROD..Trades as TR with(nolock) on PH.Trade_SID = TR.SystemID
          where PH.Date = @intDate
                and isnull(PH.IsCanceled, 'n') = 'n'
                and PH.QtyBefore <> 0
                and PH.PC_Const = 21
                and PH.TT_Const in (8, 12)
				and 0=1 )
     select ID
          , EntityID
          , EntityCode = EntityID
          , BookID
          , BookCode = BookID
          , CounterpartyID
          , CounterpartyCode = CounterpartyID
          , ClientID
          , ClientCode = ClientID
          , SubAccCode
          , LoroID
          , LoroCode = LoroID
          , NostroID = QORT_DDM.dbo.GetDDM_NostroMapping(NostroID, 'Единый пул', 0)
          , NostroCode = NostroID
          , TraderID
          , TraderName = TraderID
          , UserID
          , UserName = UserID
          , TradeDate = TradeDate
          , SettleDate = TradeDate
          , Direction
          , Currency
          , Amount
          , BackOfficeNotes
          , ChargeType
          , TransactingCapacity
          , TradeType
          , ExchangeSector
          , ExchangeID
          , ExchangeCode
          , MIC
          , IsCanceled
       from DDM_TradeVM
      where 1 = 1
            and LoroID = isnull(@LoroID, LoroID)
            and ClientID = isnull(@ClientID, ClientID)
            and NostroID = isnull(@NostroID, NostroID)
