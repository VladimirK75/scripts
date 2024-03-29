create procedure dbo.DDM_MovementProcess 
                 @MovementID bigint
               , @Action     nvarchar(7) /* New and Cancel only*/
               , @msg        nvarchar(4000) output
as
    begin
        declare 
               @Rez int
        select @msg = '000. Ok'
        declare 
               @BackID            varchar(100)
             , @IsSynchronized    bit
             , @IsDual            bit
             , @NeedClientInstr   bit
             , @SettledOnly       bit
             , @STLRuleID         bigint
             , @StartDate         datetime
             , @EndDate           datetime
             , @QRTObject         varchar(50)
             , @QRTObjType        tinyint
             , @TransactionID     bigint
             , @ExternalID        varchar(255)
             , @Version           tinyint
             , @TxnGID            varchar(100)
             , @SourceSystem      varchar(25)
             , @OperationType     varchar(50)
             , @InternalReference varchar(50)
             , @ExternalReference varchar(50)
             , @Book              varchar(6)
             , @LegalEntity       varchar(5)
             , @TranCounterparty  varchar(5)
             , @InstrLoroAccount  varchar(6)
             , @TradeDate         datetime
             , @Trader            varchar(50)
             , @User              varchar(50)
             , @PSET              varchar(50)
             , @BackOfficeNotes   varchar(255)
             , @DealingCapacity   varchar(20)
             , @TaxConfig         float
             , @IssueReference    varchar(50)
             , @TradeReference    varchar(50)
             , @MovType           varchar(8)
             , @MovCounterparty   varchar(6)
             , @LoroAccount       varchar(6)
             , @NostroAccount     varchar(50)
             , @GetLoroAccount    varchar(6)
             , @GetNostroAccount  varchar(50)
             , @Direction         smallint
             , @SettlementDate    datetime
             , @Issue             varchar(25)
             , @Qty               decimal
             , @Price             decimal
             , @AccruedCoupon     decimal
             , @ChargeType        varchar(50)
             , @Amount            decimal
             , @Currency          varchar(3)
             , @MovementID2       bigint
             , @SystemID          bigint
             , @Asset_ShortName   varchar(48)
             , @Size              decimal
        /* BackID всегда начинается с ExternalID транзакции и MovementID, породившими корректировку. Для каждого Settlement, который лишь частично закрывает объем всей корректировки к BackID добавляется ID SettlementDetail. Если корректировка исполнилась одним Settlement объектом сразу на всю сумму, ссылка на Settlement у нее будет только в комментарии и Infosource */
        select @BackID = 'CL'+@ExternalID+'/'+convert(varchar(20), cast(@MovementID as numeric(18, 0)))
          from QORT_DDM..Movements mv with(nolock)
          inner join QORT_DDM..CommonTransaction ct on mv.TransactionID = ct.ID
         where mv.ID = @MovementID
        if @Action = 'Cancel'
            begin
                /* Когда прилетает Cancel на весь Movement, мы удаляем все объекты с ним связанные в любом статусе */
                if exists (select 1
                             from QORT_TDB_PROD..CorrectPositions
                            where BackID like @BackID+'%') 
                    begin
                        update QORT_TDB_PROD.dbo.CancelCorrectPositions
                        set isProcessed = 1
                         where BackID like @BackID+'%';
                        if @@ROWCOUNT = 0
                            begin
                                insert into QORT_TDB_PROD.dbo.CancelCorrectPositions ( id
                                                                                     , BackID
                                                                                     , isProcessed ) 
                                select-1
                                    , BackID
                                    , 1
                                  from QORT_DB_PROD..CorrectPositions cp with (nolock, index = I_CorrectPositions_BackID)
                                 where cp.BackID like @BackID+'%'
                                       and cp.Date = 0
                                       and cp.IsCanceled = 'n'
                            end
                    end
                if exists (select 1
                             from QORT_TDB_PROD..Clearings with(nolock)
                            where BackID like @BackID+'%') 
                    begin
                        update QORT_TDB_PROD.dbo.CancelClearings
                        set isProcessed = 1
                         where BackID like @BackID+'%';
                        if @@ROWCOUNT = 0
                            begin
                                insert into QORT_TDB_PROD.dbo.CancelClearings ( id
                                                                              , BackID
                                                                              , isProcessed ) 
                                select-1
                                    , BackID
                                    , 1
                                  from QORT_TDB_PROD..Clearings with(nolock)
                                 where BackID like @BackID
                            end
                    end
            end
        if @Action = 'New'
            begin
                select @QRTObject = dr.QRTObject
                     , @QRTObjType = dr.QRTObjType
                     , @STLRuleID = dr.RuleID
                     , @SettledOnly = dr.SettledOnly
                     , @TransactionID = mv.TransactionID
                     , @ExternalID = ct.ExternalID
                     , @MovType = mv.MovType
                     , @Direction = mv.Direction
                     , @Qty = mv.Qty
                     , @Price = mv.Price
                     , @AccruedCoupon = mv.AccruedCoupon
                     , @ChargeType = mv.ChargeType
                     , @Amount = mv.Amount
                     , @Currency = mv.Currency
                  from QORT_DDM..DDM2QORT_Rules dr with(nolock)
                     , QORT_DDM..Movements mv with(nolock)
                     , QORT_DDM..CommonTransaction ct with(nolock)
                 where mv.ID = @MovementID
                       and mv.TransactionID = ct.ID
                       and dr.OperationType = ct.OperationType
                       and dr.MovType = mv.MovType
                       and dr.ChargeType = mv.ChargeType
                       and dr.IsSynchronized = 1
                       and dr.StartDate <= getdate()
                       and isnull(dr.EndDate, '20501231') > getdate()
                       and (dr.Direction is null
                            or dr.Direction = mv.Direction)
                if @QRTObject is null
                    begin
                        select @msg = '001. Expected Active transformation rule. MovementID = '+convert(varchar(50), @MovementID)
                             , @Rez = 1
                        return @Rez
                    end
                if @SettledOnly = 1
                    begin
                        select @msg = '002.Expected Settlement object for processing (SettledOnly = TRUE). MovementID = '+convert(varchar(50), @MovementID)
                             , @Rez = 2
                        return @Rez
                    end
                if @QRTObject = 'CorrectPosition'
                    begin
                        if @MovType = 'CASH'
                            select @Size = @Amount * @Direction
                           else
                            select @Size = @Qty * @Direction
                        exec QORT_DDM..DDM_InsertCorrectPosition @RuleID = @STLRuleID
                                                               , @MovementID = @MovementID
                                                               , @Qty = @Size
                                                               , @AccruedCoupon = @AccruedCoupon
                                                               , @Rez = @Rez out
                                                               , @msg = @msg out
                    end
            end
        return @Rez
    end
