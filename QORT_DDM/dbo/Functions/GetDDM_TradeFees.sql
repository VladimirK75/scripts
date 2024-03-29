CREATE function [dbo].[GetDDM_TradeFees](
               @intDate    int
             , @LoroID     varchar(6)  = null
             , @ClientID   varchar(5)  = null
             , @ChargeType varchar(50) = null)
returns table
as
return
with DDM_TradeFees(ID
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
                 , TechCenterCom
                 , ExchangeCom
                 , ClearingCom
                 , BackOfficeNotes
                 , ChargeType
                 , TransactingCapacity
                 , TSSection
                 , TCA
                 , ExchangeSector
                 , ExchangeID
                 , ExchangeCode
                 , MIC
                 , IsCanceled
                 , ExpenseBook)
     as (select ID = PH.SystemID
              , EntityID = isnull(nullif(TR.BrokerFirm_BOCode, ''), 'RENBR')
              , BookID = iif(iif(left(TR.SubAcc_Code, 2) = 'RB', 1, 0) + iif(left(TR.SubAcc_Code, 2) = 'SB', 1, 0) = 1, 'ETWARB', 'UAGNRB') /*WASH Book for ETG and non-ETG Clients!!!*/
              , CounterpartyID = MM.PartyID
              , ClientID = TR.SubAccOwner_BOCode
              , SubAccCode = TR.SubAcc_Code
              , LoroID = case
                              when TR.SubAccOwner_BOCode = 'RENBR' then ''
                              when TR.SubAccOwner_BOCode = 'RESEC'
                                   and TR.SubAcc_Code not in('RB0331', 'RB0441', 'RB0446', 'RB0447', 'RB0448') then 'UMG873'
                            else TR.SubAcc_Code
                         end
              , NostroID = A.AccountCode
              , TraderID = 'NONE'
              , UserID = 'NONE'
              , TradeDate = TR.TradeDate
              , Direction = -1
              , Currency = replace(PH.PhaseAsset_ShortName, 'RUR', 'RUB')
              , TechCenterCom = iif(isnull(PH.IsCanceled, 'n') = 'n', TR.TechCenterComission, 0) /*'EXCH_INFTECS_FEE' 'MICEX TechCenter Commission'*/              
              , ExchangeCom = iif(isnull(PH.IsCanceled, 'n') = 'n', TR.ExchangeComission, 0) /*'EXCH_TRADE_FEE' 'MICEX Exchange Commission'*/              
              , ClearingCom = iif(isnull(PH.IsCanceled, 'n') = 'n', TR.ClearingComission, 0) /*'EXCH_CLEAR_FEE' 'MICEX Clearing Commission'*/              
              , BackOfficeNotes = ''
              , ChargeType = ''
              , TransactingCapacity = iif(TR.SubAccOwner_BOCode = 'RENBR', 'Principal', 'Agency')
              , TSSection = ''
              , TCA = ''
              , ExchangeSector = MM.ExchangeSector collate Cyrillic_General_CS_AS
              , ExchangeID = MM.MarketPlace collate Cyrillic_General_CS_AS
              , ExchangeCode = MM.MarketPlace collate Cyrillic_General_CS_AS
              , MIC = MM.MIC collate Cyrillic_General_CS_AS
              , IsCanceled = isnull(PH.IsCanceled, 'n')
              , ExpenseBook = case
                                   when iif(left(TR.SubAcc_Code, 2) = 'RB', 1, 0) + iif(left(TR.SubAcc_Code, 2) = 'SB', 1, 0) = 1
                                        and TR.SubAccOwner_BOCode = 'RESEC' then case
                                                                                      when TR.TT_Const in(8, 12) then 'ETWARC'
                                                                                      when TR.TT_Const in(1, 2, 7)
                                                                                           and (TR.Comment like '%DMC181%'
                                                                                                or TR.Comment like '%DMC310%'
                                                                                                or TR.Comment like '%DMC340%'
                                                                                                or TR.Comment like '%DMC404%'
                                                                                                or TR.Comment like '%DMC415%'
                                                                                                or TR.Comment like '%DMC416%'
                                                                                                or TR.Comment like '%DMC437%'
                                                                                                or TR.Comment like '%DMC438%'
                                                                                                or TR.Comment like 'RB331/EX%') then 'ETS0RC'								/*ETG SPOT ExecutionOnly*/
                                                                                      when TR.TT_Const in(1, 2, 7)
                                                                                           and TR.Comment not like '%DMC181%'
                                                                                           and TR.Comment not like '%DMC310%'
                                                                                           and TR.Comment not like '%DMC340%'
                                                                                           and TR.Comment not like '%DMC404%'
                                                                                           and TR.Comment not like '%DMC415%'
                                                                                           and TR.Comment not like '%DMC416%'
                                                                                           and TR.Comment not like '%DMC437%'
                                                                                           and TR.Comment not like '%DMC438%'
                                                                                           and TR.Comment not like 'RB331/EX%' then 'ET00RC'
                                                                                    else ''
                                                                                 end
                                   when iif(left(TR.SubAcc_Code, 2) = 'RB', 1, 0) + iif(left(TR.SubAcc_Code, 2) = 'SB', 1, 0) = 1
                                        and TR.SubAccOwner_BOCode <> 'RESEC' then ''
                              end
           from QORT_TDB_PROD..Trades as TR with (nolock, index(I_Trades_TradeDate_SubaccCode))
           inner join QORT_TDB_PROD..Phases as PH with(nolock) on TR.SystemID = PH.Trade_SID
                                                                  and PH.PC_Const in(8)	/*Payment of exchange commissions*/                                 
           inner join QORT_DB_PROD..Accounts as A with(nolock) on A.ExportCode = TR.PayAccount_ExportCode collate Cyrillic_General_CI_AS
           left join QORT_DDM..MarketMap MM with(nolock) on TR.TSSection_Name = MM.Name
          where TR.TradeDate = @intDate
          and @intDate > 20201030 
		  and @intDate < 20201101 /* переход на посделочную */
		        and 1 = /* EXO MIGRATION */
                    case
                        when left(TR.Comment, 6) = 'RB331/' then case
                                                                    when substring(TR.Comment, 7, 6) in ('DMC181','DMC310','DMC404','DMC416','DMC437','DMC438','DMC444','DMC445','DMC447') then 0
                                                                    when substring(TR.Comment, 7, 6) like 'EX%' then 0
                                                                    else 1
                                                                end
                         else 1
                    end
                and (iif(left(TR.SubAcc_Code, 2) = 'RB', 1, 0) + iif(left(TR.SubAcc_Code, 2) = 'SB', 1, 0) = 1
                     and TR.SubAccOwner_BOCode not in ('RESEC', 'FOGGI')
                     or TR.SubAccOwner_BOCode = 'RESEC'
                     and TR.Comment not like 'RB331//%'
                     and TR.Comment not like 'RB331/REF%'
                     /*					 and not (TR.TT_Const = 3 and TR.CpFirm_ShortName <> 'НКО НКЦ (АО)' and TR.Comment like 'RB331/cl%')*/
                     and not(TR.TT_Const = 3
                             and TR.Comment like 'RB331/%')
                     and tr.Comment not like '%colibri%'
                     and iif(TR.Comment like '%/D%', 1, 0) + iif(TR.Comment like '%/C%', 1, 0) + iif(TR.Comment like '%/EX%', 1, 0) > 0
                     and not exists (select 1
                                       from QORT_DB_PROD..SubaccStructure SubS with(nolock)
                                       join QORT_DB_PROD..Subaccs S with(nolock) on SubS.Child_ID = S.id
                                      where Father_ID = 4136 /*UMG873 A*/
                                            and SubS.Enabled = 0
                                            and S.SubAccCode = TR.SubAcc_Code collate Cyrillic_General_CS_AS) )
                     and not(TR.TechCenterComission = 0
                             and TR.ExchangeComission = 0
                             and TR.ClearingComission = 0)
                     and TR.TT_Const in (1, 2, 3, 7, 8, 12)				/*SPOT, REPO, SELT*/     
         union
         select ID = PH.SystemID
              , EntityID = isnull(nullif(TR.BrokerFirm_BOCode, ''), 'RENBR')
              , BookID = iif(left(TR.SubAcc_Code, 2) = 'DC', 'ETWARB', 'UAGNRB')/*WASH Book for ETG and non-ETG Clients!!!*/
              , CounterpartyID = 'NKCKB'
              , ClientID = TR.SubAccOwner_BOCode
              , SubAccCode = TR.SubAcc_Code
              , LoroID = case
                              when TR.SubAccOwner_BOCode = 'RENBR' then ''
                              when TR.SubAccOwner_BOCode = 'RESEC'
                                   and left(TR.SubAcc_Code, 2) <> 'DC' then 'UMG873'
                              when TR.SubAccOwner_BOCode = 'RESEC'
                                   and left(TR.SubAcc_Code, 2) = 'DC' then 'RBF331'
                            else TR.SubAcc_Code
                         end
              , NostroID = A.AccountCode
              , TraderID = 'NONE'
              , UserID = 'NONE'
              , TradeDate = PH.Date
              , Direction = -1
              , Currency = replace(PH.PhaseAsset_ShortName, 'RUR', 'RUB')
              , TechCenterCom = 0  /*No TechCenter Commission on FORTS*/              
              , ExchangeCom = iif(TR.FunctionType <> 777
                                  and isnull(PH.IsCanceled, 'n') = 'n', PH.QtyBefore, 0) /*'EXCH_TRADE_FEE' 'FORTS Exchange Commission'*/              
              , ClearingCom = iif(TR.FunctionType = 777
                                  and isnull(PH.IsCanceled, 'n') = 'n', PH.QtyBefore, 0) /*'EXCH_CLEAR_FEE' 'FORTS Clearing Commission'*/              
              , BackOfficeNotes = ''
              , ChargeType = ''
              , TransactingCapacity = iif(TR.SubAccOwner_BOCode = 'RENBR', 'Principal', 'Agency')
              , TSSection = ''
              , TCA = ''
              , ExchangeSector = MM.ExchangeSector collate Cyrillic_General_CS_AS
              , ExchangeID = MM.MarketPlace collate Cyrillic_General_CS_AS
              , ExchangeCode = MM.MarketPlace collate Cyrillic_General_CS_AS
              , MIC = MM.MIC collate Cyrillic_General_CS_AS
              , IsCanceled = isnull(PH.IsCanceled, 'n')
              , ExpenseBook = 'ETWARC'
           from QORT_TDB_PROD..Phases as PH with (nolock, index = I_Phases_Date)
           inner join QORT_TDB_PROD..Trades as TR with (nolock, index = PK_Trades) on TR.SystemID = PH.Trade_SID
                                                                                      and TR.TT_Const = 4 and TR.TradeTime>=185500000
                                                                                      and iif(left(TR.SubAcc_Code, 2) = 'DC', 1, 0) 
																					    + iif(TR.SubAcc_Code = 'SPBFUT00TSS', 1, 0) 
																						+ iif(TR.SubAcc_Code like 'RBF%'
                                                                                      and TR.SubAccOwner_BOCode <> 'RESEC', 1, 0) > 0
           inner join QORT_DB_PROD..Accounts as A with(nolock) on A.ExportCode = TR.PayAccount_ExportCode collate Cyrillic_General_CI_AS
           left join QORT_DDM..MarketMap MM with(nolock) on TR.TSSection_Name = MM.Name
          where 1 = 1
                and PH.PC_Const in (8)
                and TR.SubAcc_Code in ('RBF006','RBF041','RBF057','RBF068','RBF074','DCF454','DCF533','DCF502','DCF504','DCF520','DCF524','DCF525','DCF526','DC519A','DC519C','DCF519')
                and 1 = case when TR.TradeDate = PH.Date and @intDate < 20210202 then 1
                             when @intDate >= 20210201 then 1
                             else 0
                        end
                and PH.Date = @intDate
                and @intDate > 20210120
                and @intDate < 20210202/* переход на посделочную */)
				
     select ID = replace('QRTCC_' + SubAccCode + '_' + NostroID collate Cyrillic_General_CS_AS + '_' + BookID + '_' + ExpenseBook + '_' + ExchangeSector collate Cyrillic_General_CS_AS + '_' + right(TradeDate, 6) collate Cyrillic_General_CS_AS, ' ', '_')
          , EntityID
          , EntityCode = EntityID
          , BookID
          , BookCode = BookID
          , CounterpartyID = 'MICEX'
          , CounterpartyCode = 'MICEX'
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
          , Amount = sum(TechCenterCom)
          , BackOfficeNotes = 'MICEX TechCenter Commission'
          , ChargeType = 'EXCH_INFTECS_FEE'
          , TransactingCapacity
          , TSSection
          , TCA
          , ExchangeSector
          , ExchangeID
          , ExchangeCode
          , MIC
          , ExpenseBook
       from DDM_TradeFees
      where 1 = 1
            and LoroID = isnull(@LoroID, LoroID)
            and ClientID = isnull(@ClientID, ClientID)
            and ChargeType = isnull(@ChargeType, ChargeType)
      group by EntityID
             , BookID
             , CounterpartyID
             , ClientID
             , SubAccCode
             , LoroID
             , NostroID
             , TraderID
             , UserID
             , Direction
             , TradeDate
             , Currency
             , BackOfficeNotes
             , ChargeType
             , TransactingCapacity
             , TSSection
             , TCA
             , ExchangeSector
             , ExchangeID
             , ExchangeCode
             , MIC
             , ExpenseBook
      having sum(TechCenterCom) <> 0
     union all
     select ID = replace('QREXC_' + SubAccCode + '_' + NostroID collate Cyrillic_General_CS_AS + '_' + BookID + '_' + ExpenseBook + '_' + ExchangeSector collate Cyrillic_General_CS_AS + '_' + right(TradeDate, 6) collate Cyrillic_General_CS_AS, ' ', '_')
          , EntityID
          , EntityCode = EntityID
          , BookID
          , BookCode = BookID
          , CounterpartyID = iif(CounterpartyID = 'NKCKB', 'NKCKB', 'MICEX')
          , CounterpartyCode = iif(CounterpartyID = 'NKCKB', 'NKCKB', 'MICEX')
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
          , Amount = sum(ExchangeCom)
          , BackOfficeNotes = case
                                   when CounterpartyID = 'MICEX' then 'MICEX Exchange Commission'
                                   when CounterpartyID = 'NKCKB' then 'FORTS Exchange Commission'
                                 else 'Exchange Commission'
                              end
          , ChargeType = 'EXCH_TRADE_FEE'
          , TransactingCapacity
          , TSSection
          , TCA
          , ExchangeSector
          , ExchangeID
          , ExchangeCode
          , MIC
          , ExpenseBook
       from DDM_TradeFees
      where 1 = 1
            and LoroID = isnull(@LoroID, LoroID)
            and ClientID = isnull(@ClientID, ClientID)
            and ChargeType = isnull(@ChargeType, ChargeType)
      /*  AND ExchangeCom <> 0*/
      group by EntityID
             , BookID
             , CounterpartyID
             , ClientID
             , SubAccCode
             , LoroID
             , NostroID
             , TraderID
             , UserID
             , Direction
             , TradeDate
             , Currency
             , BackOfficeNotes
             , ChargeType
             , TransactingCapacity
             , TSSection
             , TCA
             , ExchangeSector
             , ExchangeID
             , ExchangeCode
             , MIC
             , ExpenseBook
      having sum(ExchangeCom) <> 0
     union all
     select ID = replace('QRCLC_' + SubAccCode + '_' + NostroID collate Cyrillic_General_CS_AS + '_' + BookID + '_' + ExpenseBook + '_' + ExchangeSector collate Cyrillic_General_CS_AS + '_' + right(TradeDate, 6) collate Cyrillic_General_CS_AS, ' ', '_')
          , EntityID
          , EntityCode = EntityID
          , BookID
          , BookCode = BookID
          , CounterpartyID = 'NKCKB'
          , CounterpartyCode = 'NKCKB'
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
          , Amount = sum(ClearingCom)
          , BackOfficeNotes = 'MICEX Clearing Commission'
          , ChargeType = 'EXCH_CLEAR_FEE'
          , TransactingCapacity
          , TSSection
          , TCA
          , ExchangeSector
          , ExchangeID
          , ExchangeCode
          , MIC
          , ExpenseBook
       from DDM_TradeFees
      where 1 = 1
            and LoroID = isnull(@LoroID, LoroID)
            and ClientID = isnull(@ClientID, ClientID)
            and ChargeType = isnull(@ChargeType, ChargeType)
      group by EntityID
             , BookID
             , CounterpartyID
             , ClientID
             , SubAccCode
             , LoroID
             , NostroID
             , TraderID
             , UserID
             , Direction
             , TradeDate
             , Currency
             , BackOfficeNotes
             , ChargeType
             , TransactingCapacity
             , TSSection
             , TCA
             , ExchangeSector
             , ExchangeID
             , ExchangeCode
             , MIC
             , ExpenseBook
      having sum(ClearingCom) <> 0
