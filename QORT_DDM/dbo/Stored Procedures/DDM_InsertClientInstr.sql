CREATE procedure [dbo].[DDM_InsertClientInstr] 
                @OrderID        bigint          = null
              , @InternalNumber varchar(255)    = null
              , @InstrNum       bigint          = null
              , @InstrDateTime  datetime        = null
			  , @PlanDate       int             = null
              , @FinishDateTime datetime        = null
              , @IT_Const       smallint        = null
              , @INSTR_Const    smallint        = null
              , @SourceLoro     varchar(50)     = null
              , @TargetLoro     varchar(50)     = null
              , @Amount         decimal(38, 14)  = null
              , @Currency       varchar(3)      = null
              , @Status         varchar(50) /* as in DDM (Draft, Executing, Executed, RequestForCancel, Cancelled)*/
              , @msg            nvarchar(4000) output
as
    begin
        set nocount on
            declare 
                   @Status_Const    int
                 , @InstrDateInt    int
                 , @InstrTimeInt    int
                 , @FinishDateInt   int
                 , @FinishTimeInt   int
                 , @DM_Const        smallint
                 , @ET_Const        smallint     = 2
                 , @InstrSort_Const smallint     = 2
                 , @TYPE_Const      smallint     = 3
                 , @IsManEnter      char(1)      = 'N'
                 , @RecDocumentForm varchar(64)
                 , @Infosource      varchar(255)
                 , @AuthorPTS       varchar(50)  = ''
                 , @AuthorFIO       varchar(50)  = ''
                 , @RowID           float
                 , @IEC_ID          float
            select @Status_Const = case @Status
                                        when 'Draft' then 0
                                        when 'Executed' then 1
                                        when 'Cancelled' then 2
                                        when 'RequestForCancel' then 4
                                        when 'Executing' then 5
                                      else null
                                   end
                 , @FinishDateInt = convert(int, format(@FinishDateTime, 'yyyyMMdd'))
                 , @FinishTimeInt = convert(int, format(@FinishDateTime, 'HHmmssfff'))
            if @FinishDateInt > 0
                select @FinishTimeInt = 193000000
            if isnull(@OrderID, 0) > 0 /* Procedure is called from Order processing service or OrderID is known for Transaction*/
                begin
                    select @InternalNumber = ExternalID
                         , @InstrNum = abs(cast(hashbytes('MD5', ExternalID) as int))
                         , @InstrDateTime = dateadd(hh, 3, RaisedDateTime) /* from UTC to MSK*/
                         , @Amount = Amount
                         , @Currency = replace(Currency, 'RUB', 'RUR')
                         , @SourceLoro = SourceLoro
                         , @TargetLoro = TargetLoro
                         , @DM_Const = 2 /* Electronic*/
                         , @IT_Const = case OrderType
                                            when 'CashInterAccountTransferOrder' then 3 /* CashInteraccountTransfer*/
                                            when 'CashOutOrder' then 2 /* CashOut*/
                                            when 'CashInOrder' then 1 /* CashIn*/
                                       end
                         , @Infosource = case SourceSystem
                                              when 'PIPELINER' then 'WebCabinet'
                                              when 'EDFCashOrders' then 'Outlook'
                                         end
                         , @INSTR_Const = case OrderType
                                               when 'CashInterAccountTransferOrder' then 3 /* CashInteraccountTransfer*/
                                               when 'CashOutOrder' then 5 /* CashOut*/
                                               when 'CashInOrder' then 0 /* CashIn*/
                                          end
                         , @AuthorPTS = SourceSystem
                         , @AuthorFIO = ''
                      from QORT_DDM..NonTradingOrders with(nolock)
                     where ID = @OrderID
            end
               else /* All Instructions parameters should be defined. Instruction is manual*/
                begin
                    select @DM_Const = 3 /* Paper*/
                         , @Infosource = 'Manual'
                         , @AuthorPTS = ''
                         , @AuthorFIO = 'Client Manager'
            end
            if patindex('POS%', isnull(@SourceLoro,'')) + patindex('POS%', isnull(@TargetLoro,'')) > 0
                begin
                    select @msg = concat('403. ClientInstr filtered out by LORO. @SourceLoro = ', @SourceLoro, ',  @TargetLoro = ', @TargetLoro)
                    return
            end
            select @InstrDateInt = convert(int, format(isnull(@InstrDateTime, getdate()), 'yyyyMMdd'))
                 , @InstrTimeInt = convert(int, format(isnull(@InstrDateTime, getdate()), 'HHmmssfff'))
                 , @RowID = null
                 , @ET_Const = 2
            select @RowID = ici.id
              from QORT_TDB_PROD.dbo.ImportClientInstr ici with(nolock)
             where ici.InternalNumber = @InternalNumber
                   and ici.IsProcessed < 4
                   and not exists (select 1
                                     from QORT_TDB_PROD.dbo.ImportClientInstr ici2 with(nolock)
                                    where ici2.InternalNumber = ici.InternalNumber
                                          and ici2.IsProcessed = 3
                                          and ici2.id > ici.id) 
            if @RowID is not null
                select @InstrDateInt = iif(isnull(@OrderID, 0) > 0, @InstrDateInt, Date)
                     , @InstrTimeInt = iif(isnull(@OrderID, 0) > 0, @InstrTimeInt, Time)
                     , @FinishDateInt = iif(@FinishDateInt > 0, @FinishDateInt, isnull(AcceptDate, 0))
                     , @FinishTimeInt = iif(@FinishTimeInt > 0, @FinishTimeInt, isnull(AcceptTime, 0))
                     , @Status_Const = coalesce(nullif(@Status_Const,0), ici.STATUS_Const,0)
                     , @InstrSort_Const = 2
                     , @TYPE_Const = 3
                     , @IsManEnter = 'N'
                     , @ET_Const = 4
                  from QORT_TDB_PROD.dbo.ImportClientInstr ici with(nolock)
                 where ici.id = @RowID
            select @RowID = null
            begin
                while @RowID is null
                    begin
                        exec QORT_TDB_PROD..P_GenFloatValue @RowID output
                                                          , 'correctpositions_table'
                    end
                insert into QORT_TDB_PROD.dbo.ImportClientInstr ( id
                                                                , StartDate
                                                                , Date
                                                                , Time
                                                                , AcceptDate
                                                                , AcceptTime
																, SubAcc_SubAccCode
                                                                , GetSubacc_SubAccCode
                                                                , IT_Const
                                                                , INSTR_Const
                                                                , STATUS_Const
                                                                , Asset_ShortName
                                                                , Size
                                                                , DM_Const
                                                                , InfoSource_Name
                                                                , AuthorPTS
                                                                , AuthorFIO
                                                                , InstrSort_Const
                                                                , TYPE_Const
                                                                , InstrNum
                                                                , RegNum
                                                                , RecDocumentForm
                                                                , InternalNumber
                                                                , ET_Const
                                                                , IsManEnter
                                                                , IsProcessed
                                                                , IsExecByComm ) 
                values(
                       @RowID, @PlanDate, @InstrDateInt, @InstrTimeInt, @FinishDateInt, @FinishTimeInt, @SourceLoro, @TargetLoro, @IT_Const, @INSTR_Const, @Status_Const, @Currency, @Amount, @DM_Const, @Infosource, @AuthorPTS, @AuthorFIO, @InstrSort_Const, @TYPE_Const, @InstrNum, @InternalNumber, @RecDocumentForm, @InternalNumber, @ET_Const, @IsManEnter, 1, 'Y');
            end
            exec QORT_DDM..DDM_ImportExecutionCommands @TC_Const = 18
                                                     , @Oper_ID = @RowID
                                                     , @Comment = @InternalNumber
                                                     , @SystemName = 'DDM_InsertClientInstr'
            /* Мы ждём, пока поручение создаётся или 30 секунд */
            declare 
                   @TimeDelay   int      = 30
                 , @TimeStart   datetime = getdate()
                 , @IsProcessed bit      = 0
            while @IsProcessed = 0
                  and datediff(ss, @TimeStart, getdate()) < @TimeDelay
                begin
                    if exists (select 1
                                 from QORT_TDB_PROD.dbo.ImportClientInstr ici with(nolock)
                                where ici.InstrNum = @InstrNum
                                      and ici.IsProcessed = 3) 
                        set @IsProcessed = 1
                end
            /* */
            select @msg = '000. Ok'
            return
    end
