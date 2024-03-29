create   function dbo.DDM_IsBusinessDay
( @Dt           int
, @CalendarName varchar(20) )
returns int
as
     begin
         declare @Dt_ datetime
         select @Dt = isnull(@Dt, format(getdate(), 'yyyyMMdd'))
         select @Dt_ = convert(datetime, convert(varchar(8), @Dt, 112), 112)
		 select @CalendarName = isnull(@CalendarName, 'Календарь_2010')
         select @Dt = case
                          when exists( select 1
                                         from QORT_DB_PROD.dbo.CalendarDates cd with(nolock)
                                         inner join QORT_DB_PROD.dbo.Calendars C with(nolock) on C.Id = cd.Calendar_ID
                                                                                                 and C.Name = @CalendarName
                                        where 1 = 1
                                              and cd.[Date] = format(@Dt_, 'yyyyMMdd') ) then -1
                           else 1
                      end * iif(datepart(dw, @Dt_) in(6, 7), -1, 1)
         return @Dt
     end
