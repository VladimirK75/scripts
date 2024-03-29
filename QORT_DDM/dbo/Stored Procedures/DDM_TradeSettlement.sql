CREATE   procedure dbo.DDM_TradeSettlement 
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
               , @msg                nvarchar(4000) output
as
    begin
        declare 
               @BackID        varchar(64)
             , @PC_Const      int
             , @TT_Const      int
             , @SettledAmount decimal(38, 14)  = 0
             , @TradeAmount   decimal(38, 14)  = 0
             , @TradeQty      decimal(38, 14)  = 0
             , @PayCurrency   varchar(3)
             , @PutCurrency   varchar(3)
             , @PayDirection  smallint
        select @msg = '000. Ok'
        if @Asset = 'RUB'
            set @Asset = 'RUR'
        /***********PC_Const definition***************/
        if @MovType = 'SECURITY' /* Только поставка */
            begin
                select @TradeAmount = t.Qty
                  from QORT_TDB_PROD..Trades t with(nolock)
                 where t.SystemID = @Trade_SID
                if @TradeSource = 'QORT'
                    select @SettledAmount = isnull(sum(sd.Direction * (isnull(sd.Qty, 0) + isnull(sd.Amount, 0))), 0)
                      from QORT_DDM..ImportedTradeSettlementDetails scd with(nolock)
                      inner join QORT_DDM..ExportedTradeSettlement sc with(nolock) on scd.SettlementID = sc.ID
                      inner join QORT_DDM..ExportedTradeSettlement s with(nolock) on s.TradeGID = sc.TradeGID
                                                                                     and s.ExternalTradeID = sc.ExternalTradeID
                                                                                     and s.ExternalID <> @ExternalID
                      inner join QORT_DDM..ExportedTradeSettlementDetails sd with(nolock) on sd.SettlementID = s.ID
                     where scd.id = @SettlementDetailID
                           and s.ProcessingState = 'Processed'
                           and sd.ProcessingState = 'Created'
                           and (sd.ProcessingMessage like '%'+s.ExternalID+'/3%'+convert(varchar(20), @Trade_SID)
                                or sd.ProcessingMessage like '%'+s.ExternalID+'/4%'+convert(varchar(20), @Trade_SID))
                   else
                    select @SettledAmount = isnull(sum(sd.Direction * (isnull(sd.Qty, 0) + isnull(sd.Amount, 0))), 0)
                      from QORT_DDM..ImportedTradeSettlementDetails scd with(nolock)
                      inner join QORT_DDM..ImportedTradeSettlement sc with(nolock) on scd.SettlementID = sc.ID
                      inner join QORT_DDM..ImportedTradeSettlement s with(nolock) on s.TradeGID = sc.TradeGID
                                                                                     and s.ExternalTradeID = sc.ExternalTradeID
                                                                                     and s.ExternalID <> @ExternalID
                      inner join QORT_DDM..ImportedTradeSettlementDetails sd with(nolock) on sd.SettlementID = s.ID
                     where scd.id = @SettlementDetailID
                           and s.ProcessingState = 'Processed'
                           and sd.ProcessingState = 'Created'
                           and (sd.ProcessingMessage like '%'+s.ExternalID+'/3%'+convert(varchar(20), @Trade_SID)
                                or sd.ProcessingMessage like '%'+s.ExternalID+'/4%'+convert(varchar(20), @Trade_SID))
                if round(@TradeAmount, 0) = abs(round(@SettledAmount, 0) + round(@Amount * @Direction, 0))
                    set @PC_Const = 4 /* Полная поставка */
                   else
                    if round(@TradeAmount, 0) > abs(round(@SettledAmount, 0) + round(@Amount * @Direction, 0))
                        set @PC_Const = 3 /* Частичная поставка */
                       else
                        begin
                            select @msg = '001. Total Settlement Amount more than Trade Amount. Trade_SID = '+convert(varchar(20), @Trade_SID)+'; TradeQty = '+isnull(convert(varchar(100), @TradeAmount), 0)+'; SettledQty = '+isnull(convert(varchar(100), @SettledAmount), 0)
                            return
                        end
            end
           else /* Оплата или поставка для FX */
            begin
                select @TT_Const = t.TT_Const
                     , @PayCurrency = t.CurrPayAsset_ShortName
                     , @PutCurrency = case
                                           when t.TT_Const in(8, 12) then Asset_Name
                                         else ''
                                      end
                     , @TradeQty = t.Qty
                     , @TradeAmount = case
                                           when t.IsAccrued = 'y' then t.Volume1
                                         else t.Volume1 + t.Accruedint
                                      end
                     , @PayDirection = 2 * t.BuySell - 3
                  from QORT_TDB_PROD..Trades t with(nolock)
                 where t.SystemID = @Trade_SID
                if @Asset = @PayCurrency
                    begin
	    	/*SELECT @SettledAmount = sum(isnull(QtyBefore*QtyAfter, 0))
	    	  FROM QORT_DB_PROD..Phases p with (nolock)
	    	 WHERE p.Trade_ID = @Trade_SID    	
	    	   and PC_Const in (5,7) and IsCanceled = 'n'*/
                        if @TradeSource = 'QORT'
                            select @SettledAmount = isnull(sum(sd.Direction * (isnull(sd.Qty, 0) + isnull(sd.Amount, 0))), 0)
                              from QORT_DDM..ImportedTradeSettlementDetails scd with(nolock)
                              inner join QORT_DDM..ExportedTradeSettlement sc with(nolock) on scd.SettlementID = sc.ID
                              inner join QORT_DDM..ExportedTradeSettlement s with(nolock) on s.TradeGID = sc.TradeGID
                                                                                             and s.ExternalTradeID = sc.ExternalTradeID
                                                                                             and s.ExternalID <> @ExternalID
                              inner join QORT_DDM..ExportedTradeSettlementDetails sd with(nolock) on sd.SettlementID = s.ID
                             where scd.id = @SettlementDetailID
                                   and s.ProcessingState = 'Processed'
                                   and sd.ProcessingState = 'Created'
                                   and (sd.ProcessingMessage like '%'+s.ExternalID+'/5%'+convert(varchar(20), @Trade_SID)
                                        or sd.ProcessingMessage like '%'+s.ExternalID+'/7%'+convert(varchar(20), @Trade_SID))
                           else
                            select @SettledAmount = isnull(sum(sd.Direction * (isnull(sd.Qty, 0) + isnull(sd.Amount, 0))), 0)
                              from QORT_DDM..ImportedTradeSettlementDetails scd with(nolock)
                              inner join QORT_DDM..ImportedTradeSettlement sc with(nolock) on scd.SettlementID = sc.ID
                              inner join QORT_DDM..ImportedTradeSettlement s with(nolock) on s.TradeGID = sc.TradeGID
                                                                                             and s.ExternalTradeID = sc.ExternalTradeID
                                                                                             and s.ExternalID <> @ExternalID
                              inner join QORT_DDM..ImportedTradeSettlementDetails sd with(nolock) on sd.SettlementID = s.ID
                             where scd.id = @SettlementDetailID
                                   and s.ProcessingState = 'Processed'
                                   and sd.ProcessingState = 'Created'
                                   and (sd.ProcessingMessage like '%'+s.ExternalID+'/5%'+convert(varchar(20), @Trade_SID)
                                        or sd.ProcessingMessage like '%'+s.ExternalID+'/7%'+convert(varchar(20), @Trade_SID))
                                   and not exists (select 1
													 from QORT_DDM..ImportedTradeSettlement its with(nolock)
													 inner join QORT_DDM..ImportedTradeSettlementDetails itsd with(nolock) on itsd.SettlementID = its.id
																															  and itsd.ProcessingState = 'Created'
													where its.ExternalID = s.ExternalID
														  and s.ProcessingState = 'Processed'
														  and its.id > s.id)
                        if round(@TradeAmount, 2) = abs(round(isnull(@SettledAmount, 0), 2) + round(@Amount * @Direction, 2))
                            set @PC_Const = 7 /* Полная оплата */
                           else
                            set @PC_Const = 5 /* Частичная оплата */
                        if @PayDirection <> @Direction
                            set @Amount = -1 * @Amount /* Костыль для учета комиссий в сторону противоположную сделке */
							set @Direction = -1 * @Direction /* Костыль для учета комиссий в сторону противоположную сделке */
                    end
                   else
                    if @TT_Const in(8, 12)
                       and @Asset = @PutCurrency
                        begin
	    	/*SELECT @SettledAmount = isnull(sum(isnull(QtyBefore*QtyAfter, 0)),0)
	    	  FROM QORT_DB_PROD..Phases p with (nolock)
	    	 WHERE p.Trade_ID = @Trade_SID    	
	    	   and PC_Const in (3,4) and IsCanceled = 'n'*/
                            if @TradeSource = 'QORT'
                                select @SettledAmount = isnull(sum(sd.Direction * (isnull(sd.Qty, 0) + isnull(sd.Amount, 0))), 0)
                                  from QORT_DDM..ImportedTradeSettlementDetails scd with(nolock)
                                  inner join QORT_DDM..ExportedTradeSettlement sc with(nolock) on scd.SettlementID = sc.ID
                                  inner join QORT_DDM..ExportedTradeSettlement s with(nolock) on s.TradeGID = sc.TradeGID
                                                                                                 and s.ExternalTradeID = sc.ExternalTradeID
                                                                                                 and s.ExternalID <> @ExternalID
                                  inner join QORT_DDM..ExportedTradeSettlementDetails sd with(nolock) on sd.SettlementID = s.ID
                                 where scd.id = @SettlementDetailID
                                       and s.ProcessingState = 'Processed'
                                       and sd.ProcessingState = 'Created'
                                       and (sd.ProcessingMessage like '%'+s.ExternalID+'/3%'+convert(varchar(20), @Trade_SID)
                                            or sd.ProcessingMessage like '%'+s.ExternalID+'/4%'+convert(varchar(20), @Trade_SID))
                               else
                                select @SettledAmount = isnull(sum(sd.Direction * (isnull(sd.Qty, 0) + isnull(sd.Amount, 0))), 0)
                                  from QORT_DDM..ImportedTradeSettlementDetails scd with(nolock)
                                  inner join QORT_DDM..ImportedTradeSettlement sc with(nolock) on scd.SettlementID = sc.ID
                                  inner join QORT_DDM..ImportedTradeSettlement s with(nolock) on s.TradeGID = sc.TradeGID
                                                                                                 and s.ExternalTradeID = sc.ExternalTradeID
                                                                                                 and s.ExternalID <> @ExternalID
                                  inner join QORT_DDM..ImportedTradeSettlementDetails sd with(nolock) on sd.SettlementID = s.ID
                                 where scd.id = @SettlementDetailID
                                       and s.ProcessingState = 'Processed'
                                       and sd.ProcessingState = 'Created'
                                       and (sd.ProcessingMessage like '%'+s.ExternalID+'/3%'+convert(varchar(20), @Trade_SID)
                                            or sd.ProcessingMessage like '%'+s.ExternalID+'/4%'+convert(varchar(20), @Trade_SID))
                                   and not exists (select 1
													 from QORT_DDM..ImportedTradeSettlement its with(nolock)
													 inner join QORT_DDM..ImportedTradeSettlementDetails itsd with(nolock) on itsd.SettlementID = its.id
																															  and itsd.ProcessingState = 'Created'
													where its.ExternalID = s.ExternalID
														  and s.ProcessingState = 'Processed'
														  and its.id > s.id)
                            if round(@TradeQty, 2) = abs(round(@SettledAmount, 2) + round(@Amount * @Direction, 2))
                                set @PC_Const = 4 /* Полная поставка */
                               else
                                if round(@TradeQty, 2) > abs(round(@SettledAmount, 2) + round(@Amount * @Direction, 2))
                                    set @PC_Const = 3 /* Частичная поставка */
                                   else
                                    begin
                                        select @msg = '003. Total Settlement Amount more than Trade Amount. Trade_SID = '+convert(varchar(20), @Trade_SID)+'; TradeQty = '+isnull(convert(varchar(100), @TradeQty), 0)+'; SettledQty = '+isnull(convert(varchar(100), @SettledAmount), 0)
                                        return
                                    end
                        end
                       else
                        begin
                            select @msg = '004. Asset not found for Trade_SID = '+convert(varchar(20), @Trade_SID)+'; Asset = '+@Asset
                            return
                        end
            end
        /********************************************/
        select @BackID = @ExternalID+'/'+cast(@PC_Const as varchar(3))
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
                                           , @msg = @msg output
        return
    end
