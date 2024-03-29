CREATE   procedure [dbo].[DDM_ExportedTradesSettlementProcess] 
                          @SettlementDetailID bigint
                        , @Action             nvarchar(7) /* New and Cancel only*/
                        , @msg                nvarchar(4000) output
as
    begin
        declare 
               @BackID            varchar(100)
             , @Infosource        varchar(100)
             , @SettlementID      bigint
             , @STLRuleID         bigint
             , @ExternalID        varchar(255)
             , @ExternalReference varchar(255)
             , @OperationType     varchar(50)
             , @TradeEvent        varchar(50)
             , @Capacity          varchar(6)
             , @Direction         smallint
             , @SettlementDate    datetime
             , @SettlementDateInt int
             , @CPDateInt         int
             , @CPRegDateInt      int
             , @PC_Const          int
             , @Trade_SID         numeric(18, 0)
             , @AgreeNum          varchar(255)
             , @TradeNum          varchar(255)
             , @SubAccCode        varchar(255)
             , @AccountCode       varchar(255)
             , @Asset             varchar(255)
             , @StlExternalID     varchar(255)
             , @ReversedID        bigint
             , @RuleID            bigint
             , @StlType           varchar(6)
             , @StlDateType       varchar(50)
             , @CharPos           int
             , @Issue             varchar(25)
             , @Qty               decimal(38, 14)
             , @Price             decimal(38, 14)
             , @AccruedCoupon     decimal(38, 14)
             , @ChargeType        varchar(50)
             , @Amount            decimal(38, 14)
             , @AccruedAmount     decimal(38, 14)
             , @Currency          varchar(3)
             , @AccruedCurrency   varchar(3)
             , @MovType           varchar(8)
             , @SystemID          bigint
             , @AccrualID         bigint
             , @CommissionID      bigint
             , @Asset_ShortName   varchar(48)
             , @Size              decimal(38, 14)
             , @GetLoroAccount    varchar(6)
             , @GetNostroAccount  varchar(50)
             , @LegalEntity       varchar(6)
             , @GetLegalEntity    varchar(6)
             , @TransferStatus    varchar(100)    = 'VERIFIED' /* need to call DDM_Add_TransfersToCache */
             , @TransferType      varchar(50)     = 'PRINCIPAL' /* need to call DDM_Add_TransfersToCache */
        select @msg = '000. Ok'
        select @SettlementID = sd.SettlementID
             , @OperationType = s.OperationType
             , @StlType = sd.Type
             , @ReversedID = isnull(s.ReversedID, 0)
             , @StlExternalID = s.ExternalID
             , @ExternalReference = s.TradeGID
             , @Capacity = sd.Type
             , @ChargeType = sd.ChargeType
             , @MovType = sd.MovType
             , @Issue = sd.Issue
             , @Qty = isnull(sd.Qty, 0)
             , @Price = isnull(sd.Price, 0)
             , @AccruedCoupon = isnull(sd.AccruedCoupon, 0)
             , @Amount = isnull(sd.Amount, 0)
             , @Direction = sd.Direction
             , @Currency = sd.Currency
             , @SubAccCode = sd.LoroAccount
             , @AccountCode = sd.NostroAccount
             , @LegalEntity = s.LegalEntity
             , @GetLegalEntity = sd.Counterparty
          from QORT_DDM..ExportedTradeSettlementDetails sd with(nolock)
          inner join QORT_DDM..ExportedTradeSettlement s with(nolock) on sd.SettlementID = s.ID
          where sd.ID = @SettlementDetailID
        select top 1 @RuleID = sr.RuleID
                   , @TradeEvent = sr.TradeEvent
                   , @PC_Const = sr.PC_Const
                   , @STLRuleID = sr.STLRuleID
                   , @StlDateType = SettlementDate
          from QORT_DDM..Trades_SettlementRules sr
             , QORT_DDM..SettlementRules r
          where isnull(sr.TradeType, @OperationType) = @OperationType
                and isnull(sr.ChargeType, @ChargeType) = @ChargeType
                and sr.STLRuleID = r.STLRuleID
                and r.Capacity = @Capacity
        order by Priority
        if isnull(@TradeEvent, '') = ''
            begin
                select @msg = '001. Settlement Rule not found '
                return
            end
        exec QORT_DDM..DDM_TradeGet_SID @SettlementDetailID = @SettlementDetailID
                                      , @TradeSource = 'QORT'
                                      , @Infosource = @Infosource out
                                      , @Trade_SID = @Trade_SID out
                                      , @msg = @msg out
        if left(@msg, 3) <> '000'
            return
        if @Action = 'Cancel'
            begin
                exec QORT_DDM..DDM_PhaseCancel @ExternalID = @StlExternalID
                                             , @Trade_SID = @Trade_SID
                                             , @msg = @msg out
                return
            end
        if @ReversedID > 0 /* Cancel should be processed for the Reversed Phase*/
            begin
                exec QORT_DDM..DDM_PhaseCancel @ExternalID = @ReversedID
                                             , @Trade_SID = @Trade_SID
                                             , @msg = @msg out
                return
            end
        /* Определяем дату расчетов, согласно правилам */
        select @SettlementDate = case @StlDateType
                                      when 'FOAvaliableDate' then st.FOAvaliableDate
                                      when 'ActualSettlementDate' then st.ActualSettlementDate
                                      when 'AvaliableDate' then st.AvaliableDate
                                 end
             , @TransferStatus = case
                                      when @Action = 'Cancel' then 'CANCELED'
                                      when st.ActualSettlementDate is not null then 'SETTLED'
                                      else 'VERIFIED'
                                 end
             , @TransferType = case
                                    when @ChargeType in('FACILITATION', 'AGENCY') then @ChargeType
                                    else 'PRINCIPAL'
                               end
          from QORT_DDM..ExportedTradeSettlement st with(nolock)
          where ID = @SettlementID
        if @TradeEvent = 'AddCommission'
           and @MovType = 'CASH'
           and isnull(year(@SettlementDate), 0) <> 0
           and isnull(@SubAccCode, '') <> ''
            begin
                if isnull(@PC_Const, 0) = 0
                    begin
                        select @msg = '002. PC_Const for AddCommission not found Trade_SID = '+convert(varchar(20), @Trade_SID)+'; ExternalReference = '+@ExternalReference
                        return
                    end
                exec QORT_DDM..DDM_TradeAddCommission @ExternalID = @StlExternalID
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
        if @TradeEvent = 'AddInterest'
           and @MovType = 'CASH'
            begin
                if isnull(@PC_Const, 0) = 0
                    begin
                        select @msg = '002. PC_Const for AddInterest should be defined. Trade_SID = '+convert(varchar(20), @Trade_SID)+'; ExternalReference = '+@ExternalReference
                        return
                    end
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
        if @TradeEvent = 'CashSettlement'
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
                        exec QORT_DDM..DDM_Add_TransfersToCache @transferid = @StlExternalID
                                                              , @tradeid = @TradeNum
                                                              , @status = @TransferStatus
                                                              , @transfer_type = @TransferType
                                                              , @pay_account = @AccountCode
                        exec QORT_DDM..DDM_UpdateTradeAccounts @Trade_SID = @Trade_SID
                                                             , @ExternalReference = @ExternalReference
                                                             , @ExternalTradeID = @TradeNum
                                                             , @PayAccount = @AccountCode
                                                             , @Currency = @Currency
                                                             , @msg = @msg output
                        if isnull(year(@SettlementDate), 0) <> 0
                            begin
                                exec QORT_DDM..DDM_TradeSettlement @ExternalID = @StlExternalID
                                                                 , @Trade_SID = @Trade_SID
                                                                 , @MovType = @MovType
                                                                 , @SettlementDate = @SettlementDate
                                                                 , @Amount = @Amount
                                                                 , @Asset = @Currency
                                                                 , @Direction = @Direction
                                                                 , @LoroAccount = @SubAccCode
                                                                 , @NostroAccount = @AccountCode
                                                                 , @LegalEntity = @LegalEntity
                                                                 , @GetLegalEntity = @GetLegalEntity
                                                                 , @Infosource = @Infosource
                                                                 , @msg = @msg output
                            end
                    end
                     else
                select @msg = '003. Nostro Account should be defined'
                return
            end
        if @TradeEvent = 'SecuritySettlement'
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
                        exec QORT_DDM..DDM_Add_TransfersToCache @transferid = @StlExternalID
                                                              , @tradeid = @TradeNum
                                                              , @status = @TransferStatus
                                                              , @transfer_type = 'SECURITY' /* need to more details - ask QORT BA */ 
                                                              , @put_account = @AccountCode
                        exec QORT_DDM..DDM_UpdateTradeAccounts @Trade_SID = @Trade_SID
                                                             , @ExternalReference = @ExternalReference
                                                             , @ExternalTradeID = @TradeNum
                                                             , @PutAccount = @AccountCode
                                                             , @msg = @msg output
                        if isnull(year(@SettlementDate), 0) <> 0
                            begin
                                exec QORT_DDM..DDM_TradeSettlement @ExternalID = @StlExternalID
                                                                 , @Trade_SID = @Trade_SID
                                                                 , @MovType = @MovType
                                                                 , @SettlementDate = @SettlementDate
                                                                 , @Amount = @Amount
                                                                 , @Asset = @Issue
                                                                 , @Direction = @Direction
                                                                 , @LoroAccount = @SubAccCode
                                                                 , @NostroAccount = @AccountCode
                                                                 , @LegalEntity = @LegalEntity
                                                                 , @GetLegalEntity = @GetLegalEntity
                                                                 , @Infosource = @Infosource
                                                                 , @msg = @msg output
                            end
                    end
                     else
                select @msg = '003. Nostro Account should be defined'
                return
            end
        return
    end
