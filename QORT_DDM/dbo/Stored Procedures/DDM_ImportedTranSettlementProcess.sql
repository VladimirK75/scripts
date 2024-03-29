CREATE procedure [dbo].[DDM_ImportedTranSettlementProcess] 
                @SettlementDetailID bigint
              , @Action             nvarchar(7) /* New and Cancel only*/
              , @MovementID         bigint         = null
              , @msg                nvarchar(4000) output
as
    begin
        declare 
               @RuleID            bigint
             , @BackID            varchar(100)
             , @MockBackID        varchar(100)
             , @MovementID2       bigint
             , @SettledOnly       bit
             , @CT_Const          tinyint
             , @CL_Const          tinyint
             , @IsInternal        char(1)
             , @SettlementDateInt int
             , @Size              decimal(38, 14)
             , @ExternalID        varchar(255)
        /* get additional parameters for this Settlement */
        select @RuleID = dr.RuleID
             , @BackID = dr.BackID
             , @ExternalID = dr.ExternalID
             , @MockBackID = concat(dr.ExternalID, '/%', dr.StlExternalID)
             , @CT_Const = dr.CT_Const
             , @CL_Const = dr.CL_Const
             , @IsInternal = iif(isnull(dr.IsInternal, 0) = 0, 'N', 'Y')
             , @SettledOnly = dr.SettledOnly
             , @MovementID = isnull(@MovementID, dr.MovementID)
             , @MovementID2 = dr.MovementID2
             , @SettlementDateInt = dr.SettlementDateInt
             , @Size = round(isnull(@Size, dr.TranDirection * TranAmount), 2)
             , @Msg = dr.Msg
          from QORT_DDM..DDM_GetImportTransactions_Rule(@SettlementDetailID) dr
        if isnull(@Msg, '') = '' /* without errors in DDM_GetImportTransactions_Rule */
            begin
                if @CT_Const > 0 /* CorrectPositions */
                    begin
                        if @Action = 'New'
                            begin
                                exec QORT_DDM..DDM_InsertCorrectPosition @RuleID = @RuleID
                                                                       , @MovementID = @MovementID
                                                                       , @MovementID2 = @MovementID2
                                                                       , @SettlementDetailID = @SettlementDetailID
                                                                       , @msg = @msg out
                        end
                        if @Action = 'Cancel'
                            begin
                                /* проверка. Если это перевод, то отправлять в репроцесс(пендинг) положительную отмену, пока существуют отрицательная */
                                if @CT_Const in(11, 12)
                                   and @IsInternal = 'Y'
                                   and @Size > 0
                                    begin
                                        if exists (select 1
                                                     from QORT_DB_PROD..CorrectPositions cp with(nolock)
                                                    where 1 = 1
                                                          and cp.BackID like concat(@ExternalID, '/%')
                                                          and cp.CT_Const = @CT_Const
                                                          and isnull(cp.IsCanceled, 'n') = 'n'
                                                          and cp.Size = -1 * abs(@Size))
                                           and not exists (select 1
                                                             from QORT_DB_PROD..CorrectPositions cp with(nolock)
                                                            where 1 = 1
                                                                  and cp.BackID like concat(@ExternalID, '/%')
                                                                  and cp.BackID not like @BackID
                                                                  and cp.CT_Const = @CT_Const
                                                                  and isnull(cp.IsCanceled, 'n') = 'n'
                                                                  and cp.Size = abs(@Size)) 
                                            begin
                                                select @msg = '404. Negative InteraccountOperation is waiting for a positive one'
                                                return
                                        end
                                end
                                exec DDM_MovementCancel @MovementID = @MovementID
                                                      , @msg = @msg out
                                                      , @BackID = @MockBackID
                        end
                end
                   else /* Clearings still dummy yet */
                    begin
                        exec QORT_DDM..DDM_InsertClearing @RuleID = @RuleID
                                                        , @MovementID = @MovementID
                                                        , @SettlementDetailID = @SettlementDetailID
                                                        , @msg = @msg out
                end
        end
        return
    end
