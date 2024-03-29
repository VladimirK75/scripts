CREATE function [dbo].[DDM_fn_AddBusinessDay] ( 
                @Dt           int
              , @AddDay       int
              , @CalendarName varchar(20) ) 
returns int
as
    begin
        declare 
               @i   int
             , @Dt_ datetime
        select @Dt=isnull(@Dt, format(getdate(),'yyyyMMdd'))
        select @Dt_ = convert(datetime, convert(varchar(8), @Dt, 112), 112)
             , @i = 0
        while @i * sign(@AddDay) < @AddDay * sign(@AddDay)
            begin
                set @Dt_ = dateadd(day, sign(@AddDay), @Dt_)
                set @Dt = convert(int, convert(varchar(8), @Dt_, 112), 112)
                if datepart(WeekDay, @Dt_) between 2 and 6
                   and not exists (select 1
                                     from QORT_DB_PROD.dbo.CalendarDates D with(nolock)
                                     inner join QORT_DB_PROD.dbo.Calendars C with(nolock) on C.Id = D.Calendar_ID
                                    where C.Name = @CalendarName
                                          and D.date = @Dt)
                   or datepart(WeekDay, @Dt_) in(1, 7)
                      and exists (select 1
                                    from QORT_DB_PROD.dbo.CalendarDates D with(nolock)
                                    inner join QORT_DB_PROD.dbo.Calendars C with(nolock) on C.Id = D.Calendar_ID
                                   where C.Name = @CalendarName
                                         and D.date = @Dt) 
                    set @i = @i + sign(@AddDay)
            end
        return @Dt
    end;
