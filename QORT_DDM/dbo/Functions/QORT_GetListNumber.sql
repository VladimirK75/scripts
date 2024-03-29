create   function dbo.QORT_GetListNumber(@List      varchar(max)
                                    , @Delimiter char(1)
                                    , @id        int)
returns varchar(max)
as
     begin
         declare @ResultString varchar(max)
         declare @Result table
         ( id    int identity(1, 1)
         , Value varchar(max) )
         insert into @Result
         select *
           from string_split(@List, @Delimiter)
         select @ResultString = Value
           from @Result
          where id = @id
         return @ResultString
     end
