CREATE procedure [dbo].[DDM_Add_TransfersToCache] ( 
                 @transferid    int
               , @tradeid       int
               , @status        varchar(100)
               , @transfer_type varchar(50)
               , @put_account   varchar(2000) = null
               , @pay_account   varchar(2000) = null
               , @Trade_SID     int null ) 
as
    begin
        set nocount on
        declare 
               @timestamp float= convert(float, FORMAT(getdate(), 'yyyyMMddHHmmss'))
             , @repo_leg      int          = 1
             , @delivery_type varchar(100) = 'DFP'
        if @Trade_SID is null
            select @Trade_SID = last_value(coalesce(nullif(it.SystemID, -1), nullif(it.Modified_System_ID, -1))) over(partition by it.TradeNum
                   order by it.id)
              from QORT_TDB_PROD..ImportTrades it with(nolock)
              inner join QORT_TDB_PROD..Trades t with(nolock) on t.TradeNum = it.TradeNum
                                                                 and t.SystemID = coalesce(nullif(it.SystemID, -1), nullif(it.Modified_System_ID, -1))
                                                                 and t.NullStatus = 'n'
             where coalesce(nullif(it.SystemID, -1), nullif(it.Modified_System_ID, -1)) is not null
                   and it.TradeNum = @tradeid
                   and it.IsProcessed < 4
        select @repo_leg = 1+isnull(charindex('y', IsRepo2), 0)
             , @tradeid = TradeNum
          from QORT_DB_PROD..Trades with(nolock)
         where id = @Trade_SID
		/* Проверить, если есть - отменить внешние этапы */
		declare @msg nvarchar(4000), @ExternalID varchar(255)
		set @ExternalID = cast(@tradeid as varchar)
		if @put_account is not null
		begin
	    set @ExternalID=concat(@ExternalID,'/27')
		if exists (select 1 from QORT_DB_PROD.dbo.Phases p with(nolock) where p.Trade_ID=@Trade_SID and p.PC_Const=27 and p.IsCanceled='n')
		exec qort_ddm.[dbo].[DDM_PhaseCancel] @ExternalID=@ExternalID, @Trade_SID=@Trade_SID, @msg = @msg out
		end
		if @pay_account is not null
		begin
	    set @ExternalID=concat(@ExternalID,'/26')
		if exists (select 1 from QORT_DB_PROD.dbo.Phases p with(nolock) where p.Trade_ID=@Trade_SID and p.PC_Const=26 and p.IsCanceled='n')
		exec qort_ddm.[dbo].[DDM_PhaseCancel] @ExternalID=@ExternalID, @Trade_SID=@Trade_SID, @msg = @msg out
		end
		/* */
        begin
            update QORT_CACHE_DB..trade_transfers with(rowlock, updlock)
            set transferid = @transferid
              , status = @status
              , put_account = isnull(@put_account,put_account)
              , pay_account = isnull(@pay_account,pay_account)
              , timestamp = @timestamp
              , trade_sid = @Trade_SID
             where tradeid = @tradeid
                   and delivery_type = @delivery_type
                   and transfer_type = @transfer_type
                   and repo_leg = @repo_leg
            if @@ROWCOUNT = 0
                begin
                    insert into QORT_CACHE_DB..trade_transfers ( transferid
                                                               , tradeid
                                                               , status
                                                               , delivery_type
                                                               , transfer_type
                                                               , put_account
                                                               , pay_account
                                                               , timestamp
                                                               , trade_sid
                                                               , repo_leg ) 
                    values ( @transferid
                           , @tradeid
                           , @status
                           , @delivery_type
                           , @transfer_type
                           , @put_account
                           , @pay_account
                           , @timestamp
                           , @trade_sid
                           , @repo_leg ) 
                end
        end
    end
