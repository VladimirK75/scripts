create   procedure dbo.DDM_TradeAddInterest 
                          @ExternalID     varchar(255)
                        , @Trade_SID      numeric(18, 0)
                        , @PC_Const       int
                        , @SettlementDate datetime
                        , @Amount         decimal(38, 14)
                        , @Currency       varchar(3)
                        , @Direction      smallint
                        , @LoroAccount    varchar(6)
                        , @NostroAccount  varchar(50)
                        , @LegalEntity    varchar(6)
                        , @GetLegalEntity varchar(6)
                        , @Infosource     varchar(64)
                        , @msg            nvarchar(4000) output
as
    begin
        declare 
               @BackID           varchar(64)
             , @GetLoroAccount   varchar(6)
             , @GetNostroAccount varchar(50)
             , @CommissionID     bigint
             , @AccruedAmount    decimal(38, 14)
             , @AccruedCurrency  varchar(3)
        select @msg = '000. Ok'
        select @Trade_SID = RepoTrade_SystemID
          from QORT_TDB_PROD..Trades with (nolock)
          where SystemID = @Trade_SID
                and TT_Const in (3, 6, 12, 13, 14)
        select @BackID = @ExternalID+'/'+cast(@PC_Const as varchar(3))
        exec QORT_DDM..DDM_InsertTradePhases @PC_Const = @PC_Const
                                           , @Trade_SID = @Trade_SID
                                           , @BackID = @BackID
                                           , @Infosource = @Infosource
                                           , @SettlementDate = @SettlementDate
                                           , @LegalEntity = @LegalEntity
                                           , @GetLegalEntity = @GetLegalEntity
                                           , @LoroAccount = @LoroAccount
                                           , @NostroAccount = @NostroAccount
                                           , @Issue = @Currency
                                           , @Amount = @Amount
                                           , @Direction = @Direction
                                           , @msg = @msg output
        return
    end
