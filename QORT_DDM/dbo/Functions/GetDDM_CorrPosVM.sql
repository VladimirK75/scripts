create    function dbo.GetDDM_CorrPosVM(  
               @intDate   int  
             , @LoroID    varchar(6)  = null  
             , @ClientID  varchar(5)  = null  
             , @NostroID  varchar(50) = null  
             , @IssueCode varchar(50) = null)  
returns table  
as  
return  
with DDM_CorrPosVM(ID  
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
                 , Currency  
                 , Amount  
                 , Direction  
                 , BackOfficeNotes  
                 , ChargeType  
                 , TransactingCapacity  
                 , IssueID  
                 , IssueCode  
                 , ExchangeSector  
                 , ExchangeID  
                 , ExchangeCode  
                 , MIC  
                 , IsCanceled)  
     as (select ID = CP.SystemID  
              , EntityID = 'RENBR'  
              , BookID = 'NONE'  
              , CounterpartyID = 'NKCKB'  
              , ClientID = CP.SubaccOwnerFirm_BOCode  
              , SubAccCode = CP.Subacc_Code  
              , LoroID = case  
                              when CP.Subacc_Code like 'DC%' then 'RBF331'  
                              when CP.SubaccOwnerFirm_BOCode = 'RENBR' then ''  
                              when CP.Subacc_Code in('RESEC', 'RESECEQ', 'RESECFI', 'SPBFUT00RDP', 'SPBFUT00RES', 'SPBFUT00EPG', 'SPBFUT00RUS', 'SPBFUT77RES', 'SPBFUT00RST', 'SPBFUT00RSTSGK', 'SPBFUT00TSS', 'SPBFUTZZ000','SPBFUT05RDP', 'SPBFUT77EPG') then 'UMG873'  
                            else CP.Subacc_Code  
                         end  
              , NostroID = CP.Account_ExportCode /* NOSTRO account*/  
              , TraderID = 'NONE'  
              , UserID = 'SrvPositioner'  
              , TradeDate = CP.Date  
              , Currency = replace(CP.Asset_ShortName, 'RUR', 'RUB')  
              , Amount = abs(CP.Size)  
              , Direction = iif(CP.Size > 0, 1, -1)  
              , BackOfficeNotes = 'FORTS Variation margin'  
              , ChargeType = 'VARIATION_MARGIN'  
              , TransactingCapacity = iif(CP.SubaccOwnerFirm_BOCode = 'RENBR', 'Principal', 'Agency')  
              , IssueID = ISSUE.GrdbID  
              , IssueCode = CP.SideAsset_ShortName  
              , ExchangeSector = 'FORTS'  
              , ExchangeID = 'TSRTS'  
              , ExchangeCode = 'TSRTS'  
              , MIC = 'RTSX'  
              , IsCanceled = isnull(CP.IsCanceled, 'n')  
           from QORT_TDB_PROD..ExportCorrectPositions as CP with(nolock)  
           left join GRDBServices.Publication.GrdbMap ISSUE with(nolock) on ISSUE.AssetShortName = CP.SideAsset_ShortName  
                                                                            and ISSUE.Enabled = 0  
          where CP.Date = QORT_DDM.dbo.DDM_fn_AddBusinessDay (QORT_DDM.dbo.DDM_fn_AddBusinessDay (@intDate,1,'Календарь_2010'),-1,'Календарь_2010')  
                and CP.CT_Const in (51, 52) )  
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
          , NostroID = QORT_DDM.dbo.GetDDM_NostroMapping (NostroID, 'Единый пул', 0)  
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
          , IssueID  
          , IssueCode  
          , ExchangeSector  
          , ExchangeID  
    , ExchangeCode  
          , MIC  
          , IsCanceled  
       from DDM_CorrPosVM  
      where 1 = 1  
            and LoroID = isnull(@LoroID, LoroID)  
            and ClientID = isnull(@ClientID, ClientID)  
            and NostroID = isnull(@NostroID, NostroID)  
            and IssueCode = isnull(@IssueCode, IssueCode)
