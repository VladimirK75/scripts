CREATE procedure dbo.DDM_TradeAddCommission 
                 @ExternalID       varchar(255)
               , @Trade_SID        numeric(18, 0)
               , @PC_Const         int
               , @SettlementDate   datetime        = null
               , @AvaliableDate    datetime        = null
               , @Amount           decimal(38, 14)
               , @Action           nvarchar(7)            /* New and Cancel only*/
               , @Currency         varchar(3)
               , @Direction        smallint
               , @LoroAccount      varchar(6)      = null
               , @NostroAccount    varchar(50)     = null
               , @GetLoroAccount   varchar(6)      = null
               , @GetNostroAccount varchar(50)     = null
               , @LegalEntity      varchar(6)
               , @GetLegalEntity   varchar(6)
               , @Infosource       varchar(64)
               , @CommissionName   varchar(255)    = null
               , @ChargeType       varchar(50)     = null
               , @msg              nvarchar(4000) output
as
    begin
        declare 
               @BackID          varchar(64)
             , @CommissionID    bigint
             , @AccrualID       bigint
             , @AccruedAmount   decimal(38, 14)
             , @AccruedCurrency varchar(3)
             , @TradeLoro       varchar(6)
             , @TradeNostro     varchar(50)
        select @msg = '000. Ok'
        if nullif(@Trade_SID, 0) is null
            begin
                select @msg = '400. Bad Request. Field Trade_SystemID=@Trade_SID must be specified but set as EMPTY'
                return
            end
        select @CommissionID = id
          from QORT_DB_PROD..Commissions with(nolock)
         where Name like @CommissionName
        if isnull(@CommissionID, 0) = 0
            begin
                select @msg = '400. Bad Request. Commission ID not found for @CommissionName = '+@CommissionName
                return
            end
        select @Currency = replace(@Currency, 'RUB', 'RUR')
             , @BackID = @ExternalID+'/'+isnull(ltrim(str(@PC_Const)), '')
        exec QORT_DDM..DDM_InsertTradeBlock @ExternalID = @ExternalID
                                          , @Trade_SID = @Trade_SID
                                          , @PC_Const = @PC_Const
                                          , @AccrualDate = @AvaliableDate
                                          , @CommissionName = @CommissionName
                                          , @LoroAccount = @LoroAccount
                                          , @NostroAccount = @NostroAccount
                                          , @GetLoroAccount = @GetLoroAccount
                                          , @GetNostroAccount = @GetNostroAccount
                                          , @Issue = @Currency
                                          , @Amount = @Amount
                                          , @Direction = @Direction
                                          , @Action = @Action
                                          , @msg = @msg output
        if isnull(year(@SettlementDate), 0) <> 0
            begin
                select @BackID = concat(@ExternalID,'/',@PC_Const)
                     --, @Amount = -1 * @Direction * @Amount
                exec QORT_DDM..DDM_InsertTradePhases @PC_Const = @PC_Const
                                                   , @Trade_SID = @Trade_SID
                                                   , @BackID = @BackID
                                                   , @Infosource = @Infosource
                                                   , @SettlementDate = @SettlementDate
                                                   , @LegalEntity = @LegalEntity
                                                   , @GetLegalEntity = @GetLegalEntity
                                                   , @LoroAccount = @LoroAccount
                                                   , @NostroAccount = @NostroAccount
                                                   , @GetLoroAccount = @GetLoroAccount
                                                   , @GetNostroAccount = @GetNostroAccount
                                                   , @Issue = @Currency
                                                   , @Amount = @Amount
                                                   , @Direction = @Direction
                                                   , @CommissionID = @CommissionID
                                                   , @ChargeType = @ChargeType
                                                   , @msg = @msg output
            end
        return
    end
---------------------------------------------
