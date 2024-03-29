CREATE procedure [dbo].[QORT_GetTradeInstReport]
( @Subacc varchar(32)
, @Rdate  date
, @ListOfStatuses   varchar(128) )
as
    begin
        declare @OrderDate int
        select @OrderDate = format(@Rdate, 'yyyyMMdd')
        drop table if exists #tmp_Order
        select OrderDate = convert(varchar(10), cast(str(o.OrderDate) as date), 104)
             , OrderHour = (o.OrderTime / 10000000) % 100
             , OrderTime = stuff(stuff(stuff(right(concat('0000000000', o.OrderTime), 9), 7, 0, '.'), 5, 0, ':'), 3, 0, ':')
             , issue.ShortName
             , issue.ISIN
             , o.BONum
             , f.Name
             , ClientAgreesNum = ca.Num
             , ClientAgreesDateCreate = convert(varchar(10), cast(str(ca.DateCreate) as date), 104)
             , AuthField = case
                               when nullif(o.TraderUID, 0) is null then iif(o.DM_Const = 3, 'Obrezkov K.', o.AuthorPTS)
                                else concat('UID', o.TraderUID)
                           end
             , status = choose(o.status, 'Активна', 'Исполнена', 'Снята', 'Подана', 'Отклонена', 'Сформирована', 'Снята пользователем')
             , DM_Const = dm.Description
             , InstrSort_Const = choose(o.InstrSort_Const, 'Не задана', 'Обычное', 'Служебное', 'Генеральное')
        into #tmp_Order
          from QORT_DB_PROD..Orders o with(nolock)
		  inner join QORT_DDM.dbo.QORT_GetList( @ListOfStatuses) st on cast(st.Value as smallint) = o.status
          inner join QORT_DB_PROD..Securities sec with(nolock) on sec.id = o.Security_ID
          inner join QORT_DB_PROD..Assets issue with(nolock) on issue.id = sec.Asset_ID
          inner join QORT_DB_PROD..DM_Const dm with(nolock) on dm.Value = o.DM_Const
          inner join QORT_DB_PROD..Subaccs s with(nolock) on s.id = o.Subacc_ID
          inner join QORT_DDM.dbo.QORT_GetLoroList( @Subacc ) loro on loro.Subacc_ID = s.id
          left join QORT_DB_PROD..Firms f with(nolock) on f.id = s.OwnerFirm_ID
                                                          and f.Enabled = 0
          left join QORT_DB_PROD..ClientAgrees ca with(nolock) on o.Subacc_ID = ca.SubAcc_ID
                                                                  and ca.Enabled = 0
                                                                  and ca.ClientAgreeType_ID in(1, 2, 3, 34)
         where 1 = 1
               and o.Orderdate = @OrderDate
               and o.Enabled = 0
        insert into #tmp_Order
        select OrderDate = convert(varchar(10), cast(str(ti.[Date]) as date), 104)
             , OrderHour = (ti.[Time] / 10000000) % 100
             , OrderTime = stuff(stuff(stuff(right(concat('0000000000', ti.[Time]), 9), 7, 0, '.'), 5, 0, ':'), 3, 0, ':')
             , issue.ShortName
             , issue.ISIN
             , ti.BONum
             , f.Name
             , ClientAgreesNum = ca.Num
             , ClientAgreesDateCreate = convert(varchar(10), cast(str(ca.DateCreate) as date), 104)
             , AuthField = case
                               when nullif(ti.TraderUID, 0) is null then iif(ti.DM_Const = 3, ti.AuthorFIO, ti.AuthorPTS)
                                else concat('UID', ti.TraderUID)
                           end
             , status = choose(IS_Const, 'Новое', 'На исполнении', '', 'Частично исполнено', 'Исполнено', 'Отказано', 'Отклонена ИТС QUIK', 'Отклонена ТС', 'Отозвано клиентом', 'Истек срок', 'Не исполнено')
             , DM_Const = dm.Description
             , InstrSort_Const = choose(ti.InstrSort_Const, 'Не задана', 'Обычное', 'Служебное', 'Генеральное')
          from QORT_DB_PROD..TradeInstrs ti with(nolock)
          inner join QORT_DB_PROD..Securities sec with(nolock) on sec.id = ti.Security_ID
          inner join QORT_DB_PROD..Assets issue with(nolock) on issue.id = sec.Asset_ID
          inner join QORT_DB_PROD..DM_Const dm with(nolock) on dm.Value = ti.DM_Const
          inner join QORT_DB_PROD..Subaccs s with(nolock) on s.id = ti.AuthorSubAcc_ID
          inner join QORT_DDM.dbo.QORT_GetLoroList( @Subacc ) loro on loro.Subacc_ID = s.id
          inner join QORT_DB_PROD..Firms f with(nolock) on f.id = s.OwnerFirm_ID
                                                           and f.Enabled = 0
          left join QORT_DB_PROD..Users auth with(nolock) on auth.id = ti.AuthorUser_ID
          left join QORT_DB_PROD..ClientAgrees ca with(nolock) on ca.SubAcc_ID in(select ti.AuthorSubAcc_ID
                                                                                  union
                                                                                  select loro.Subacc_ID
                                                                                    from QORT_DDM.dbo.QORT_GetLoroList( f.BOCode ) loro)
        and ca.Enabled = 0
        and ca.ClientAgreeType_ID in(1, 2, 3, 34)
         where 1 = 1
               and ti.[Date] = @OrderDate
               and ti.Enabled = 0
        select *
          from #tmp_Order
    end
