CREATE function [dbo].[DDM_GetDateTimeFromInt] ( 
                @MDate int
              , @MTime int ) 
returns datetime2(3)
as
    begin
        declare 
               @DateTime datetime2(3) = null
        set @DateTime = cast(cast(@MDate as char) as date)
        set @DateTime = dateadd(hour, (@MTime / 10000000) % 100, dateadd(minute, (@MTime / 100000) % 100, dateadd(second, (@MTime / 1000) % 100, dateadd(millisecond, @MTime % 1000, @DateTime))))
        return @DateTime
    end
