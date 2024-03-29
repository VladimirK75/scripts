CREATE 
 procedure [dbo].[SetQORT_Accrual] @RunDate       date
                                  , @ISIN          varchar(16)
                                  , @SECID         varchar(16)
                                  , @GRDB_ID       varchar(16)
                                  , @MxLabel       varchar(128)
                                  , @Ccy           varchar(3)
                                  , @AccruedPrctT0 float
                                  , @AccruedAmntT0 float
                                  , @CapFactorT0   float
                                  , @AccruedPrct   float
                                  , @AccruedAmnt   float
                                  , @CapFactor     float
                                  , @msg           nvarchar(4000) output
as
    begin
        set nocount on;
        begin try
            declare @AuditHash int
            if exists( select 1
                         from QORT_DDM.dbo.GetQORT_Accrual
                        where RunDate = @RunDate
                              and [Issue.ISIN] = @ISIN
                              and [Issue.SECID] = @SECID
                              and [Issue.GRDB_ID] = @GRDB_ID
                              and [MX.IssueName] = @MxLabel
                              and [Issue.FaceValueCurrency] = @Ccy )
                begin
                    update gqa
                       set gqa.[Coupon.AccruedPercentT0] = @AccruedPrctT0
                         , gqa.[Coupon.AccruedAmountT0] = @AccruedAmntT0
                         , gqa.[Coupon.CapFactorT0] = @CapFactorT0
                         , gqa.[Coupon.AccruedPercent] = @AccruedPrct
                         , gqa.[Coupon.AccruedAmount] = @AccruedAmnt
                         , gqa.[Coupon.CapFactor] = @CapFactor
                         , gqa.AuditDateTime = getdate()
                         , gqa.AuditHash = binary_checksum(@RunDate, @ISIN, @SECID, @GRDB_ID, @MxLabel, @Ccy, @AccruedPrctT0, @AccruedAmntT0, @CapFactorT0, @AccruedPrct, @AccruedAmnt, @CapFactor)
                      from QORT_DDM.dbo.GetQORT_Accrual gqa
                     where gqa.RunDate = @RunDate
                           and gqa.[Issue.ISIN] = @ISIN
                           and gqa.[Issue.SECID] = @SECID
                           and gqa.[Issue.GRDB_ID] = @GRDB_ID
                           and gqa.[MX.IssueName] = @MxLabel
                           and gqa.[Issue.FaceValueCurrency] = @Ccy
                    select @msg = concat('000. Ok - Updated ', @ISIN, ' for ', format(@RunDate, 'yyyy-MM-dd'))
            end
                 else
                begin
                    insert into QORT_DDM.dbo.GetQORT_Accrual
                    ( RunDate
                    , [Issue.ISIN]
                    , [Issue.SECID]
                    , [Issue.GRDB_ID]
                    , [MX.IssueName]
                    , [Issue.FaceValueCurrency]
                    , [Coupon.AccruedPercentT0]
                    , [Coupon.AccruedAmountT0]
                    , [Coupon.CapFactorT0]
                    , [Coupon.AccruedPercent]
                    , [Coupon.AccruedAmount]
                    , [Coupon.CapFactor]
                    , AuditDateTime
                    , AuditHash
                    , Version
                    )
                    values
                    ( @RunDate
                    , @ISIN
                    , @SECID
                    , @GRDB_ID
                    , @MxLabel
                    , @Ccy
                    , @AccruedPrctT0
                    , @AccruedAmntT0
                    , @CapFactorT0
                    , @AccruedPrct
                    , @AccruedAmnt
                    , @CapFactor
                    , getdate()
                    , binary_checksum(@RunDate, @ISIN, @SECID, @GRDB_ID, @MxLabel, @Ccy, @AccruedPrctT0, @AccruedAmntT0, @CapFactorT0, @AccruedPrct, @AccruedAmnt, @CapFactor)
                    , null /* Version - timestamp*/
                    )
                    select @msg = concat('000. Ok - Inserted ', @ISIN, ' for ', format(@RunDate, 'yyyy-MM-dd'))
            end
        end try
        begin catch
            select @msg = concat('500. Fail ', error_message())
        end catch
    end
