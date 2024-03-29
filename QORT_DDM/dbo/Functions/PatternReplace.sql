create function dbo.PatternReplace
( @InputString varchar(4000)
, @Pattern     varchar(100)
, @ReplaceText varchar(4000) )
returns varchar(4000)
as
     begin
         declare @Result varchar(4000)
         set @Result = '' -- First character in a match 
         declare @First int -- Next character to start search on 
         declare @Next int
         set @Next = 1 -- Length of the total string -- 8001 
         if @InputString is null
             declare @Len int
         set @Len = coalesce(len(@InputString), 8001) -- End of a pattern 
         declare @EndPattern int
         while @Next <= @Len
             begin
                 set @First = patindex('%' + @Pattern + '%', substring(@InputString, @Next, @Len))
                 if isnull(@First, 0) = 0	--no match - return 
                     begin
                         set @Result = @Result + case --return NULL, just like REPLACE, if inputs are NULL 
                                                 when @InputString is null
                                                      or @Pattern is null
                                                      or @ReplaceText is null
                                                      then null
                                                      else substring(@InputString, @Next, @Len)
                                                 end
                         break
                 end
                      else
                     begin -- Concatenate characters before the match to the result 
                         set @Result = @Result + substring(@InputString, @Next, @First - 1)
                         set @Next = @Next + @First - 1
                         set @EndPattern = 1 -- Find start of end pattern range 
                         while patindex(@Pattern, substring(@InputString, @Next, @EndPattern)) = 0
                             set @EndPattern = @EndPattern + 1 -- Find end of pattern range 
                         while patindex(@Pattern, substring(@InputString, @Next, @EndPattern)) > 0
                               and @Len >= @Next + @EndPattern - 1
                             set @EndPattern = @EndPattern + 1 --Either at the end of the pattern or @Next + @EndPattern = @Len 
                         set @Result = @Result + @ReplaceText
                         set @Next = @Next + @EndPattern - 1
                 end
             end
         return @Result
     end
