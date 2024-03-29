CREATE procedure dbo.QORT_GetSubBrocker_Orders @StartDate date        = '2020-01-08'
                                            , @EndDate   date        = '2020-01-17'
                                            , @ISIN      varchar(24) = 'US87238U2033'
                                            , @CpCode    varchar(6)  = 'FID003'
as
    begin
        set nocount on
        declare @TimeStamp varchar(512)
        drop table if exists #tmpOrders
        create table #tmpOrders
        ( CpCode                        varchar(6)
        , OrderNum                      varchar(20)
        , [Дата регистрации поручения]  varchar(10)
        , [Время регистрации поручения] varchar(12)
        , [Номер регистрации поручения] varchar(32)
        , [Наименование  клиента]       varchar(128)
        , [Номер  договора с клиентом]  varchar(16)
        , [Дата договора с клиентом]    varchar(16)
        , [Наименование операции]       varchar(12)
        , [Трейдер (QUIK)]              varchar(12)
        , [Трейдер (Биржа)]             varchar(32)
        , [Статус поручения]            varchar(32)
        , [Способ подачи поручения]     varchar(12)
        , [Тип поручения]               varchar(12)
        , [Категория поручения]         varchar(12) )
        while @StartDate <= @EndDate
            begin
                drop table if exists #tmp_MarketTrades
                select t.TradeDate
                     , t.TSSection_ID
                     , t.OrderNum
                into #tmp_MarketTrades
                  from QORT_DB_PROD.dbo.Trades t with (nolock, index = PK_Trades)
                  inner join QORT_DB_PROD..Securities sec with(nolock) on t.Security_ID = sec.id
                                                                          and sec.Enabled = 0
                  inner join QORT_DB_PROD..Assets a with(nolock) on a.id = sec.Asset_ID
                                                                    and a.Enabled = 0
                                                                    and a.ISIN = @ISIN
                  inner join QORT_DB_PROD..Subaccs s with(nolock) on s.id = t.SubAcc_ID
                                                                     and s.SubAccCode = 'RB0331'
                  inner join QORT_DB_PROD..TSSections tsec with(nolock) on tsec.id = t.TSSection_ID
                  inner join QORT_DB_PROD..TSs ts with(nolock) on ts.id = tsec.TS_ID
                                                                  and ts.IsMarket = 'y'
                 where t.Enabled = 0
                       and t.Tradedate = format(@StartDate, 'yyyyMMdd')
                       and t.NullStatus = 'n'
                       and left(replace(t.Comment, 'RB331/', ''), 6) = @CpCode
                 group by t.TradeDate
                        , t.TSSection_ID
                        , t.OrderNum
                insert into #tmpOrders
                select CpCode = left(replace(o.Comment, 'RB331/', ''), 6)
                     , OrderNum = cast(o.OrderNum as varchar(20))
                     , [Дата регистрации поручения] = stuff(stuff(nullif(o.OrderDate, 0), 7, 0, '-'), 5, 0, '-')
                     , [Время регистрации поручения] = stuff(stuff(stuff(right(concat('000000000', o.OrderTime), 9), 7, 0, '.'), 5, 0, ':'), 3, 0, ':')
                     , [Номер регистрации поручения] = o.BONum
                     , [Наименование  клиента] = f.Name
                     , [Номер  договора с клиентом] = ca.Num
                     , [Дата договора с клиентом] = stuff(stuff(nullif(ca.DateCreate, 0), 7, 0, '-'), 5, 0, '-')
                     , [Наименование операции] = iif(o.BuySell = 1, 'Покупка', 'Продажа')
                     , [Трейдер (QUIK)] = o.TraderUID
                     , [Трейдер (Биржа)] = o.Trader
                     , [Статус поручения] = case
                                                when o.status in(3, 7)
                                                     and t.TradeDate is not null then 'Частично исполнено'
                                                 else choose(o.status, 'Активно', 'Исполнено', 'Снято', 'Подано', 'Отклонено', 'Сформировано', 'Отозвано клиентом')
                                            end
                     , [Способ подачи поручения] = choose(o.DM_Const, 'Иное', 'Электронный', 'Бумажный', 'С голоса')
                     , [Тип поручения] = choose(o.TYPE_Const, 'Не задан', 'Торговое', 'Неторговое')
                     , [Категория поручения] = choose(o.InstrSort_Const, 'Не задана', 'Обычное', 'Служебное', 'Генеральное')
                  from QORT_DB_PROD..Orders o with (nolock, index = PK_Orders)
                  left join QORT_DB_PROD..Subaccs s with(nolock) on o.Subacc_ID = s.id
                  left join QORT_DB_PROD..Firms f with(nolock) on s.OwnerFirm_ID = f.id
                  inner join QORT_DB_PROD..Securities sec with(nolock) on o.Security_ID = sec.id
                                                                          and sec.Enabled = 0
                  inner join QORT_DB_PROD..Assets a with(nolock) on a.id = sec.Asset_ID
                                                                    and a.Enabled = 0
                                                                    and a.ISIN = @ISIN
                  left join QORT_DB_PROD..ClientAgrees ca with(nolock) on o.Subacc_ID = ca.SubAcc_ID
                                                                          and ca.Enabled = 0
                                                                          and ca.ClientAgreeType_ID in(1, 2, 3, 34)
                  left join #tmp_MarketTrades t on t.OrderNum = o.OrderNum
                                                   and t.TSSection_ID = sec.TSSection_ID
                 where 1 = 1
                       and o.OrderDate = format(@StartDate, 'yyyyMMdd')
                       and o.Comment like 'RB331%'
                       and left(replace(o.Comment, 'RB331/', ''), 6) = @CpCode
                select @StartDate = dateadd(dd, 1, @StartDate)
            end
        select *
          from #tmpOrders
    end
