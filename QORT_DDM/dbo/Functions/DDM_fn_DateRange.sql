create   function dbo.DDM_fn_DateRange(@DateStart int
                                  , @DateEnd   int
                                  , @Option    smallint)
returns @ReturnTable table( OperDate int )
as
     begin
         declare @DateFrom date
               , @DateTo   date
         select @DateFrom = cast(cast(@DateStart as char) as date)
              , @DateTo = cast(cast(@DateEnd as char) as date)
         if @Option&1 = 1
             select @DateFrom = dateadd(dd, 1, @DateFrom)
         if @Option&2 = 2
             select @DateTo = dateadd(dd, -1, @DateTo)
         while @DateFrom <= @DateTo
             begin
                 insert into @ReturnTable
                 select format(@DateFrom, 'yyyyMMdd')
                 select @DateFrom = dateadd(dd, 1, @DateFrom)
             end
         return
     end
