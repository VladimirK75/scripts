CREATE procedure dbo.DDM_InsertTradeInstr 
                @OrderID    bigint
              , @Status     varchar(50) /* as in DDM (New, Executing, Executed, Rejected, Cancelled)*/
              , @FinishDate bigint         = null /* crutch for EAI Trades Adapter */
              , @FinishTime bigint         = null /* crutch for EAI Trades Adapter */
              , @msg        nvarchar(4000) output
as
    begin
        set nocount on
        begin try
            declare 
                   @RowID                   float(53)
                 , @RegisterNum             varchar(256)
                 , @IS_Const                int
                 , @WithdrawTime            int
                 , @PT_Const                smallint
                 , @IT_Const                smallint
                 , @TSSection_Name          varchar(100)
                 , @TSSection_ID            float
                 , @Security_Code           varchar(100)
                 , @Qty                     float
                 , @Price                   float
                 , @Discount                float
                 , @CurrencyAsset_ShortName varchar(48)
                 , @RepoRate                float
                 , @RepoTerm                smallint
                 , @BackPrice               float
                 , @DateInt                 int
                 , @TimeInt                 int
                 , @PutPlannedDate          int
                 , @PayPlannedDate          int
                 , @RepoDate2               int
                 , @TBT_Const               smallint
                 , @Infosource              varchar(200)
                 , @IsAgent                 char(1)
                 , @ET_Const                smallint
                 , @BackID                  varchar(255)
                 , @SubaccCode              varchar(16)
                 , @CpFirm_BOCode           varchar(32)
                 , @Firm_ShortName          varchar(150)
                 , @Firm_BOCode             varchar(32)
                 , @OwnerFirm_ShortName     varchar(150)
                 , @OwnerFirm_BOCode        varchar(32)
                 , @IEC_ID                  float
            select @RegisterNum = tor.ExternalID
                 , @WithdrawTime = iif(@Status in('Rejected', 'Cancelled'), convert(int, format(StatusDateTime, 'HHmmss000')), null)
                 , @Qty = tor.Qty
                 , @Price = tor.Price
                 , @Discount = tor.Haircut
                 , @CurrencyAsset_ShortName = replace(tor.PriceCurrency, 'RUB', 'RUR')
                 , @RepoRate = tor.RepoRate
                 , @RepoTerm = tor.Duration
                 , @BackPrice = tor.BackPrice
                 , @DateInt = convert(int, format(tor.RaisedDateTime, 'yyyyMMdd'))
                 , @TimeInt = convert(int, format(tor.RaisedDateTime, 'HHmmssfff'))
                 , @PutPlannedDate = convert(int, format(tor.DeliveryDate, 'yyyyMMdd'))
                 , @PayPlannedDate = convert(int, format(tor.PaymentDate, 'yyyyMMdd'))
                 , @RepoDate2 = convert(int, format(tor.BackDate, 'yyyyMMdd'))
                 , @FinishDate = isnull(@FinishDate, iif(@Status not in('New', 'Executing'), convert(int, format(StatusDateTime, 'yyyyMMdd')), null))
                 , @FinishTime = isnull(@FinishTime, iif(@Status not in('New', 'Executing'), convert(int, format(StatusDateTime, 'HHmmss000')), null))
                 , @TBT_Const = case tor.TimeBasis
                                     when 'ACT_360' then 1
                                     when 'ACT_365' then 3
                                     when 'ACT_ACT' then 8
                                     when 'ACT_366' then 7
                                     when '30_360' then 5
                                     when '30EPlus_360' then 4
                                   else null
                                end
                 , @Infosource = case tor.SourceSystem
                                      when 'FIDESSA' then 'FIX FD'
                                      when 'MUREX' then 'FIX MX'
                                    else null
                                 end
                 , @IsAgent = iif(tor.BrokerRole = 'Agent', 'Y', 'N')
                 , @BackID = tor.ExternalID + '/' + ltrim(str(tor.ID, 16))
                 , @SubaccCode = tor.LoroAccount
                 , @IS_Const = case @Status
                                    when 'New' then 1
                                    when 'Executing' then 4
                                    when 'Executed' then 5
                                    when 'Rejected' then 8
                                    when 'Cancelled' then 6
                                  else null
                               end
                 , @IT_Const = case
                                    when tor.OrderType in('EquityOrder', 'FixedIncomeOrder', 'FXOrder', 'ListedOptionOrder', 'ListedForwardOrder', 'SWAPOrder', 'FXForwardOrder') then iif(Direction = 1, 7, 8)
                                    when tor.OrderType in('RepoOrder', 'RepoBondOrder') then iif(Direction = 1, 10, 9)
                                  else 17
                               end
                 , @PT_Const = iif(tor.OrderType in('RepoBondOrder', 'FixedIncomeOrder'), 1, 2)
                 , @TSSection_Name = itr.TSSection
                 , @TSSection_ID = ts.id
                 , @CpFirm_BOCode = tor.Counterparty
                 , @Firm_ShortName = f.FirmShortName
                 , @Firm_BOCode = f.BOCode
                 , @OwnerFirm_ShortName = o.FirmShortName
                 , @OwnerFirm_BOCode = o.BOCode
                 , @Security_Code = sec.SecCode
                 , @msg = case
                               when itr.RuleID is null then '404. ImportTrade_Rules not found for Order=' + tor.ExternalID + ' and OrderType=' + tor.OrderType + ' in QORT_DDM.dbo.ImportTrade_Rules'
                               when ts.id is null then '404. TSSection=' + itr.TSSection + ' not found for Order=' + tor.ExternalID + ' and OrderType=' + tor.OrderType + ' and RuleID=' + ltrim(str(itr.RuleID, 16)) + ' in QORT_DB_PROD..TSSections'
                               when f.id is null then '404. LegalEntity=' + isnull(nullif(tor.LegalEntity, ''), 'null') + ' not ours for OrderOrder=' + tor.ExternalID + ' in QORT QORT_DB_PROD..Firms'
                               when s.id is null then '404. LoroAccount (SubAccCode=' + isnull(nullif(tor.LoroAccount, ''), 'null') + ') not found for Order=' + tor.ExternalID + ' in QORT Subaccs.SubAccCode'
                               when isnull(tor.Issue, '') = '' then '404. Issue is empty for Order=' + tor.ExternalID + ' and OrderType=' + tor.OrderType
                               when isnull(a.id, a2.id) is null then '404. Asset not found for Issue=' + tor.Issue + ' Order=' + tor.ExternalID + ' and OrderType=' + tor.OrderType + ' in GRDBServices.Publication.CurrPairGrdbMap and QORT_DB_PROD..Assets'
                               when sec.id is null then '404. Security not found for Issue=' + tor.Issue + ' Order=' + tor.ExternalID + ' and OrderType=' + tor.OrderType + ' in QORT_DB_PROD..Securities'
                             else null
                          end
              from QORT_DDM.dbo.TradeOrders tor with(nolock)
              left join QORT_DDM.dbo.ImportTrade_Rules itr with(nolock) on tor.OrderType = itr.OrderType
              left join QORT_DB_PROD..TSSections ts with(nolock) on ts.Name = itr.TSSection
              left join QORT_DB_PROD..Subaccs s with(nolock) on s.SubAccCode = tor.LoroAccount collate Cyrillic_General_CS_AS
                                                                and s.Enabled = 0
              left join QORT_DB_PROD..Firms o with(nolock) on o.ID = s.OwnerFirm_ID
              left join QORT_DB_PROD..Firms f with(nolock) on f.BOCode = tor.LegalEntity
                                                              and f.Enabled = 0
                                                              and f.IsOurs = 'y'
              left join QORT_DB_PROD..Assets a with(nolock) on a.Marking = tor.Issue
                                                               and a.Enabled = 0
              left join QORT_DB_PROD..Assets a2 with(nolock) on tor.Issue = a2.ISIN
                                                                and a2.Enabled = 0
              left join QORT_DB_PROD..Securities sec with(nolock) on sec.TSSection_ID = ts.id
                                                                     and iif(sec.Asset_ID in(a.id, a2.id), 1, 0) + iif(sec.SecCode = replace(a.Name, '/', ''), 1, 0) > 0 /* КОСТЫЛЬ для поручений FX из MUREX  */
                                                                     and sec.Enabled = 0
             where 1 = 1
                   and tor.ID = @OrderID
            if isnull(@msg, '') <> ''
                begin
                    update QORT_DDM..TradeOrders with(rowlock)
                    set ProcessingState = 'ErrorOnCreation'
                      , ProcessingMessage = @msg
                     where ID = @OrderID
                    return
            end
            /*-------------------------------------- / AuthorFIO, AuthorPTS / ----------------------------------------*/
            declare 
                   @AuthorFIO varchar(100) = ''
                 , @AuthorPTS varchar(32)  = ''
            select @AuthorFIO = isnull(ir.AuthorFIO, '''')
                 , @AuthorPTS = isnull(ir.AuthorPTS, '''')
              from QORT_DB_PROD..InstrRules ir(nolock)
             where ir.Priority = (select min(ir.Priority) as MinPriority
                                    from QORT_DB_PROD..InstrRules ir(nolock)
                                   where 1 = 1
                                         and ir.TSSection_ID in (@TSSection_ID, -1)
                                         and case
                                                  when ir.SubaccCode in ('', '*') then 1
                                                else patindex(replace(ir.SubaccCode, '*', '%'), @SubaccCode)
                                             end = 1
                                         and case
                                                  when ir.InfoSource in ('', '*') then 1
                                                else patindex(replace(ir.InfoSource, '*', '%'), @InfoSource)
                                             end = 1
                                         and ir.Trader in ('', '*')
                                         and ir.QUIKUID = 0
                                         and ir.HM_Const = 1
                                         and ir.DM_Const = 2)
            /*-------------------------------------- / AuthorFIO, AuthorPTS / ----------------------------------------*/ 
            select @ET_Const = iti.ET_Const
              from QORT_TDB_PROD..ImportTradeInstrs iti with(nolock)
             where iti.BackID = @BackID
                   and iti.IsProcessed < 4
                   and not exists (select 1
                                     from QORT_TDB_PROD..ImportTradeInstrs iti2 with(nolock)
                                    where iti2.BackID = @BackID
                                          and iti2.IsProcessed < 4
                                          and iti2.id > iti.id) 
            if nullif(@ET_Const, 8) is null
                select @ET_Const = iif(@Status in('Rejected', 'Cancelled'), null, 2)
               else
                select @ET_Const = 4
            if @ET_Const is null
                select @msg = '000. TradeInstrs not found for ' + @Status + ' Order=' + @RegisterNum + ' in QORT_TDB_PROD..ImportTradeInstrs BackID=' + @BackID
               else
                begin
                    select @msg = '500. Order=' + @RegisterNum + ' for Status=' + @Status + ' has not been inserted into QORT_TDB_PROD..ImportTradeInstrs'
                    while @RowID is null
                        begin
                            exec QORT_TDB_PROD..P_GenFloatValue @RowID output
                                                              , 'importtradeinstrs_table'
            end
                    insert into QORT_TDB_PROD..ImportTradeInstrs with(rowlock) ( id
                                                                               , Firm_ShortName
                                                                               , Date
                                                                               , Time
                                                                               , RegisterNum
                                                                               , OwnerFirm_ShortName
                                                                               , Section_Name
                                                                               , Type
                                                                               , Security_Code
                                                                               , Qty
                                                                               , PutPlannedDate
                                                                               , PayPlannedDate
                                                                               , AuthorSubAcc_Code
                                                                               , IS_Const
                                                                               , BackPrice
                                                                               , Volume2
                                                                               , RepoRate
                                                                               , RepoDate2
                                                                               , Price
                                                                               , PriceType
                                                                               , Volume
                                                                               , OwnerFirm_BOCode
                                                                               , Firm_BOCode
                                                                               , RepoTerm
                                                                               , BackID
                                                                               , CurrencyAsset_ShortName
                                                                               , TimeBasis
                                                                               , WithdrawTime
                                                                               , CpFirm_BOCode
                                                                               , DM_Const /* Electronno*/
                                                                               , FinishDate
                                                                               , FinishTime
                                                                               , Discount
                                                                               , InstrSort_Const
                                                                               , InfoSource_Name
                                                                               , TYPE_Const
                                                                               , IsAgent
                                                                               , ET_Const
                                                                               , IsExecByComm
                                                                               , IsProcessed
                                                                               , AuthorFIO
                                                                               , AuthorPTS ) 
                    values(
                           @RowID, @Firm_ShortName, @DateInt, @TimeInt, @RegisterNum, @OwnerFirm_ShortName, @TSSection_Name, @IT_Const, @Security_Code, @Qty, @PutPlannedDate, @PayPlannedDate, @SubaccCode, @IS_Const, @BackPrice, null, @RepoRate, @RepoDate2, @Price, @PT_Const, null, @OwnerFirm_BOCode, @Firm_BOCode, @RepoTerm, @BackID, @CurrencyAsset_ShortName, @TBT_Const, @WithdrawTime, @CpFirm_BOCode, 2 /* Electronno*/
                           , @FinishDate, @FinishTime, @Discount, 2, @Infosource, 2 /* TYPE CONST Torgovoe*/
                           , @IsAgent, @ET_Const /*ET Const*/
                           , 'Y' /* IsExecByComm*/
                           , 1, @AuthorFIO, @AuthorPTS)
                    if @@ROWCOUNT > 0
                        begin
                            select @msg = '000. Ok'
                            exec QORT_DDM..DDM_ImportExecutionCommands @TC_Const = 19
                                                                     , @Oper_ID = @RowID
                                                                     , @Comment = @BackID
                                                                     , @SystemName = 'DDM_InsertTradeInstr'
                    end
            end
            update QORT_DDM..TradeOrders with(rowlock)
            set ProcessingState = iif(left(@msg, 4) = '000.', 'Processed', 'ErrorOnCreation')
              , ProcessingMessage = @msg
             where ID = @OrderID
            return
        end try
        begin catch
            select @msg = error_message()
            return
        end catch
    end
