CREATE procedure [dbo].[DDM_TradeAddSettlement] 
                @SettlementDetailID bigint
              , @TradeSource        varchar(25)
              , @ExternalID         varchar(255)
              , @Trade_SID          numeric(18, 0)
              , @MovType            varchar(8)
              , @SettlementDate     datetime
              , @Amount             decimal(38, 14)
              , @Asset              varchar(20)
              , @Direction          smallint
              , @LoroAccount        varchar(6)      = null
              , @NostroAccount      varchar(50)
              , @LegalEntity        varchar(6)
              , @Infosource         varchar(64)
              , @ChargeType         varchar(50)     = null
              , @NetSettlementID    varchar(32)     = null
              , @CommissionName     varchar(255)    = null
              , @msg                nvarchar(4000) output
as
    begin
        declare 
               @TradeAmount  money       = 0
             , @TradeQty     float       = 0
             , @PayCurrency  varchar(3)
             , @PutCurrency  varchar(3)
             , @PayDirection smallint
             , @TT_Const     smallint
             , @PC_Const     smallint
             , @BackID       varchar(64)
        select @msg = '500. DDM_TradeAddSettlement need to investigate'
             , @Asset = replace(@Asset, 'RUB', 'RUR')
        select @TT_Const = t.TT_Const
             , @PayCurrency = t.CurrPayAsset_ShortName
             , @PutCurrency = t.Asset_Name
             , @TradeQty = t.Qty
             , @TradeAmount = t.Volume1 + iif(t.IsAccrued <> 'y', t.Accruedint, 0)
             , @PayDirection = 2 * t.BuySell - 3
          from QORT_TDB_PROD..Trades t with(nolock)
         where t.SystemID = @Trade_SID
        if @MovType = 'CASH'
           and @PayDirection <> @Direction
		   and @PayCurrency=@Asset
            begin
                set @Amount = -1 * @Amount /* Костыль для учета комиссий в сторону противоположную сделке */
                set @Direction = -1 * @Direction /* Костыль для учета комиссий в сторону противоположную сделке */
        end
        select @TradeAmount = @TradeAmount - iif(@MovType = 'CASH', p.QtyBefore * p.QtyAfter * isnull(sign(2 * p.BuySell - 3), @PayDirection), 0)
             , @TradeQty = @TradeQty - iif(@MovType = 'SECURITY', p.QtyBefore, 0)
          from QORT_TDB_PROD..Phases p with(nolock)
         where 1 = 1
               and p.BackID not in (@ExternalID + '/5', @ExternalID + '/7', @ExternalID + '/3', @ExternalID + '/4')
               and p.Trade_SID = @Trade_SID
               and p.PhaseAsset_ShortName = @Asset
               and p.IsProcessed < 4
               and p.PC_Const in (3, 4, 5, 7)
               and isnull(p.IsCanceled, 'n') = 'n'
        select @PC_Const = case
                                when @MovType = 'CASH' then case
                                                                 when @Asset = @PayCurrency then iif(@TradeAmount = @PayDirection * cast(@Amount * @Direction as money), 7, 5)
                                                                 when @Asset = @PutCurrency then iif(@TradeQty = abs(cast(@Amount as money)), 4, 3)
                                                               else 0
                                                            end
                              else iif(@TradeQty = abs(cast(@Amount as money)), 4, 3)
                           end
        select @BackID = concat(@ExternalID, '/', @PC_Const)
        exec QORT_DDM..DDM_InsertTradePhases @PC_Const = @PC_Const
                                           , @Trade_SID = @Trade_SID
                                           , @BackID = @BackID
                                           , @Infosource = @Infosource
                                           , @SettlementDate = @SettlementDate
                                           , @LegalEntity = @LegalEntity
                                           , @LoroAccount = @LoroAccount
                                           , @NostroAccount = @NostroAccount
                                           , @Issue = @Asset
                                           , @Amount = @Amount
                                           , @Direction = @Direction
                                           , @ChargeType = @ChargeType
                                           , @NetSettlementID = @NetSettlementID
                                           , @msg = @msg output
        return
    end
