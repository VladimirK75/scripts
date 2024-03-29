create procedure dbo.DDM_SettlementDetailProcess 
                 @SettlementDetailID bigint
               , @Action             nvarchar(7) /* New and Cancel only*/
               , @msg                nvarchar(4000) output
as
    begin
        declare 
               @Rez               int
             , @BackID            varchar(100)
             , @Infosource        varchar(100)
             , @MovementID        bigint
             , @SettlementID      bigint
             , @IsSynchronized    bit
             , @IsDual            bit
             , @NeedClientInstr   bit
             , @SettledOnly       bit
             , @STLRuleID         bigint
             , @QRTObject         varchar(50)
             , @QRTObjType        tinyint
             , @TransactionID     bigint
             , @ExternalID        varchar(255)
             , @Version           tinyint
             , @Direction         smallint
             , @SettlementDate    datetime
             , @SettlementDateInt int
             , @AccruedCoupon     decimal
             , @SettledAccCoupon  decimal
             , @Amount            decimal
             , @SettledAmount     decimal
             , @UnSettledAmount   decimal
             , @Size              decimal
             , @SystemID          bigint
             , @StlExternalID     bigint
             , @ReversedID        bigint
             , @RuleID            bigint
             , @StlType           varchar(6)
             , @StlDateType       varchar(50)
        select @MovementID = sd.MovementID
             , @SettlementID = sd.SettlementID
             , @SettledAccCoupon = sd.AccruedCoupon
             , @SettledAmount = isnull(sd.Amount, sd.Qty)
             , @StlType = sd.Type
             , @ReversedID = isnull(s.ReversedID, 0)
             , @StlExternalID = s.ExternalID
          from QORT_DDM..SettlementDetails sd with(nolock)
          inner join QORT_DDM..Settlement s with(nolock) on sd.SettlementID = s.ID
         where sd.ID = @SettlementDetailID
        /* BackID всегда начинается с ExternalID транзакции и MovementID, породившими корректировку. Для каждого Settlement, который лишь частично закрывает объем всей корректировки к BackID добавляется ID SettlementDetail. Если корректировка исполнилась одним Settlement объектом сразу на всю сумму, ссылка на Settlement у нее будет только в комментарии и Infosource */
        select @BackID = 'CL'+convert(varchar(20), cast(ct.ExternalID as numeric(18, 0)))+'/'+convert(varchar(20), cast(@MovementID as numeric(18, 0)))
             , @RuleID = dr.RuleID
             , @QRTObject = dr.QRTObject
             , @QRTObjType = dr.QRTObjType
             , @SettledOnly = dr.SettledOnly
             , @STLRuleID = dr.STLRuleID
             , @TransactionID = mv.TransactionID
             , @ExternalID = ct.ExternalID
             , @Direction = mv.Direction
             , @AccruedCoupon = mv.AccruedCoupon
             , @Amount = isnull(mv.Amount, mv.Qty)
             , @StlDateType = sr.SettlementDate
          from QORT_DDM..DDM2QORT_Rules dr with(nolock)
             , QORT_DDM..SettlementRules sr with(nolock)
             , QORT_DDM..Movements mv with(nolock)
             , QORT_DDM..CommonTransaction ct with(nolock)
         where mv.ID = @MovementID
               and mv.TransactionID = ct.ID
               and dr.OperationType = ct.OperationType
               and dr.MovType = mv.MovType
               and dr.ChargeType = mv.ChargeType
               and dr.IsSynchronized = 1
               and dr.StartDate <= getdate()
               and isnull(dr.EndDate, '20501231') > getdate()
               and (dr.Direction is null
                    or dr.Direction = mv.Direction)
               and dr.STLRuleID = sr.STLRuleID
               and sr.Capacity = @StlType
        if @QRTObject is null
            begin
                select @msg = '001. No settlement rules for SettlementDetailID = '+convert(varchar(50), @SettlementDetailID)+'. MovementID = '+convert(varchar(50), @MovementID)
                     , @Rez = 1
                return @Rez
            end
        /* Определяем дату расчетов, согласно правилам */
        select @SettlementDate = case @StlDateType
                                      when 'FOAvaliableDate' then st.FOAvaliableDate
                                      when 'ActualSettlementDate' then st.ActualSettlementDate
                                      when 'AvaliableDate' then st.AvaliableDate
                                 end
          from QORT_DDM..Settlement st with(nolock)
         where ID = @SettlementID
        select @SettlementDateInt = isnull(year(@SettlementDate) * 10000 + month(@SettlementDate) * 100 + day(@SettlementDate), 0)
        if @QRTObject = 'CorrectPosition'
            begin
                select @Infosource = 'TXN'+convert(varchar(20), cast(@TransactionID as numeric(18, 0)))+'/STL'+convert(varchar(20), cast(@SettlementDetailID as numeric(18, 0)))
                if @SettledOnly = 1
                    begin
                        /* Рассматриваем корректировки, которые создаются только сразу исполненными (различные CashIN, SecurityIN и т.д.) */
                        select @BackID = @BackID+'/'+convert(varchar(20), cast(@SettlementDetailID as numeric(18, 0)))
                        if @Action = 'Cancel'
                            begin
                                /* Отмена сеттлмента для таких корректировок означает отмену корректировки */
                                select @SystemID = id
                                     , @BackID = BackID
                                  from QORT_DB_PROD..CorrectPositions with(nolock)
                                 where BackID like @BackID+'%'
                                       and Infosource = @Infosource
                                       and IsCanceled = 'n'
                                if isnull(@SystemID, 0) = 0
                                    begin
                                        select @msg = '001. CorrectPosition not found with BackID = '+@BackID+'. Action = '+@Action+'. Infosource = '+@Infosource
                                             , @Rez = 2
                                        return @Rez
                                    end
                                insert into QORT_TDB_PROD.dbo.CancelCorrectPositions ( id
                                                                                     , BackID
                                                                                     , isProcessed ) 
                                select-1
                                    , BackID
                                    , 1
                                  from QORT_DB_PROD..CorrectPositions cp with(nolock)
                                 where cp.id = @SystemID
                                       and cp.IsCanceled = 'n'
                            end
                        if @Action = 'New'
                            begin
                                /* Поскольку в этой ветке рассматривается только корректировки, создаваемые исполненными, мы не анализируем полный это Settlement или частичный */
                                select @Size = @SettledAmount * @Direction
                                exec QORT_DDM..DDM_InsertCorrectPosition @RuleID = @RuleID
                                                                       , @MovementID = @MovementID
                                                                       , @Qty = @Size
                                                                       , @AccruedCoupon = @SettledAccCoupon
                                                                       , @SettlementDetailID = @SettlementDetailID
                                                                       , @SettlementDate = @SettlementDate
                                                                       , @Rez = @Rez out
                            end
                    end
                   else
                    begin
                        /* Ветка для корректировок, созданых неисполненными. Ищем ту самую неисполненную корректировку, которую надо частично или полностью засетлить или наоборот рассетлить по Cancel */
                        select @SystemID = id /*, @BackID = BackID*/
                          from QORT_DB_PROD..CorrectPositions with(nolock)
                         where BackID like @BackID+'%'
                               and (Infosource like @Infosource
                                    or @Action = 'New')
                               and IsCanceled = 'n'
                               and (@Action = 'Cancel'
                                    or Date = 0
                                    or @ReversedID > 0)
                        if isnull(@SystemID, 0) = 0
                            begin
                                select @msg = '001. CorrectPosition not found with BackID = '+@BackID+'. Action = '+@Action+'. Infosource = '+@Infosource
                                     , @Rez = 4
                                return @Rez
                            end
                        if @Action = 'Cancel'
                            begin
                                /* Отменяем корректировку по Settlement */
                                insert into QORT_TDB_PROD.dbo.CancelCorrectPositions ( id
                                                                                     , BackID
                                                                                     , isProcessed ) 
                                select-1
                                    , BackID
                                    , 1
                                  from QORT_DB_PROD..CorrectPositions cp with(nolock)
                                 where cp.id = @SystemID
                                       and cp.IsCanceled = 'n'
                                /* Отменяем текущую незасетленную корректировку, если она есть */
                                select @SystemID = id
                                     , @UnSettledAmount = Size
                                     , @AccruedCoupon = Accrued
                                  from QORT_DB_PROD..CorrectPositions with(nolock)
                                 where BackID like @BackID+'%'
                                       and IsCanceled = 'n'
                                       and Date = 0
                                if isnull(@SystemID, 0) > 0
                                    begin
                                        select @Size = @UnSettledAmount + @SettledAmount * @Direction
                                        select @AccruedCoupon = @AccruedCoupon + @SettledAccCoupon
                                        insert into QORT_TDB_PROD.dbo.CancelCorrectPositions ( id
                                                                                             , BackID
                                                                                             , isProcessed ) 
                                        select-1
                                            , BackID
                                            , 1
                                          from QORT_DB_PROD..CorrectPositions cp with(nolock)
                                         where cp.id = @SystemID
                                               and cp.IsCanceled = 'n'
                                    end
                                /* Вставляем новую незасетленную корректировку на остаток по MovementID */
                                exec QORT_DDM..DDM_InsertCorrectPosition @RuleID = @STLRuleID
                                                                       , @MovementID = @MovementID
                                                                       , @Qty = @Size
                                                                       , @AccruedCoupon = @AccruedCoupon
                                                                       , @Rez = @Rez out
                            end
                        if @Action = 'New'
                            begin			
                                /* Ищем корерктировку и незасетленый объем по данному Movement */
                                select @SystemID = id
                                     , @UnSettledAmount = Size
                                  from QORT_DB_PROD..CorrectPositions with(nolock)
                                 where BackID like @BackID+'%'
                                       and IsCanceled = 'n'
                                       and Date = 0
                                if isnull(@SettledAmount, 0) = isnull(@UnSettledAmount, 0)
                                   and @ReversedID = 0
                                    begin
                                        /* Если Settlement полный и это не реверсный трансфер, просто исполняем существующую корректировку */
                                        update QORT_TDB_PROD..CorrectPositions
                                        set Date = @SettlementDateInt
                                          , Infosource = Infosource+'/STL'+convert(varchar(20), cast(@SettlementDetailID as numeric(18, 0)))
                                          , Comment2 = Comment2+'/STL '+convert(varchar(20), cast(@StlExternalID as numeric(18, 0)))
                                          , ET_Const = 4 /* Edit*/                                          , IsProcessed = 1
                                          from QORT_TDB_PROD..CorrectPositions
                                         where BackID like @BackID+'%'
                                               and Date = 0
                                               and Size = @UnSettledAmount
                                    end
                                   else
                                    if @ReversedID > 0
                                        begin
                                            /* Если трансфер реверсный, мы создаем новую корректировку в обратную сторону с соответствующим комментарием и Infosource */
                                            select @Size = @SettledAmount * @Direction
                                            if isnull(@Size, 0) = 0
                                                begin
                                                    select @msg = '005.No settlement amount. SettlementDetailID = '+convert(varchar(50), @SettlementDetailID)
                                                         , @Rez = 8
                                                    return @Rez
                                                end
                                            exec QORT_DDM..DDM_InsertCorrectPosition @RuleID = @RuleID
                                                                                   , @MovementID = @MovementID
                                                                                   , @Qty = @Size
                                                                                   , @AccruedCoupon = @AccruedCoupon
                                                                                   , @SettlementDetailID = @SettlementDetailID
                                                                                   , @SettlementDate = @SettlementDate
                                                                                   , @Rez = @Rez out
                                        end
                                       else /* Если частичный сеттлмент */
                                        begin
                                            if isnull(@SettledAmount, 0) > isnull(@UnSettledAmount, 0)
                                                begin
                                                    select @msg = '006.Settlement is more than trade. SettlementDetailID = '+convert(varchar(50), @SettlementDetailID)
                                                         , @Rez = 16
                                                    return @Rez
                                                end
                                            select @Size = @SettledAmount * @Direction
                                            if isnull(@Size, 0) = 0
                                                begin
                                                    select @msg = '005.No settlement amount. SettlementDetailID = '+convert(varchar(50), @SettlementDetailID)
                                                         , @Rez = 32
                                                    return @Rez
                                                end
                                            /* Создаем корректировку на засетленый объем */
                                            exec QORT_DDM..DDM_InsertCorrectPosition @RuleID = @RuleID
                                                                                   , @MovementID = @MovementID
                                                                                   , @Qty = @Size
                                                                                   , @AccruedCoupon = @SettledAccCoupon
                                                                                   , @SettlementDetailID = @SettlementDetailID
                                                                                   , @SettlementDate = @SettlementDate
                                                                                   , @Rez = @Rez out
                                            if @Rez > 0
                                                return @Rez
                                            select @SystemID = id
                                                 , @UnSettledAmount = Size
                                                 , @AccruedCoupon = Accrued
                                              from QORT_DB_PROD..CorrectPositions with(nolock)
                                             where BackID like @BackID+'%'
                                                   and IsCanceled = 'n'
                                                   and Date = 0
                                            /* Убиваем незасетленую корректировку */
                                            if isnull(@SystemID, 0) > 0
                                                begin
                                                    select @Size = @UnSettledAmount - @SettledAmount * @Direction
                                                    select @AccruedCoupon = @AccruedCoupon - @SettledAccCoupon
                                                    insert into QORT_TDB_PROD.dbo.CancelCorrectPositions ( id
                                                                                                         , BackID
                                                                                                         , isProcessed ) 
                                                    select-1
                                                        , BackID
                                                        , 1
                                                      from QORT_DB_PROD..CorrectPositions cp with(nolock)
                                                     where cp.id = @SystemID
                                                           and cp.IsCanceled = 'n'
                                                end
                                            /* Вставляем новую незасетленную корректировку на остаток по MovementID */
                                            exec QORT_DDM..DDM_InsertCorrectPosition @RuleID = @STLRuleID
                                                                                   , @MovementID = @MovementID
                                                                                   , @Qty = @Size
                                                                                   , @AccruedCoupon = @AccruedCoupon
                                                                                   , @Rez = @Rez out
                                        end
                            end
                    end
            end
        return @Rez
    end
