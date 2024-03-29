create   procedure dbo.DDM_SettleCorrectPosition 
                 @SettlementDetailID bigint
               , @MovementID         bigint
               , @MovementID2        bigint         = null
               , @msg                nvarchar(4000) output
as
    begin
        set nocount on
        begin try
            declare 
                   @BackID            varchar(100)
                 , @SettlementID      bigint
                 , @RuleID            bigint
                 , @SettledOnly       bit
                 , @STLRuleID         bigint
                 , @CT_Const          tinyint
                 , @CL_Const          tinyint
                 , @TransactionID     bigint
                 , @ExternalID        varchar(255)
                 , @Version           tinyint
                 , @Direction         smallint
                 , @SettlementDate    datetime
                 , @SettlementDateInt int
                 , @AccruedCoupon     decimal(38, 14)
                 , @SettledAccCoupon  decimal(38, 14)
                 , @Amount            decimal(38, 14)
                 , @SettledAmount     decimal(38, 14)
                 , @UnSettledAmount   decimal(38, 14)
                 , @Size              decimal(38, 14)
                 , @SystemID          bigint
                 , @StlExternalID     varchar(255)
                 , @ReversedID        bigint
                 , @StlType           varchar(6)
                 , @StlDateType       varchar(50)
                 , @SettlementFeature varchar(255)
            select @msg = '000. Ok'
            select @SettlementID = sd.SettlementID
                 , @SettledAccCoupon = round(sd.AccruedCoupon, 2)
                 , @SettledAmount = round(isnull(sd.Amount, sd.Qty), 2)
                 , @Direction = iif(sd.Type = 'Loro', -1, 1)*sd.Direction
                 , @StlType = sd.Type
                 , @ReversedID = isnull(s.ReversedID, 0)
                 , @StlExternalID = s.ExternalID
              from QORT_DDM..ImportedTranSettlementDetails sd with(nolock)
              inner join QORT_DDM..ImportedTranSettlement s with(nolock) on sd.SettlementID = s.ID
             where sd.ID = @SettlementDetailID
            /* BackID всегда начинается с ExternalID транзакции и MovementID. Для каждого Settlement к BackID добавляется ExternalID Settlement. Если корректировка исполнилась одним Settlement объектом сразу на всю сумму, ссылка на Settlement у нее будет только в комментарии и Infosource */
            select @BackID = ct.ExternalID+'/'+ltrim(str(@MovementID, 16))
                 , @RuleID = dr.RuleID
                 , @CT_Const = isnull(dr.CT_Const, 0)
                 , @CL_Const = isnull(dr.CL_Const, 0)
                 , @SettledOnly = dr.SettledOnly
                 , @STLRuleID = dr.STLRuleID
                 , @TransactionID = mv.TransactionID
                 , @ExternalID = ct.ExternalID
                 , @AccruedCoupon = mv.Direction * round(mv.AccruedCoupon, 2)
                 , @Amount = mv.Direction * round(isnull(mv.Amount, mv.Qty), 2)
                 , @StlDateType = sr.SettlementDate
                 , @SettlementFeature = sr.Feature
              from QORT_DDM..ImportTransactions_Rules dr with(nolock)
                 , QORT_DDM..SettlementRules sr with(nolock)
                 , QORT_DDM..Movements mv with(nolock)
                 , QORT_DDM..CommonTransaction ct with(nolock)
             where mv.ID = @MovementID
                   and mv.TransactionID = ct.ID
                   and dr.OperationType = ct.OperationType
                   and dr.MovType = mv.MovType
                   and coalesce(dr.ChargeType, mv.ChargeType, '') = isnull(mv.ChargeType, '')
                   and isnull(mv.LoroAccount, ct.LegalEntity) like coalesce(dr.LoroAccount, mv.LoroAccount, ct.LegalEntity)
                   and dr.IsSynchronized = 1
                   and dr.StartDate <= getdate()
                   and isnull(dr.EndDate, '20501231') > getdate()
                   and isnull(dr.Direction, mv.Direction) = mv.Direction
                   and dr.STLRuleID = sr.STLRuleID
                   and sr.Capacity = @StlType
            if isnull(@RuleID, 0) = 0
                begin
                    select @msg = '001. No settlement rules for SettlementDetailID = '+ltrim(str(@SettlementDetailID, 16))+'. MovementID = '+ltrim(str(@MovementID, 16))
                    return
                end
            select @SettlementDate = case @StlDateType
                                          when 'FOAvaliableDate' then st.FOAvaliableDate
                                          when 'ActualSettlementDate' then st.ActualSettlementDate
                                          when 'AvaliableDate' then st.AvaliableDate
                                     end
              from QORT_DDM..ImportedTranSettlement st with(nolock)
             where ID = @SettlementID
            select @SettlementDateInt = convert(int, FORMAT(@SettlementDate, 'yyyyMMdd'))
            if @SettledOnly = 1
               and isnull(@SettlementDateInt, 0) = 0
                begin
                    select @msg = '001. No Settlement Date. Settlement do not applied by SettlementRules. RuleID = '+ltrim(str(@RuleID, 16))
                    return
                end
/********************************************************************************************************************************
	 	Проверяем условие на разрыв переводов(TransferGap)
	*********************************************************************************************************************************/
            if isnull(@MovementID2, 0) > 0
               and @SettlementFeature = 'TransferGap'
                begin
                    declare 
                           @SettlementDate2    datetime
                         , @SettlementDate2Int int
                         , @SettlementID2      bigint
                    select @SettlementID2 = first_value(sd.SettlementID) over(partition by sd.MovementID
                                                                                         , sd.Type
                           order by s.EventDateTime desc)
                         , @SettlementDate2 = case @StlDateType
                                                   when 'FOAvaliableDate' then first_value(s.FOAvaliableDate) over(partition by sd.MovementID
                                                                                                                              , sd.Type
                                              order by s.EventDateTime desc)
                                                   when 'ActualSettlementDate' then first_value(s.ActualSettlementDate) over(partition by sd.MovementID
                                                                                                                                        , sd.Type
                                              order by s.EventDateTime desc)
                                                   when 'AvaliableDate' then first_value(s.AvaliableDate) over(partition by sd.MovementID
                                                                                                                          , sd.Type
                                              order by s.EventDateTime desc)
                                              end
                      from QORT_DDM..ImportedTranSettlementDetails sd with(nolock)
                      inner join QORT_DDM..ImportedTranSettlement s with(nolock) on sd.SettlementID = s.ID
                     where sd.MovementID = @MovementID2
                           and sd.Type = @StlType
                    select @SettlementDate2Int = convert(int, format(@SettlementDate2, 'yyyyMMdd'))
                    if isnull(@SettlementDateInt, 0) <> isnull(@SettlementDate2Int, 0)
                        select @MovementID2 = 0
                end
            /**************************/
/********************************************************************************************************************************
	 	Ищем сумму остатка, на который необходимо исполнить транзакцию <<< требует пересмотра
	*********************************************************************************************************************************/
            select @UnSettledAmount = round(isnull(@Amount, 0), 2) - @Direction * abs(isnull(sum(sd.Qty), 0) + isnull(sum(sd.Amount), 0))
              from QORT_DDM..ImportedTranSettlementDetails sd with(nolock)
              inner join QORT_DDM..ImportedTranSettlement s with(nolock) on s.ID = sd.SettlementID
             where sd.MovementID = @MovementID
                   and sd.Type = @StlType
                   and case @StlDateType
                            when 'FOAvaliableDate' then s.FOAvaliableDate
                            when 'ActualSettlementDate' then s.ActualSettlementDate
                            when 'AvaliableDate' then s.AvaliableDate
                       end is not null
                   and s.ExternalID <> @StlExternalID
                   and s.ProcessingState = 'Processed'
                   and sd.ProcessingState = 'Created'
/********************************************************************************************************************************
	 	Проверяем полный Settlement или частичный
	*********************************************************************************************************************************/
            if abs(isnull(@SettledAmount, 0)) = abs(isnull(@UnSettledAmount, 0))
                begin
                    /* Если Settlement полный, просто отменяем неисполненную и процессим новую с BackID + Settlement */
                    exec QORT_DDM..DDM_MovementCancel @MovementID = @MovementID
                                                    , @msg = @msg out
                    exec QORT_DDM..DDM_InsertCorrectPosition @RuleID = @RuleID
                                                           , @MovementID = @MovementID
                                                           , @MovementID2 = @MovementID2
                                                           , @SettlementDetailID = @SettlementDetailID
                                                           , @msg = @msg out
                    if left(@msg, 3) <> '000'
                        return
                end
               else
                begin
/********************************************************************************************************************************
	 	Если Settlement частичный, нужно отменить всю неисполненную часть и создать две корректировки - 
	 	исполненная на сумму Settlement и неисполненную на остаток
	*********************************************************************************************************************************/
                    if abs(isnull(@SettledAmount, 0)) > abs(isnull(@UnSettledAmount, 0))
                        begin
                            select @msg = '006. Settlement is more than trade. SettlementDetailID = '+ltrim(str(@SettlementDetailID, 16))+'; @SettledAmount = '+cast(@SettledAmount as varchar(100))+'; @UnSettledAmount = '+cast(@UnSettledAmount as varchar(100))
                            return
                        end
                    select @Size = @SettledAmount * @Direction
                    if isnull(@Size, 0) = 0
                        begin
                            select @msg = '005. No settlement amount. SettlementDetailID = '+ltrim(str(@SettlementDetailID, 16))
                            return
                        end
                    /* Создаем корректировку на засетленый объем */
                    exec QORT_DDM..DDM_InsertCorrectPosition @RuleID = @RuleID
                                                           , @MovementID = @MovementID
                                                           , @MovementID2 = @MovementID2
                                                           , @SettlementDetailID = @SettlementDetailID
                                                           , @msg = @msg out
                    if left(@msg, 3) <> '000'
                        return
                    /* Убиваем незасетленую корректировку */
                    if abs(isnull(@UnSettledAmount, 0)) > 0
                        begin
                            select @Size = round(@UnSettledAmount - @SettledAmount * @Direction, 2)
                            select @AccruedCoupon = round(@AccruedCoupon - @SettledAccCoupon, 2)
                            exec QORT_DDM.dbo.DDM_MovementCancel @MovementID = @MovementID
                                                               , @UnSettledOnly = 1
                                                               , @msg = @msg out
                            /* Вставляем новую незасетленную корректировку на остаток по MovementID*/
                            if abs(isnull(@Size, 0)) > 0
                                exec QORT_DDM.dbo.DDM_InsertCorrectPosition @RuleID = @RuleID
                                                                          , @MovementID = @MovementID
                                                                          , @MovementID2 = @MovementID2
                                                                          , @Size = @Size
                                                                          , @AccruedCoupon = @AccruedCoupon
                                                                          , @msg = @msg out
                        end
                end
            return
        end try
        begin catch
            select @msg = error_message()
            return
        end catch
    end
