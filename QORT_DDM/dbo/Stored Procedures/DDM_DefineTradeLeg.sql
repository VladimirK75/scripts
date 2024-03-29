CREATE   procedure [dbo].[DDM_DefineTradeLeg] 
                          @Trade_SID    numeric(18, 0)
                        , @Asset        varchar(50) /* Currency or GRDB ID from DDM*/
						, @Direction    int /* NOSTRO Settlement direction (should be reversed for LORO)*/
						, @ChargeType   varchar(50) null /* Charge type */
						, @TradeLeg_SID numeric(18, 0) output
                        , @msg          nvarchar(4000) output
as
    begin
        declare 
               @SubaccOwner       varchar(50)
             , @AssetShortName    varchar(50)
             , @PayAssetShortName varchar(50)
             , @TradeDirection    int
             , @TT_Const          smallint
        select @msg = '000. Ok'
        select @TT_Const = TT_Const
             , @AssetShortName = AssetShortName
             , @PayAssetShortName = CurrPayAsset_ShortName
             , @TradeDirection = 3 - 2 * BuySell
          from QORT_TDB_PROD..Trades with (nolock)
          where SystemID = @Trade_SID
/*select 'Define Trade Leg', @TT_Const,@AssetShortName,@PayAssetShortName,@TradeDirection
select 'Define Trade Leg In', @Asset,@Direction*/
        if @TT_Const not in(3, 6, 12, 13, 14) /* NOT REPO or SWAP*/
            begin
                select @TradeLeg_SID = @Trade_SID
                return
            end
        if @TT_Const = 12
           and @Asset = @AssetShortName /* Поставка SWAP*/
            begin
                if @Direction = @TradeDirection /* Направление сделки совпадает с направлением движения предмета сделки*/
                    select @TradeLeg_SID = @Trade_SID
                     else
                select @TradeLeg_SID = RepoTrade_SystemID
                  from QORT_TDB_PROD..Trades with (nolock)
                  where SystemID = @Trade_SID
                        and TT_Const in (3, 6, 12, 13, 14)
                if isnull(@TradeLeg_SID, 0) = 0
                    select @msg = 'BackID for TradeSID = '+convert(varchar(20), @Trade_SID)+' not found.'
                return
            end
        if @Asset = @PayAssetShortName /* Оплата*/
            begin
                if isnull(@ChargeType,'') != 'INTEREST' /* INTEREST - всегда ко второй ноге */
				and  @Direction <> @TradeDirection /* Направление сделки противоположно направлению оплаты*/
                    select @TradeLeg_SID = @Trade_SID
                     else
                select @TradeLeg_SID = RepoTrade_SystemID
                  from QORT_TDB_PROD..Trades with (nolock)
                  where SystemID = @Trade_SID
                        and TT_Const in (3, 6, 12, 13, 14)
                if isnull(@TradeLeg_SID, 0) = 0
                    select @msg = 'BackID for TradeSID = '+convert(varchar(20), @Trade_SID)+' not found.'
                return
            end
        if @TT_Const in(3, 6, 13, 14)
           and exists (select 1
                         from QORT_DB_PROD..Assets a with (nolock)
                         where a.ShortName = @AssetShortName
                               and a.Marking = @Asset )  /* Поставка инструмента*/
            begin
                if @Direction = @TradeDirection /* Направление сделки совпадает с направлением движения предмета сделки*/
                    select @TradeLeg_SID = @Trade_SID
                     else
                select @TradeLeg_SID = RepoTrade_SystemID
                  from QORT_TDB_PROD..Trades with (nolock)
                  where SystemID = @Trade_SID
                        and TT_Const in (3, 6, 12, 13, 14)
                if isnull(@TradeLeg_SID, 0) = 0
                    select @msg = 'BackID for TradeSID = '+convert(varchar(20), @Trade_SID)+' not found.'
                return
            end
        select @msg = 'Asset '+@Asset+' not found on Trade Parameters @Trade_SID = '+convert(varchar(20), @Trade_SID)
        return
    end
