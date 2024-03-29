create   procedure dbo.DDM_UnsettleCorrectPosition 
                 @SettlementDetailID bigint
               , @MovementID         bigint
               , @MovementID2        bigint         = null
               , @msg                nvarchar(4000) output
as
    begin
        set nocount on
        begin try
            declare 
                   @RuleID     bigint
                 , @BackID     varchar(100)
                 , @Infosource varchar(255)
                 , @MoveAmount decimal(38, 14)
                 , @CPAmount   decimal(38, 14)
                 , @Accrued    decimal(38, 14)
                 , @RowID      float
/* BackID всегда начинается с ExternalID транзакции и MovementID, породившими корректировку. Для каждого Settlement к BackID добавляется ExternalID Settlement.  */
            select @RuleID = dr.RuleID
                 , @BackID = concat(dr.ExternalTransactionID,'/',@MovementID,'/',dr.StlExternalID)
                 , @Infosource = dr.Infosource
                 , @MoveAmount = dr.MoveAmount * dr.Direction
                 , @CPAmount = dr.TranAmount * dr.TranDirection
                 , @Accrued = dr.SettledAccCoupon
                 , @msg = dr.Msg
              from QORT_DDM..DDM_GetImportTransactions_Rule ( @SettlementDetailID ) dr
            if isnull(@Msg, '') = ''
/* Когда прилетает Cancel на Settlement корректировки, мы удаляем исполненную корректировку и создаем новую не исполненную на весь остаток по транзакции В случае частичного Settlement есть корректировка, где в BackID будет его ID */
                if exists (select 1
                             from QORT_DB_PROD..CorrectPositions cp with (nolock, index = I_CorrectPositions_BackID)
                            where BackID like @BackID
                                  and cp.IsCanceled = 'N') 
                    begin
                        exec QORT_DDM..DDM_MovementCancel @MovementID = @MovementID
                                                        , @msg = @msg out
                        /* Если Settlement меньше транзакции, ищем оставшуюся непосетленую часть транзакции или всю транзакцию, если Settlement был полным*/
                        if abs(@MoveAmount) > abs(@CPAmount)
                            begin
                                /* Добавляем не исполненную корректировку на оставшийся объем */
                                set @MoveAmount = abs(@MoveAmount) - abs(@CPAmount)
                                exec QORT_DDM..DDM_InsertCorrectPosition @RuleID = @RuleID
                                                                       , @MovementID = @MovementID
                                                                       , @MovementID2 = @MovementID2
                                                                       , @Size = @MoveAmount
                                                                       , @AccruedCoupon = @Accrued
                                                                       , @msg = @msg out
                            end
                        select @msg = '000. CorrectPosition Canceled, BackID='+@BackID+'; '+isnull(@msg, '')
                    end
                   else
                    begin
                        set @Msg = '400. Bad Request. CorrectPosition ID not found for @BackID = '+@BackID
                    end
            return
        end try
        begin catch
            select @msg = error_message()
            return
        end catch
    end
