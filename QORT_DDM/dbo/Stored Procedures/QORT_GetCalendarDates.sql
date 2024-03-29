create   procedure QORT_GetCalendarDates
( @Year     int = 2020
, @Month    int = 1
, @Calendar int = 1 )
as
    begin
        set datefirst 1;
        declare @StartDate date
              , @EndDate   date
        select @StartDate = datefromparts(@Year, @Month, 1)
        select @EndDate = eomonth(@StartDate, 0)
        declare @CalendarList table
        ( WeekNum     int
        , WeekDayName varchar(16)
        , DateNum     int )
        while @StartDate <= @EndDate
            begin
                insert into @CalendarList
                select WeekNum = datepart(week, @StartDate)
                     , WeekDayName = datename(dw, @StartDate)
                     , DateNum = datepart(dd, @StartDate) * case
                                                                when exists( select 1
                                                                               from QORT_DB_PROD.dbo.CalendarDates cd
                                                                              where cd.Calendar_ID = @Calendar
                                                                                    and cd.[Date] = format(@StartDate, 'yyyyMMdd') ) then -1
                                                                 else 1
                                                            end * iif(datepart(dw, @StartDate) in(6, 7), -1, 1)
                select @StartDate = dateadd(dd, 1, @StartDate)
            end
        select *
          from @CalendarList cl pivot(sum(DateNum) for WeekDayName in(Monday
                                                                    , Tuesday
                                                                    , Wednesday
                                                                    , Thursday
                                                                    , Friday
                                                                    , Saturday
                                                                    , Sunday)) P
    end
