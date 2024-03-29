CREATE procedure [dbo].[DDM_ImportedTradesSettlementProcess] @SettlementDetailID bigint
                                                      , @Action             nvarchar(7) /* New and Cancel only*/
                                                      , @msg                nvarchar(4000) output
as
    begin
        set nocount on
        declare @RuleID            bigint
              , @BackID            varchar(100)
              , @Infosource        varchar(100)
              , @ExternalID2       varchar(255)
              , @ExternalReference varchar(255)
              , @TradeEvent        varchar(50)
              , @Direction         smallint
              , @SettlementDate    datetime
              , @AvaliableDate     datetime
              , @PC_Const          int
              , @CT_Const          int
              , @Trade_SID         numeric(18, 0)
              , @TradeNum          varchar(255)
              , @SubAccCode        varchar(255)
              , @AccountCode       varchar(255)
              , @StlExternalID     varchar(255)
              , @ReversedID        bigint
              , @Issue             varchar(25)
              , @Asset_ShortName   varchar(25)
              , @Qty               decimal(38, 14)
              , @Amount            decimal(38, 14)
              , @Currency          varchar(3)
              , @PayCurrency       varchar(3)
              , @MovType           varchar(8)
              , @CommissionName    varchar(255)
              , @GetLoroAccount    varchar(6)
              , @GetNostroAccount  varchar(50)
              , @LegalEntity       varchar(6)
              , @GetLegalEntity    varchar(6)
              , @TransferStatus    varchar(100)    = 'VERIFIED' /* need to call DDM_Add_TransfersToCache */
              , @TransferType      varchar(50)     = 'PRINCIPAL' /* need to call DDM_Add_TransfersToCache */
              , @ChargeType        varchar(50)     = null
              , @NetSettlementID   varchar(32)     = null
              , @Extra_Msg         varchar(4000)
        select @RuleID = dr.RuleID
             , @ReversedID = dr.ReversedID
             , @StlExternalID = dr.StlExternalID
             , @ExternalReference = dr.ExternalReference
             , @TradeNum = dr.TradeNum
             , @MovType = dr.MovType
             , @Issue = dr.Issue
             , @Asset_ShortName = dr.Asset_ShortName
             , @Qty = dr.Qty
             , @Amount = dr.Amount
             , @Direction = dr.Direction
             , @Currency = dr.Currency
             , @SubAccCode = dr.SubAccCode
             , @AccountCode = dr.AccountCode
             , @LegalEntity = isnull(dr.LegalEntity, 'RENBR')
             , @AvaliableDate = dr.AvaliableDate
             , @GetLegalEntity = dr.GetLegalEntity
             , @TradeEvent = dr.TradeEvent
             , @PC_Const = dr.PC_Const
             , @CT_Const = dr.CT_Const
             , @SettlementDate = dr.SettlementDate
             , @CommissionName = dr.CommissionName
             , @TransferStatus = dr.TransferStatus
             , @TransferType = dr.TransferType
             , @ExternalID2 = dr.ExternalID2
             , @GetLoroAccount = dr.GetLoroAccount
             , @GetNostroAccount = dr.GetNostroAccount
             , @Infosource = 'BackOffice'
             , @Trade_SID = dr.Trade_SID
             , @PayCurrency = dr.PayCurrency
             , @ChargeType = dr.ChargeType
             , @NetSettlementID = dr.NetSettlementID
             , @Msg = dr.Msg
          from QORT_DDM.dbo.DDM_GetImportTrade_Rule( @SettlementDetailID ) dr
        if @Action <> 'Cancel'
           and isnull(@Msg, '') <> '' /* escape in any errors in DDM_GetImportTrade_Rule */
            begin
                return
        end
        select @msg = '500. DDM_ImportedTradesSettlementProcess need to investigate'
        if @TradeEvent = 'AddCorrectPosition' /* CorrectPosition Process doesn't need trade SID*/
            begin
                if @Action = 'Cancel'
                    begin
                        set @BackID = concat(@TradeNum, '/', @StlExternalID)
                        exec QORT_DDM..DDM_MovementCancel @MovementID = @StlExternalID
                                                        , @msg = @msg out
                                                        , @BackID = @BackID
                        if @ReversedID > 0 /* Cancel should be processed for the Reversed CorrectPosition*/
                            begin
                                set @BackID = concat(@TradeNum, '/', @ReversedID)
                                exec QORT_DDM..DDM_MovementCancel @MovementID = @StlExternalID
                                                                , @msg = @msg out
                                                                , @BackID = @BackID
                        end
                        return
                end
                     else
                    begin
                        exec QORT_DDM..DDM_InsertCorrectPosition @RuleID = @RuleID
                                                               , @MovementID = null
                                                               , @MovementID2 = null
                                                               , @SettlementDetailID = @SettlementDetailID
                                                               , @msg = @msg out
                                                               , @TradeSettlementDetailID = 1
                end
                return
        end
        if @Action = 'Cancel'
            begin
                if @TradeEvent in('AddCommission', 'AddCommissionBlock')
                   and @MovType = 'CASH'
                    begin
                        exec QORT_DDM.dbo.DDM_InsertTradeBlock @ExternalID = @StlExternalID
                                                             , @Trade_SID = @Trade_SID
                                                             , @PC_Const = @PC_Const /* 9 = PC_COM_BROKER */
                                                             , @AccrualDate = @AvaliableDate
                                                             , @CommissionName = @CommissionName
                                                             , @LoroAccount = @SubAccCode
                                                             , @NostroAccount = @AccountCode
                                                             , @GetLoroAccount = @GetLoroAccount
                                                             , @GetNostroAccount = @GetNostroAccount
                                                             , @Issue = @Currency
                                                             , @Amount = 0 /* cancel whole BlockComission if exists */
                                                             , @Direction = @Direction
                                                             , @Action = @Action
                                                             , @msg = @msg output
                        set @Extra_Msg = @msg
                end
                set @msg = ''
                exec QORT_DDM.dbo.DDM_PhaseCancel @ExternalID = @StlExternalID
                                                , @Trade_SID = @Trade_SID
                                                , @msg = @msg out
                set @Extra_Msg = concat(@Extra_Msg, '; ', @msg)
                set @msg = ''
                if isnull(@ReversedID, 0) > 0
                    begin
                        exec QORT_DDM.dbo.DDM_PhaseCancel @ExternalID = @ReversedID
                                                        , @Trade_SID = @Trade_SID
                                                        , @msg = @msg out
                end
                set @msg = concat(@Extra_Msg, '; ', @msg)
                return
        end
        if @TradeEvent in('AddCommission', 'AddCommissionBlock')
           and @MovType = 'CASH'
            begin
                if @TradeEvent = 'AddCommissionBlock'
                    exec QORT_DDM.dbo.DDM_InsertTradeBlock @ExternalID = @StlExternalID
                                                         , @Trade_SID = @Trade_SID
                                                         , @PC_Const = @PC_Const
                                                         , @AccrualDate = @AvaliableDate
                                                         , @CommissionName = @CommissionName
                                                         , @LoroAccount = @SubAccCode
                                                         , @NostroAccount = @AccountCode
                                                         , @GetLoroAccount = @GetLoroAccount
                                                         , @GetNostroAccount = @GetNostroAccount
                                                         , @Issue = @Currency
                                                         , @Amount = @Amount
                                                         , @Direction = @Direction
                                                         , @Action = @Action
                                                         , @msg = @msg output
                if @TradeEvent = 'AddCommission'
                    exec QORT_DDM.dbo.DDM_TradeAddCommission @ExternalID = @StlExternalID
                                                           , @Trade_SID = @Trade_SID
                                                           , @PC_Const = @PC_Const
                                                           , @SettlementDate = @SettlementDate
                                                           , @AvaliableDate = @AvaliableDate
                                                           , @Amount = @Amount
                                                           , @Action = @Action
                                                           , @Currency = @Currency
                                                           , @Direction = @Direction
                                                           , @LoroAccount = @SubAccCode
                                                           , @NostroAccount = @AccountCode
                                                           , @GetLoroAccount = @GetLoroAccount
                                                           , @GetNostroAccount = @GetNostroAccount
                                                           , @LegalEntity = @LegalEntity
                                                           , @GetLegalEntity = @GetLegalEntity
                                                           , @Infosource = @Infosource
                                                           , @CommissionName = @CommissionName
                                                           , @ChargeType = @ChargeType
                                                           , @msg = @msg output
                return
        end
        if @TradeEvent = 'AddInterest'
           and @MovType = 'CASH'
           and isnull(year(@SettlementDate), 0) <> 0
            begin
                exec QORT_DDM..DDM_TradeAddInterest @ExternalID = @StlExternalID
                                                  , @Trade_SID = @Trade_SID
                                                  , @PC_Const = @PC_Const
                                                  , @SettlementDate = @SettlementDate
                                                  , @Amount = @Amount
                                                  , @Currency = @Currency
                                                  , @Direction = @Direction
                                                  , @LoroAccount = @SubAccCode
                                                  , @NostroAccount = @AccountCode
                                                  , @LegalEntity = @LegalEntity
                                                  , @GetLegalEntity = @GetLegalEntity
                                                  , @Infosource = @Infosource
                                                  , @msg = @msg output
                return
        end
        if @TradeEvent in('CashSettlement', 'UpdateTradeAccount')
           and @MovType = 'CASH'
            begin
                exec QORT_DDM..DDM_DefineTradeLeg @Trade_SID = @Trade_SID
                                                , @Asset = @Currency /* AssetShortName from QORT*/
                                                , @Direction = @Direction /* Settlement direction*/
                                                , @ChargeType = @ChargeType /* Charge Type */
                                                , @TradeLeg_SID = @Trade_SID output
                                                , @msg = @msg output
                if isnull(@AccountCode, '') <> ''
                    begin
                        if @Currency = @PayCurrency
                            begin
                                exec QORT_DDM.dbo.DDM_Add_TransfersToCache @transferid = @StlExternalID
                                                                         , @tradeid = @TradeNum
                                                                         , @status = @TransferStatus
                                                                         , @transfer_type = @TransferType
                                                                         , @pay_account = @AccountCode
                                                                         , @Trade_SID = @Trade_SID
                                exec QORT_DDM.dbo.DDM_UpdateTradeAccounts @Trade_SID = @Trade_SID
                                                                        , @ExternalReference = @ExternalReference
                                                                        , @ExternalTradeID = @TradeNum
                                                                        , @PayAccount = @AccountCode
                                                                        , @Currency = @Currency
                                                                        , @msg = @msg output
                        end
                             else
                            begin
                                exec QORT_DDM.dbo.DDM_Add_TransfersToCache @transferid = @StlExternalID
                                                                         , @tradeid = @TradeNum
                                                                         , @status = @TransferStatus
                                                                         , @transfer_type = @TransferType
                                                                         , @put_account = @AccountCode
                                                                         , @Trade_SID = @Trade_SID
                                exec QORT_DDM.dbo.DDM_UpdateTradeAccounts @Trade_SID = @Trade_SID
                                                                        , @ExternalReference = @ExternalReference
                                                                        , @ExternalTradeID = @TradeNum
                                                                        , @PutAccount = @AccountCode
                                                                        , @msg = @msg output
                        end
                        if isnull(year(@SettlementDate), 0) = 0
                           and @TradeEvent = 'CashSettlement'
                            begin
                                exec QORT_DDM..DDM_PhaseCancel @ExternalID = @StlExternalID
                                                             , @Trade_SID = @Trade_SID
                                                             , @msg = @msg output
                        end
                        if isnull(year(@SettlementDate), 0) <> 0
                           and @TradeEvent = 'CashSettlement'
                            begin
                                exec QORT_DDM..DDM_TradeAddSettlement @SettlementDetailID = @SettlementDetailID
                                                                    , @TradeSource = 'IMPORT'
                                                                    , @ExternalID = @StlExternalID
                                                                    , @Trade_SID = @Trade_SID
                                                                    , @MovType = @MovType
                                                                    , @SettlementDate = @SettlementDate
                                                                    , @Amount = @Amount
                                                                    , @Asset = @Currency
                                                                    , @Direction = @Direction
                                                                    , @LoroAccount = @SubAccCode
                                                                    , @NostroAccount = @AccountCode
                                                                    , @LegalEntity = @LegalEntity
                                                                    , @ChargeType = @ChargeType
                                                                    , @Infosource = @Infosource
                                                                    , @NetSettlementID = @NetSettlementID
                                                                    , @CommissionName = @CommissionName
                                                                    , @msg = @msg output
                        end
                end
                     else
                    select @msg = '003. Nostro Account should be defined'
                return
        end
        if @TradeEvent in('SecuritySettlement', 'UpdateTradeAccount')
           and @MovType = 'SECURITY'
            begin
                exec QORT_DDM..DDM_DefineTradeLeg @Trade_SID = @Trade_SID
                                                , @Asset = @Issue /* Currency or GRDB ID*/
                                                , @Direction = @Direction /* Settlement direction*/
                                                , @ChargeType = @ChargeType /* Charge Type */
                                                , @TradeLeg_SID = @Trade_SID output
                                                , @msg = @msg output
                if isnull(@AccountCode, '') <> ''
                    begin
                        exec QORT_DDM.dbo.DDM_Add_TransfersToCache @transferid = @StlExternalID
                                                                 , @tradeid = @TradeNum
                                                                 , @status = @TransferStatus
                                                                 , @transfer_type = 'SECURITY' /* need to more details - ask QORT BA */
                                                                 , @put_account = @AccountCode
                                                                 , @Trade_SID = @Trade_SID
                        exec QORT_DDM.dbo.DDM_UpdateTradeAccounts @Trade_SID = @Trade_SID
                                                                , @ExternalReference = @ExternalReference
                                                                , @ExternalTradeID = @TradeNum
                                                                , @PutAccount = @AccountCode
                                                                , @msg = @msg output
                        if isnull(year(@SettlementDate), 0) = 0
                           and @TradeEvent = 'SecuritySettlement'
                            begin
                                exec QORT_DDM..DDM_PhaseCancel @ExternalID = @StlExternalID
                                                             , @Trade_SID = @Trade_SID
                                                             , @msg = @msg output
                        end
                        if isnull(year(@SettlementDate), 0) <> 0
                           and @TradeEvent = 'SecuritySettlement'
                            begin
                                exec QORT_DDM..DDM_TradeAddSettlement @SettlementDetailID = @SettlementDetailID
                                                                    , @TradeSource = 'IMPORT'
                                                                    , @ExternalID = @StlExternalID
                                                                    , @Trade_SID = @Trade_SID
                                                                    , @MovType = @MovType
                                                                    , @SettlementDate = @SettlementDate
                                                                    , @Amount = @Qty
                                                                    , @Asset = @Asset_ShortName
                                                                    , @Direction = @Direction
                                                                    , @LoroAccount = @SubAccCode
                                                                    , @NostroAccount = @AccountCode
                                                                    , @LegalEntity = @LegalEntity
                                                                    , @ChargeType = 'SECURITY'
                                                                    , @Infosource = @Infosource
                                                                    , @NetSettlementID = @NetSettlementID
                                                                    , @CommissionName = @CommissionName
                                                                    , @msg = @msg output
                        end
                end
                     else
                    select @msg = '003. Nostro Account should be defined'
                return
        end
        return
    end
