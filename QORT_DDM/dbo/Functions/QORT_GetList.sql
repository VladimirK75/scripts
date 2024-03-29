create   function dbo.QORT_GetList(@List varchar(max))
returns @tmp_Value table( [Value] varchar(48) )
as
     begin
         declare @Delimiter char(1)     = ','
               , @pos       smallint
               , @b         smallint
               , @tmpValue  varchar(32)
         select @List = concat(isnull(@List, ''), @Delimiter)
         while charindex(',', @List) > 0
             begin
                 select @pos = charindex(@Delimiter, @List)
                 select @tmpValue = ltrim(rtrim(substring(@List, 1, @pos - 1)))
                 if nullif(@tmpValue, '') is not null
                    and not exists( select 1
                                      from @tmp_Value tl
                                     where tl.[Value] = @tmpValue )
                     insert into @tmp_Value
                     select @tmpValue
                 select @List = substring(@List, @pos + 1, len(@List) - @pos)
                      , @tmpValue = null
             end
         return
     end
