CREATE   procedure [dbo].[DDM_UpdateTradeAccounts] 
                 @Trade_SID         bigint
               , @ExternalReference varchar(255)
               , @ExternalTradeID   varchar(255)
               , @PutAccount        varchar(50)    = null
               , @PayAccount        varchar(50)    = null
               , @Currency          varchar(20)    = null
               , @msg               nvarchar(4000) output
as
    begin
        declare 
               @TT_Const       int
             , @Asset          varchar(50)
             , @PC_Const       int
             , @QFlags         bigint      = 0
             , @Import_ID      bigint /* for non imported rows */
             , @RowID          bigint
             , @IEC_ID         float
             , @TSSection_Name varchar(32)
             , @SubAcc_Code    varchar(32)
             , @Security_Code  varchar(64)
        if isnull(@Trade_SID, 0) <= 0
            begin
                select @msg = '404. Trade_SID is empty for TradeGID='+@ExternalReference+' TradeNum='+@ExternalTradeID
                return
            end
        select @msg = '500. Internal Server Error'
        /* get null objects */
        /* get last pending import row */
        select @Import_id = max(id)
          from QORT_TDB_PROD..ImportTrades it with(nolock)
         where it.SystemID = @Trade_SID
               and it.IsProcessed < 3
        /* set undefined and unprocessed accounts */
        if isnull(@PutAccount, '') = ''
            select @PutAccount = tt.put_account
              from QORT_CACHE_DB..trade_transfers tt with(nolock)
             where tt.tradeid = cast(@ExternalTradeID as int)
			   and tt.put_account is not null
        if isnull(@PutAccount, '') = ''
            select @PutAccount = PutAccount_ExportCode
              from QORT_TDB_PROD..ImportTrades it with(nolock)
             where id = @Import_ID
                   and PutAccount_ExportCode is not null
        if isnull(@PutAccount, '') = ''
            select @PutAccount = PutAccount_ExportCode
              from QORT_TDB_PROD..Trades with(nolock)
             where SystemID = @Trade_SID
                   and PutAccount_ExportCode is not null
        if isnull(@PayAccount, '') = ''
            select @PayAccount = tt.pay_account
              from QORT_CACHE_DB..trade_transfers tt with(nolock)
             where tt.tradeid = cast(@ExternalTradeID as int)
			   and tt.pay_account is not null
        if isnull(@PayAccount, '') = ''
            select @PayAccount = PayAccount_ExportCode
              from QORT_TDB_PROD..ImportTrades it with(nolock)
             where id = @Import_ID
                   and PayAccount_ExportCode is not null
        if isnull(@PayAccount, '') = ''
            select @PayAccount = PayAccount_ExportCode
              from QORT_TDB_PROD..Trades with(nolock)
             where SystemID = @Trade_SID
                   and PayAccount_ExportCode is not null
        /* set defined objects */
        select @TT_Const = t.TT_Const
             , @Asset = case
                             when t.TT_Const in(8, 12) then Asset_Name
                           else ''
                        end
          from QORT_TDB_PROD..Trades t with(nolock)
         where t.SystemID = @Trade_SID
        if @TT_Const in(8, 12)
           and @Asset = @Currency
           and isnull(@PayAccount, '') <> ''
            begin
                select @PutAccount = @PayAccount
                set @PayAccount = null
            end
        if not exists (select 1
                         from QORT_TDB_PROD..Trades with(nolock)
                        where SystemID = @Trade_SID
                              and isnull(@PutAccount, PutAccount_ExportCode) = PutAccount_ExportCode
                              and isnull(@PayAccount, PayAccount_ExportCode) = PayAccount_ExportCode) 
            begin
                 set @QFlags = 557056 /* QF_REVIVE Признак восстановления этапов	*/
				--set @QFlags = 524288 /* QF_REVIVE_BROKCOMM	Признак восстановления этапов	*/
                /* set @Qflags from QORT_DB_PROD..Trades */
                select @QFlags = t.Qflags
                     , @TSSection_Name = ts.Name
                     , @SubAcc_Code = s.SubaccCode
                     , @Security_Code = sec.SecCode
                  from QORT_DB_PROD..Trades t with(nolock)
                  inner join QORT_DB_PROD..TSSections ts with(nolock) on t.TSSection_ID = ts.ID
                  inner join QORT_DB_PROD..Subaccs s with(nolock) on t.SubAcc_ID = s.id
                  inner join QORT_DB_PROD..Securities sec with(nolock) on Security_ID = sec.id
                 where t.id = @Trade_SID
				set @QFlags = (@QFlags|557056)
                /* try to update unprocessed rows */
                /* START - generate the new ID for this trade */
                exec QORT_TDB_PROD.dbo.P_GenFloatValue @RowID output
                                                     , 'importtrades_table'
                insert into QORT_TDB_PROD..ImportTrades ( id
                                                        , TradeNum
                                                        , AgreeNum
                                                        , SystemID
                                                        , TradeDate
                                                        , PutAccount_ExportCode
                                                        , PayAccount_ExportCode
                                                        , ET_Const
                                                        , QFlags
                                                        , TT_Const
                                                        , TSSection_Name
                                                        , SubAcc_Code
                                                        , Qty
                                                        , BuySell
                                                        , Security_Code
                                                        , TradeTime
                                                        , InfoSource
                                                        , IsProcessed
                                                        , IsExecByComm ) 
                select @RowID
                     , t.TradeNum
                     , t.AgreeNum
                     , @Trade_SID
                     , t.TradeDate
                     , @PutAccount
                     , @PayAccount
                     , 4
                     , @QFlags
                     , t.TT_Const
                     , @TSSection_Name
                     , @SubAcc_Code
                     , t.Qty
                     , t.BuySell
                     , @Security_Code
                     , t.TradeTime
                     , t.InfoSource
                     , 1
                     , 'Y'
                  from QORT_DB_PROD..Trades t with(nolock)
                 where t.id = @Trade_SID
                if @@ROWCOUNT > 0
                    begin
                        select @msg = '000. Update Trade System ID = '+ltrim(str(@Trade_SID))
                        exec QORT_DDM..DDM_ImportExecutionCommands @TC_Const = 1
                                                                 , @Oper_ID = @RowID
                                                                 , @Comment = @Trade_SID
                                                                 , @SystemName = 'DDM_UpdateTradeAccounts'
                    end
			/* Мы ждём, пока поручение создаётся или 30 секунд */
			declare 
				   @TimeDelay   int      = 30
				 , @TimeStart   datetime = getdate()
				 , @IsProcessed bit      = 0
			while @IsProcessed = 0
				  and datediff(ss, @TimeStart, getdate()) < @TimeDelay
				begin
					if exists (select 1
								 from QORT_TDB_PROD.dbo.ImportTrades it with(nolock)
								where it.ID = @RowID
									  and it.IsProcessed > 2) 
						set @IsProcessed = 1
				end
			/* */
            end
           else
            select @msg = '304. Nothing to update Trade_SID = '+ltrim(str(@Trade_SID))
        return
    end
