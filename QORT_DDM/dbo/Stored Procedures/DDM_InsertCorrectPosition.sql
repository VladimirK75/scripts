CREATE procedure [dbo].[DDM_InsertCorrectPosition] 
                @RuleID                  bigint
              , @MovementID              bigint
              , @MovementID2             bigint          = null
              , @Size                    decimal(38, 14)  = null
              , @AccruedCoupon           float           = null
              , @SettlementDetailID      bigint          = null
              , @SettlementDate          datetime        = null
              , @msg                     nvarchar(4000) output
              , @TradeSettlementDetailID bit             = 0
as
    begin
        set nocount on
        begin try
            declare 
                   @BackID                 varchar(100)
                 , @Infosource             varchar(100)
                 , @NeedClientInstr        bit
                 , @CT_Const               smallint
                 , @ET_Const               smallint     = 2
                 , @ExternalID             varchar(255)
				 , @PlanDate               int
                 , @TradeDateInt           int
                 , @TradeTimeInt           int
                 , @SettlementDateInt      int
                 , @BackOfficeNotes        varchar(255)
                 , @LoroAccount            varchar(20)
                 , @NostroAccount          varchar(50)
                 , @GetLoroAccount         varchar(20)
                 , @GetNostroAccount       varchar(50)
                 , @Price                  float
                 , @Currency               varchar(3)
                 , @Asset_ShortName        varchar(48)
                 , @ReversedID             bigint
                 , @Comment2               varchar(255)
                 , @IsInternal             char(1)
                 , @PDocType_Name          varchar(200)
                 , @InstrNum               float
                 , @InternalNumber         varchar(255)
                 , @InstrDateTime          datetime
                 , @InstrDateInt           bigint
                 , @IT_Const               smallint
                 , @InstrStatus            varchar(255)
                 , @CorrPositionCheck      int
                 , @CorrPositionMinorCheck int
                 , @IsDual                 bit
                 , @NTOrderID              bigint
                 , @RowID                  float
                 , @RegistrationDate       int
                 , @OperDay                int
                 , @CorrDay                int
                 , @IEC_ID                 float
                 , @MockBackID             varchar(100)
                 , @QF                     bigint       = 0
            select @TradeTimeInt = 0
                 , @SettlementDateInt = convert(int, format(@SettlementDate, 'yyyyMMdd'))
				 , @InstrDateTime = getdate()
            if nullif(@SettlementDetailID, 0) is null
                begin /* get Movement details */
                    select @BackID = dr.BackID
                         , @MockBackID = concat(dr.ExternalID, '/%')
                         , @ExternalID = dr.ExternalID
                         , @TradeDateInt = dr.TradeDateInt
                         , @TradeTimeInt = iif(isnull(@SettlementDateInt, 0) > 0, 193000000, dr.TradeTimeInt)
                         , @RegistrationDate = dr.TradeDateInt
                         , @LoroAccount = dr.SubAccCode
                         , @NostroAccount = dr.AccountCode
                         , @BackOfficeNotes = dr.BackOfficeNotes
                         , @CT_Const = dr.CT_Const
                         , @IT_Const = dr.IT_Const
                         , @NeedClientInstr = dr.NeedClientInstr
                         , @Asset_ShortName = dr.Asset_ShortName
                         , @Price = dr.Price
                         , @Currency = dr.Currency
                         , @Size = round(isnull(@Size, dr.Size), 2)
                         , @AccruedCoupon = dr.AccruedCoupon
                         , @SettlementDate = null
                         , @SettlementDateInt = 0
                         , @GetLoroAccount = dr.GetLoroAccount
                         , @GetNostroAccount = dr.GetNostroAccount
                         , @Comment2 = dr.Comment2
                         , @Infosource = dr.Infosource
                         , @IsInternal = iif(isnull(dr.IsInternal, 0) = 0, 'N', 'Y')
                         , @PDocType_Name = dr.PDocType_Name
                         , @InternalNumber = dr.InternalNumber
                         , @InstrNum = dr.InstrNum
                         , @InstrStatus = dr.InstrStatus
                         , @msg = dr.msg
                      from QORT_DDM..DDM_GetImportMovement_Rule(@MovementID) dr
            end
               else
                begin /* get Transfer details */
                    if @TradeSettlementDetailID = 0
                        begin
                            select @BackID = dr.BackID
                                 , @MockBackID = concat(dr.ExternalID, '/%', dr.StlExternalID)
                                 , @MovementID = dr.MovementID
                                 , @ExternalID = dr.ExternalID
								 , @PlanDate = dr.PlanDate
                                 , @TradeDateInt = dr.TradeDateInt
                                 , @TradeTimeInt = iif(dr.SettledOnly = 1
                                                       and isnull(@SettlementDateInt, 0) > 0, 193000000, dr.TradeTimeInt)
                                 , @RegistrationDate = iif(dr.SettledOnly = 1
                                                           and isnull(dr.SettlementDateInt, 0) > 0, dr.SettlementDateInt, dr.TradeDateInt)
                                 , @LoroAccount = dr.SubAccCode
                                 , @NostroAccount = dr.AccountCode
                                 , @BackOfficeNotes = dr.BackOfficeNotes
                                 , @CT_Const = dr.CT_Const
                                 , @IT_Const = dr.IT_Const
                                 , @NeedClientInstr = dr.NeedClientInstr
                                 , @ReversedID = dr.ReversedID
                                 , @Asset_ShortName = dr.Asset_ShortName
                                 , @Price = dr.Price
                                 , @Currency = dr.Currency
                                 , @Size = round(isnull(@Size, dr.TranDirection * TranAmount), 2)
                                 , @AccruedCoupon = dr.AccruedCoupon
                                 , @SettlementDate = dr.SettlementDate
                                 , @SettlementDateInt = dr.SettlementDateInt
                                 , @GetLoroAccount = dr.GetLoroAccount
                                 , @GetNostroAccount = dr.GetNostroAccount
                                 , @Comment2 = dr.Comment2
                                 , @Infosource = dr.Infosource
                                 , @IsInternal = iif(isnull(dr.IsInternal, 0) = 0, 'N', 'Y')
                                 , @PDocType_Name = dr.PDocType_Name
                                 , @InternalNumber = dr.InternalNumber
                                 , @InstrNum = dr.InstrNum
                                 , @InstrStatus = dr.InstrStatus
                                 , @msg = dr.msg
                              from QORT_DDM..DDM_GetImportTransactions_Rule(@SettlementDetailID) dr
                    end
                       else
                        begin
                            select @BackID = dr.TradeNum + '/' + dr.StlExternalID
                                 , @MockBackID = concat(dr.TradeNum, '/%', dr.StlExternalID)
                                 , @ExternalID = dr.TradeNum
                                 , @TradeDateInt = dr.TradeDate
                                 , @TradeTimeInt = iif(dr.SettlementDate is not null, 193000000, 0)
                                 , @RegistrationDate = isnull(convert(int, format(dr.SettlementDate, 'yyyyMMdd')), dr.TradeDate)
                                 , @LoroAccount = dr.SubAccCode
                                 , @NostroAccount = dr.AccountCode
                                 , @BackOfficeNotes = dr.ChargeType
                                 , @CT_Const = dr.CT_Const
                                 , @IT_Const = null
                                 , @NeedClientInstr = 0
                                 , @ReversedID = null
                                 , @Asset_ShortName = dr.Currency
                                 , @Price = dr.Price
                                 , @Currency = dr.Currency
                                 , @Size = round(isnull(null, dr.Amount), 2)
                                 , @AccruedCoupon = dr.AccruedCoupon
                                 , @SettlementDate = dr.SettlementDate
                                 , @SettlementDateInt = isnull(convert(int, format(dr.SettlementDate, 'yyyyMMdd')), 0)
                                 , @GetLoroAccount = dr.GetLoroAccount
                                 , @GetNostroAccount = dr.GetNostroAccount
                                 , @Comment2 = dr.TradeNum + '/' + dr.ChargeType + '/' + dr.TransferType
                                 , @Infosource = 'BackOffice'
                                 , @IsInternal = 'N'
                                 , @PDocType_Name = null
                                 , @InternalNumber = null
                                 , @InstrNum = null
                                 , @InstrStatus = null
                                 , @msg = dr.msg
                              from QORT_DDM..DDM_GetImportTrade_Rule(@SettlementDetailID) dr
                    end
            end
            if isnull(@Msg, '') <> '' /* Interrupt in case of an error message */
                return
                /* [QORT-902] QORT RENBR DDM Service should check RegistrationDate for CorrectPositions  */
                select @CorrDay = isnull(max(s.Date), 0)
                  from QORT_DB_PROD..Specials s with(nolock)
                  inner join QORT_DB_PROD..Users u with(nolock) on s.User_ID = u.id
                 where u.last_name = 'srvDeadLine_Changes'
            select @RegistrationDate = iif(@RegistrationDate > @CorrDay, @RegistrationDate, @CorrDay)
            /* If we expect two-sides CorrectPosition we should check opposite CorrectPosition */
            if isnull(@IsDual, 0) = 1
               and isnull(@MovementID2, 0) > 0
               and (select count(1)
                      from QORT_TDB_PROD..CancelCorrectPositions ccp with (nolock, index = I_CancelCorrectPositions_BackID)
                     where ccp.BackID like @ExternalID + '/' + ltrim(str(@MovementID2, 16)) + '%'
                           and ccp.IsProcessed < 4) < (select count(1)
                                                         from QORT_TDB_PROD..CorrectPositions cp2 with (nolock, index = I_CorrectPositions_BackID)
                                                        where cp2.BackID like @ExternalID + '/' + ltrim(str(@MovementID2, 16)) + '%'
                                                              and cp2.IsProcessed < 4) 
                begin
                    select @msg = concat('304. Opposite CorrectPosition is already exists in QORT_TDB_PROD..CorrectPositions where BackID =', @ExternalID, '/', '%')
                    return
            end
            /* Перевод в рамках одного ЛОРО - это смена места хранения и не требует поручения клиента */
            if @LoroAccount = @GetLoroAccount
                select @IsInternal = 'Y'
            select @QF = iif(@IsInternal = 'Y', 4294967296, 0)
            /* 1-я проверка: есть ли точно такая же корректировка?  если да -- выйти с ответом "000. это дубликат" */
            /* @MockBackID содержит @BackID без Movement_ID, защита от бага сервиса когда к одному и тому же трансферу подставляется разный Movement_ID */
            select @RowID = tt.RowID
                 , @CorrPositionCheck = tt.CorrPositionCheck
                 , @CorrPositionMinorCheck = tt.CorrPositionMinorCheck
              from (select RowID = cp.id
                         , CorrPositionCheck = binary_checksum(isnull([Date], 0), BackID, Subacc_Code, Account_ExportCode, isnull(Comment, ''), CT_Const, Asset, Size, Price, CurrencyAsset, isnull(Accrued, 0), RegistrationDate, GetSubacc_Code, GetAccount_ExportCode, Comment2, isnull(QF_Flags, 0), PDocType_Name, ClientInstr_InternalNumber, ClientInstr_InstrNum)
                         , CorrPositionMinorCheck = binary_checksum(BackID, Subacc_Code, Account_ExportCode, CT_Const, Asset, Size, Price, CurrencyAsset, isnull(Accrued, 0), RegistrationDate, GetSubacc_Code, GetAccount_ExportCode, isnull(QF_Flags, 0), PDocType_Name, ClientInstr_InternalNumber, ClientInstr_InstrNum)
                      from QORT_TDB_PROD.dbo.CorrectPositions cp with (nolock, index = I_CorrectPositions_BackID)
                     where cp.BackID like @MockBackID
                           and cp.IsProcessed < 4
                           and not exists (select 1
                                             from QORT_TDB_PROD.dbo.CorrectPositions cp0 with (nolock, index = I_CorrectPositions_BackID)
                                            where cp0.BackID = cp.BackID
                                                  and cp0.IsProcessed < 4
                                                  and cp0.id > cp.id) 
                    union all
                    select RowID = cp.id
                         , CorrPositionCheck = binary_checksum(isnull([Date], 0), BackID, Subacc_Code, Account_ExportCode, isnull(Comment, ''), CT_Const, Asset, Size, Price, CurrencyAsset, isnull(Accrued, 0), RegistrationDate, GetSubacc_Code, GetAccount_ExportCode, Comment2, isnull(QF_Flags, 0), PDocType_Name, ClientInstr_InternalNumber, ClientInstr_InstrNum)
                         , CorrPositionMinorCheck = binary_checksum(BackID, Subacc_Code, Account_ExportCode, CT_Const, Asset, Size, Price, CurrencyAsset, isnull(Accrued, 0), RegistrationDate, GetSubacc_Code, GetAccount_ExportCode, isnull(QF_Flags, 0), PDocType_Name, ClientInstr_InternalNumber, ClientInstr_InstrNum)
                      from QORT_TDB_PROD.dbo.CorrectPositions cp with (nolock, index = I_CorrectPositions_BackID)
                     where cp.BackID like concat(left(@MockBackID, charindex('/', @MockBackID)), @MovementID) /*@MovBackId*/
                           and @MovementID is not null
                           and cp.IsProcessed < 4
                           and not exists (select 1
                                             from QORT_TDB_PROD.dbo.CorrectPositions cp0 with (nolock, index = I_CorrectPositions_BackID)
                                            where cp0.BackID = cp.BackID
                                                  and cp0.IsProcessed < 4
                                                  and cp0.id > cp.id) ) tt
            order by tt.RowID asc
            if @RowID is not null
                begin
                    set @ET_Const = 4
                    if @CorrPositionCheck = binary_checksum(isnull(@SettlementDateInt, 0), @BackID, @LoroAccount, @NostroAccount, isnull(@BackOfficeNotes, ''), @CT_Const, @Asset_ShortName, cast(@Size as float), @Price, @Currency, @AccruedCoupon, @RegistrationDate, @GetLoroAccount, @GetNostroAccount, @Comment2, isnull(@QF, 0), @PDocType_Name, @InternalNumber, @InstrNum)
                       and exists (select 1 from QORT_DB_PROD..CorrectPositions cp with (nolock) where 1=1 and cp.BackID=@BackID and cp.Enabled=0 and cp.IsCanceled='n' )
                       and @LoroAccount != 'RB0047' /* заглушка на время */
					   begin
                            select @msg = concat('304. CorrectPosition is already exists for the BackID = ', @BackID)
                            return
                    end
                       else
                        begin
                            /* 2-я проверка: если это другой кейс, чем "-> SETTLED" - отменить предыдущую */
                            if @CorrPositionMinorCheck <> binary_checksum(@BackID, @LoroAccount, @NostroAccount, @CT_Const, @Asset_ShortName, cast(@Size as float), @Price, @Currency, @AccruedCoupon, @RegistrationDate, @GetLoroAccount, @GetNostroAccount, isnull(@QF, 0), @PDocType_Name, @InternalNumber, @InstrNum)
                                begin
                                    if @MovementID is not null
                                        set @MockBackID = concat(left(@MockBackID, charindex('/', @MockBackID)), @MovementID)
                                    exec DDM_MovementCancel @MovementID = null
                                                          , @msg = @msg out
                                                          , @BackID = @MockBackID
                                    set @ET_Const = 2
                            end
                    end
            end
            /* 3-я проверка. Если это перевод, то отправлять в репроцесс(пендинг) отрицательные движения, пока отсутствует положительное */
            if @CT_Const in(11, 12)
               and @IsInternal = 'Y'
               and @Size < 0
                begin
                    if not exists (select 1
                                     from QORT_DB_PROD..CorrectPositions cp with(nolock)
                                    where 1 = 1
                                          and cp.BackID like concat(@ExternalID, '/%')
                                          and cp.CT_Const = @CT_Const
                                          and isnull(cp.IsCanceled, 'n') = 'n'
                                          and cp.Size = abs(cast(@Size as float)))
										  
                        begin
                            select @msg = '404. Negative InteraccountOperation is waiting for a positive one'
                            return
                    end
            end
            /* */
            set @RowID = null
            if @NeedClientInstr = 1
               and isnull(@ReversedID, 0) = 0
               and @IsInternal = 'N'
               and isnull(@InternalNumber, '') <> ''
                begin
                    select @InstrDateInt =  isnull(@RegistrationDate, convert(int, format(getdate(), 'yyyyMMdd')))
                    select @NTOrderID = ID
                         , @InstrDateInt = convert(int, format(dateadd(hh, 3, RaisedDateTime), 'yyyyMMdd'))
                      from QORT_DDM..NonTradingOrders with(nolock)
                     where ExternalID = @InternalNumber
                    exec QORT_DDM..DDM_InsertClientInstr @OrderID = @NTOrderID /* if null - will be created */
                                                       , @PlanDate = @PlanDate
													   , @FinishDateTime = @SettlementDate
                                                       , @InternalNumber = @InternalNumber
                                                       , @InstrNum = @InstrNum
                                                       , @IT_Const = @IT_Const
                                                       , @INSTR_Const = 21 /* Не задан*/
                                                       , @SourceLoro = @LoroAccount
                                                       , @TargetLoro = @GetLoroAccount
                                                       , @Amount = @Size
                                                       , @Currency = @Asset_ShortName
                                                       , @Status = @InstrStatus
                                                       , @msg = @msg output
            end
            while @RowID is null
                begin
                    exec QORT_TDB_PROD..P_GenFloatValue @RowID output
                                                      , 'correctpositions_table'
                end
            insert into QORT_TDB_PROD.dbo.CorrectPositions ( id
                                                           , BackID
														   , PlanDate
                                                           , [Date]
                                                           , [Time]
                                                           , Subacc_Code
                                                           , Account_ExportCode
                                                           , Comment
                                                           , CT_Const
                                                           , Asset
                                                           , Size
                                                           , Price
                                                           , CurrencyAsset
                                                           , IsProcessed
                                                           , Accrued
                                                           , ET_Const
                                                           , RegistrationDate
                                                           , GetSubacc_Code
                                                           , GetAccount_ExportCode
                                                           , Comment2
                                                           , Infosource
                                                           , IsInternal
                                                           , QF_Flags
                                                           , PDocType_Name
                                                           , ClientInstr_InternalNumber
                                                           , ClientInstr_InstrNum
                                                           , ClientInstr_Date
                                                           , IsExecByComm ) 
            values(
                   @RowID, @BackID, @PlanDate, isnull(@SettlementDateInt, 0), isnull(@TradeTimeInt, 0), @LoroAccount, @NostroAccount, @BackOfficeNotes, @CT_Const, @Asset_ShortName, cast(@Size as float), @Price, @Currency, 1, @AccruedCoupon, @ET_Const, @RegistrationDate, @GetLoroAccount, @GetNostroAccount, @Comment2, @Infosource, @IsInternal , @QF, @PDocType_Name, @InternalNumber, @InstrNum, @InstrDateInt, 'Y')
            if @@ROWCOUNT > 0
                begin
                    exec QORT_DDM..DDM_ImportExecutionCommands @TC_Const = 5
                                                             , @Oper_ID = @RowID
                                                             , @Comment = @BackID
                                                             , @SystemName = 'DDM_InsertCorrectPosition'
                                                             , @Priority = 3
                    select @msg = concat('000. CP @BackID = ', @BackID, ' is inserted. @Size: ', cast(@Size as money), ' @SettlementDateInt: ', nullif(@SettlementDateInt, 0), ';', @msg)
            end
            return
        end try
        begin catch
            select @msg = error_message()
            return
        end catch
    end
