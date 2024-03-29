CREATE procedure [dbo].[DDM_MovementCancel] 
                 @MovementID    bigint
               , @msg           nvarchar(4000) output
               , @UnSettledOnly smallint       = 0
               , @BackID        varchar(100)   = null
as
    begin
        set nocount on
        begin try
            declare 
                   @CancelBackID   varchar(100)
                 , @Infosource     varchar(255)
                 , @TranExternalID varchar(255)
                 , @Version        int
                 , @InternalNumber varchar(255)
                 , @RowID          float
                 , @ExtraMsg       varchar(4000)
            /* BackID всегда начинается с ExternalID транзакции и MovementID, породившими корректировку. Для каждого Settlement, который лишь частично закрывает объем всей корректировки к BackID добавляется ID SettlementDetail. Если корректировка исполнилась одним Settlement объектом сразу на всю сумму, ссылка на Settlement у нее будет только в комментарии и Infosource */
            if @BackID is null /* для корректировок БЕЗ сделок */
                begin
                    select @BackID = dr.BackID
                         , @Infosource = dr.Infosource
                         , @TranExternalID = dr.ExternalID
                         , @Version = dr.CtVersion
                         , @InternalNumber = dr.InternalNumber
                         , @msg = dr.msg
                      from QORT_DDM..DDM_GetImportMovement_Rule(@MovementID) dr
            end
               else
                begin
                    /* для корректировок ИЗ-ПОД сделок */
                    select @InternalNumber = null
                         , @msg = null
            end
            if isnull(@Msg, '') <> '' /* Interrupt in case of an error message */
                begin
                    return
            end
            /* Когда прилетает Cancel на весь Movement, мы удаляем только этот мувмент */
            drop table if exists #tmp_cur_DDM_MovementCancel
            create table #tmp_cur_DDM_MovementCancel ( 
                         BackID varchar(100)
                       , RowID  float ) 
            insert into #tmp_cur_DDM_MovementCancel ( BackID ) 
            select BackID
              from QORT_TDB_PROD..CorrectPositions cp with (nolock, index = I_CorrectPositions_BackID)
             where cp.BackID like @BackID
                   /*+iif(@MovementID is not null and cp.BackID like concat(left(@BackID, charindex('/', @BackID)), @MovementID), 1, 0) */
                   and cp.IsProcessed < 4
                   and iif(@UnSettledOnly = 1
                           and cp.Date = 0, 1, 0) + iif(@UnSettledOnly = 0, 1, 0) = 1
                   and exists (select 1
                                     from QORT_DB_PROD..CorrectPositions cp0 with (nolock, index = I_CorrectPositions_BackID)
                                    where cp0.BackID = cp.BackID
                                          and cp0.IsCanceled = 'n')
             group by cp.BackID
            union all
            select BackID
              from QORT_TDB_PROD..CorrectPositions cp with (nolock, index = I_CorrectPositions_BackID)
             where cp.BackID like concat(left(@BackID, charindex('/', @BackID)), @MovementID)
                   and @MovementID is not null
                   and cp.IsProcessed < 4
                   and iif(@UnSettledOnly = 1
                           and cp.Date = 0, 1, 0) + iif(@UnSettledOnly = 0, 1, 0) = 1
                   and exists (select 1
                                     from QORT_DB_PROD..CorrectPositions cp0 with (nolock, index = I_CorrectPositions_BackID)
                                    where cp0.BackID = cp.BackID
                                          and cp0.IsCanceled = 'n')
             group by cp.BackID
            declare tmp_cur_DDM_MovementCancel cursor local
            for select BackID
                  from #tmp_cur_DDM_MovementCancel
            open tmp_cur_DDM_MovementCancel
            fetch next from tmp_cur_DDM_MovementCancel into 
                                                            @CancelBackID
            while @@FETCH_STATUS = 0
                begin
			/* Мы ждём, пока корректировка создаётся или 30 секунд */
			declare 
				   @TimeDelay   int      = 30
				 , @TimeStart   datetime = getdate()
				 , @IsProcessed bit      = 0
			while @IsProcessed = 0
				  and datediff(ss, @TimeStart, getdate()) < @TimeDelay
				begin
					if exists (select 1
								 from QORT_TDB_PROD.dbo.CorrectPositions cp with(nolock)
								where cp.BackID = @CancelBackID
									  and cp.IsProcessed > 2) 
					set @IsProcessed = 1
				end
			/* */
                    while @RowID is null
                        begin
                            exec QORT_TDB_PROD..P_GenFloatValue @RowID output
                                                              , 'cancelcorrectpositions_table'
                        end
                    insert into QORT_TDB_PROD.dbo.CancelCorrectPositions with(rowlock) ( id
                                                                                       , BackID
																					   , InfoSource
                                                                                       , isProcessed
                                                                                       , IsExecByComm ) 
                    values(
                           @RowID, @CancelBackID, 'BackOffice', 1, 'Y')
                    if @@ROWCOUNT > 0
                        exec QORT_DDM..DDM_ImportExecutionCommands @TC_Const = 16
                                                                 , @Oper_ID = @RowID
                                                                 , @Comment = @CancelBackID
                                                                 , @SystemName = 'DDM_MovementCancel'
                    set @RowID = null
                    fetch next from tmp_cur_DDM_MovementCancel into 
                                                                    @CancelBackID
                    select @ExtraMsg = concat(@ExtraMsg, '; ', @CancelBackID)
                end
            close tmp_cur_DDM_MovementCancel
            deallocate tmp_cur_DDM_MovementCancel
            /* if Cancel Movement is last version - have to Cancel ClientInst */
            if isnull(@InternalNumber, '') <> ''
               and exists (select 1
                             from QORT_DDM..CommonTransaction ct with(nolock)
                            where ct.ExternalID = @TranExternalID
                                  and ct.DDMStatus = 'Cancelled'
                                  and ct.Version > @Version) 
                exec QORT_DDM.dbo.DDM_InsertClientInstr @InternalNumber = @InternalNumber
                                                      , @Status = 'Cancel'
                                                      , @msg = @msg output
            select @msg = '000. All affected CorrectPosition has Canceled' + isnull(@ExtraMsg, ' Nothing to cancel') + '; ' + isnull(@msg, '')
            return
        end try
        begin catch
            select @msg = error_message()
            return
        end catch
    end
