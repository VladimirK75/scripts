CREATE procedure [dbo].[UpdateAggregateOrders] @StartDate bigint
                                     , @EndDate   bigint
as
    begin
        set nocount on;
        select @StartDate = isnull(@StartDate, format(getdate(), 'yyyyMMdd'))
        select @EndDate = isnull(@EndDate, @StartDate)
        declare @Date      int
              , @OrderDate cursor
        set @OrderDate = cursor local
        for select dt.OperDate
              from QORT_DDM.dbo.DDM_fn_DateRange( @StartDate, @EndDate, 0 ) dt
        open @OrderDate
        fetch next from @OrderDate into @Date
        while @@FETCH_STATUS = 0
            begin
                delete from QORT_DDM.dbo.AggregateOrders
                 where OrderDate = @Date
                insert into QORT_DDM.dbo.AggregateOrders
                select o.OrderDate as                        OrderDate
                     , case o.DM_const when 1
                            then 'Тип_Иное' when 2
                            then 'Тип_Электронный' when 3
                            then 'Тип_Бумажный' when 4
                            then 'Тип_С голоса' when 5
                            then 'Тип_Личный кабинет (электронная форма)' when 6
                            then 'Тип_Оригинал на бумажном носителе' when 7
                            then 'Тип_Система интернет-трейдинга (электронная форма)' when 8
                            then 'Тип_Телефон (голосовая информация)' when 9
                            then 'Тип_Факс (электронная форма)' when 10
                            then 'Тип_Шлюз (электронная форма)' when 11
                            then 'Тип_Электронная почта (электронная форма)'
                            else cast(o.DM_const as nvarchar(512))
                       end as                                [Delivery method]
                     , case o.TYPE_const when 1
                            then 'Не задан' when 2
                            then 'Торговое' when 3
                            then 'Неторговое'
                            else cast(o.TYPE_const as nvarchar(512))
                       end as                                [Instruction type]
                     , case o.InstrSort_Const when 1
                            then 'Не задана' when 2
                            then 'Обычное' when 3
                            then 'Служебное' when 4
                            then 'Генеральное'
                            else cast(o.InstrSort_Const as nvarchar(512))
                       end as                                [Instruction category]
                       --   AuthorFIO,
                       --   AuthorPTS,
                     , cast(o.TraderUID as nvarchar(512)) as TraderUID
                     , o.Trader
                       --    CPFirmCode,
                     , o.QuikClassCode
                       --cast(cast(o.ordernum as bigint) as nvarchar(512))               as [OrderId],
                     , count(o.ordernum) as                  OrderCount
                     , case o.status when 1
                            then 'Активна' when 2
                            then 'Исполнена' when 3
                            then 'Снята' when 4
                            then 'Подана' when 5
                            then 'Отклонена' when 6
                            then 'Сформирована' when 7
                            then 'Снята пользователем'
                            else cast(o.status as nvarchar(512))
                       end as                                [Order status]
                       --    balance,
                       --    lotqty,
                     , s.SubAccCode as                       SubAccCode
					 , LastRefreshTime = getdate()
                  from QORT_DB_PROD.dbo.orders o with(nolock)
                  join QORT_DB_PROD.dbo.Subaccs s with(nolock) on o.subacc_id = s.id
                 where 1 = 1
                       and o.OrderDate = @Date
                 group by o.OrderDate
                        , o.DM_const
                        , o.TYPE_const
                        , o.InstrSort_Const
                        , o.TraderUID
                        , o.Trader
                        , o.QuikClassCode
                        , o.status
                        , s.SubAccCode
                fetch next from @OrderDate into @Date
            end
        close @OrderDate
        deallocate @OrderDate
    end
