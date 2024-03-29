CREATE procedure dbo.DDM_InsertTradeBlock 
                 @ExternalID       varchar(255)           /* Transfer ID  */
               , @Trade_SID        bigint                 /* DB.Trades.ID */
               , @PC_Const         int
               , @AccrualDate      datetime       = null
               , @CommissionName   varchar(100)
               , @LoroAccount      varchar(6)
               , @NostroAccount    varchar(50)
               , @GetLoroAccount   varchar(6)     = null
               , @GetNostroAccount varchar(50)    = null
               , @Issue            varchar(25)
               , @Amount           float
               , @Direction        smallint
               , @Action           nvarchar(7)            /* New and Cancel only*/
               , @msg              nvarchar(4000) output
as
    begin
        set nocount on
        declare 
               @AccrualDateInt  int
             , @Asset_ShortName varchar(48)
             , @CommissionID    bigint
             , @ET_Const        smallint    = 8 /* delete by default */
             , @TC_Const        smallint    = 11
             , @AccrualTime     int         = 0
             , @BackID          varchar(64)
             , @RowID           float
             , @Ibcot_ID        float
             , @Ibcot_CheckSum  int
             , @Block_CheckSum  int
        select @CommissionID = id
          from QORT_DB_PROD..Commissions with(nolock)
         where Name like @CommissionName
        if isnull(@CommissionID, 0) = 0
            begin
                select @msg = '400. Bad Request. Commission ID not found for @CommissionName = ' + isnull(@CommissionName, '<empty>')
                return
        end
        if nullif(@Trade_SID, 0) is null
            begin
                select @msg = '400. Bad Request. Field Trade_SystemID=@Trade_SID must be specified but set as EMPTY'
                return
        end
        /* UNSETTLE prev Phase */
        if exists (select 1
                     from QORT_TDB_PROD..Phases with(nolock)
                    where Trade_SID = @Trade_SID
                          and isnull(IsCanceled, 'n') = 'n'
                          and patindex('%' + @ExternalID + '%', Backid) + patindex('%' + @ExternalID + '%', Infosource) > 0) 
            begin
                exec QORT_DDM.dbo.DDM_PhaseCancel @ExternalID = @ExternalID
                                                , @Trade_SID = @Trade_SID
                                                , @msg = @msg out
        end
        /* get truly Asset_ShortName for Issue */
        select @Asset_ShortName = ShortName
          from QORT_DB_PROD..Assets with(nolock)
         where Marking = replace(@Issue, 'RUB', 'RUR')
        /* set Trade Date when AvaliableDate is null */
        select @AccrualDateInt = isnull(convert(int, format(@AccrualDate, 'yyyyMMdd')), 0)
        if isnull(@AccrualDateInt, 0) = 0
            select @AccrualDateInt = TradeDate
              from QORT_TDB_PROD..Trades with(nolock)
             where SystemID = @Trade_SID
        /* get current values if exists */
        select @Amount = @Amount * @Direction * -1
             , @BackID = @ExternalID + '/' + ltrim(str(@PC_Const))
        select @Ibcot_ID = ibcot.id
             , @Ibcot_CheckSum = binary_checksum(PC_Const, AccrualDate, AccrualTime, Trade_SystemID, Size, Calc_Value, GetAccountExportCode, GetSubAccCode, SubAccCode, AccountExportCode, Calc_Currency_ShortName, Currency_ShortName, Commission_SID, CommissionName)
          from QORT_TDB_PROD..ImportBlockCommissionOnTrades ibcot with(nolock)
         where ibcot.Trade_SystemID = @Trade_SID
               and ibcot.BackID = @BackID
               and ibcot.IsProcessed < 4
               and ibcot.ET_Const < 5
               and not exists (select 1
                                 from QORT_TDB_PROD..ImportBlockCommissionOnTrades ibcot2 with(nolock)
                                where ibcot2.id > ibcot.id
                                      and ibcot2.Trade_SystemID = ibcot.Trade_SystemID
                                      and ibcot2.BackID = ibcot.BackID
                                      and ibcot2.IsProcessed < 4)
         order by ibcot.id desc
        set @Block_CheckSum = binary_checksum(@PC_Const, @AccrualDateInt, @AccrualTime, cast(@Trade_SID as float), @Amount, abs(@Amount), @GetNostroAccount, @GetLoroAccount, @LoroAccount, @NostroAccount, @Asset_ShortName, @Asset_ShortName, cast(@CommissionID as float), @CommissionName)
        if @Action <> 'Cancel'
           and @Ibcot_ID is not null
           and @Ibcot_CheckSum = @Block_CheckSum
           or @Action = 'Cancel'
           and @Ibcot_ID is null
            begin
                select @msg = '304. Nothing to do: BlockCommission PC_Const = ' + isnull(ltrim(str(@PC_Const)), 'null') + ' is already ' + iif(@Action = 'Cancel', 'deleted', 'inserted') + ' for Trade_SID = ' + isnull(ltrim(str(@Trade_SID)), 'null')
                return
        end
        if @Action <> 'Cancel'
           and @Ibcot_ID is not null
           and @Ibcot_CheckSum <> @Block_CheckSum
           or @Action = 'Cancel'
            begin
                select @RowID = null
                     , @ET_Const = 8
                while @RowID is null
                    begin
                        exec QORT_TDB_PROD..P_GenFloatValue @RowID output
                                                          , 'importblockcommissionontrades_table'
        end
                insert into QORT_TDB_PROD.dbo.ImportBlockCommissionOnTrades ( id
                                                                            , PC_Const
                                                                            , AccrualDate
                                                                            , AccrualTime
                                                                            , Trade_SystemID
                                                                            , Size
                                                                            , Calc_Value
                                                                            , GetAccountExportCode
                                                                            , GetSubAccCode
                                                                            , SubAccCode
                                                                            , AccountExportCode
                                                                            , IsProcessed
                                                                            , ET_Const
                                                                            , Calc_Currency_ShortName
                                                                            , Currency_ShortName
                                                                            , Commission_SID
                                                                            , CommissionName
                                                                            , BackID
                                                                            , IsExecByComm ) 
                select @RowID
                     , PC_Const
                     , AccrualDate
                     , AccrualTime
                     , Trade_SystemID
                     , Size
                     , Calc_Value
                     , GetAccountExportCode
                     , GetSubAccCode
                     , SubAccCode
                     , AccountExportCode
                     , 1
                     , @ET_Const
                     , Calc_Currency_ShortName
                     , Currency_ShortName
                     , Commission_SID
                     , CommissionName
                     , BackID
                     , 'Y'
                  from QORT_TDB_PROD..ImportBlockCommissionOnTrades ibcot with(nolock)
                 where ibcot.ID = @Ibcot_ID
                if @@ROWCOUNT > 0
                    exec QORT_DDM..DDM_ImportExecutionCommands @TC_Const = @TC_Const
                                                             , @Oper_ID = @RowID
                                                             , @Comment = @BackID
                                                             , @SystemName = 'DDM_InsertTradeBlock'
        end
        select @RowID = null
             , @ET_Const = 2
        if @Action <> 'Cancel'
            begin
                while @RowID is null
                    begin
                        exec QORT_TDB_PROD..P_GenFloatValue @RowID output
                                                          , 'importblockcommissionontrades_table'
        end
                insert into QORT_TDB_PROD.dbo.ImportBlockCommissionOnTrades ( id
                                                                            , PC_Const
                                                                            , AccrualDate
                                                                            , AccrualTime
                                                                            , Trade_SystemID
                                                                            , Size
                                                                            , Calc_Value
                                                                            , GetAccountExportCode
                                                                            , GetSubAccCode
                                                                            , SubAccCode
                                                                            , AccountExportCode
                                                                            , IsProcessed
                                                                            , ET_Const
                                                                            , Calc_Currency_ShortName
                                                                            , Currency_ShortName
                                                                            , Commission_SID
                                                                            , CommissionName
                                                                            , BackID
                                                                            , IsExecByComm ) 
                values(
                       @RowID, @PC_Const, @AccrualDateInt, @AccrualTime, @Trade_SID, @Amount, abs(@Amount), @GetNostroAccount, @GetLoroAccount, @LoroAccount, @NostroAccount, 1, @ET_Const, @Asset_ShortName, @Asset_ShortName, @CommissionID, @CommissionName, @BackID, 'Y');
                if @@ROWCOUNT > 0
                    exec QORT_DDM..DDM_ImportExecutionCommands @TC_Const = @TC_Const
                                                             , @Oper_ID = @RowID
                                                             , @Comment = @BackID
                                                             , @SystemName = 'DDM_InsertTradeBlock'
        end
        select @msg = '000. BlockCommission PC_Const = ' + isnull(ltrim(str(@PC_Const)), 'null') + ' was ' + iif(@Action = 'Cancel', 'deleted', 'inserted') + ' for Trade_SID = ' + isnull(ltrim(str(@Trade_SID)), 'null')
        return
    end
---------------------------------------------
