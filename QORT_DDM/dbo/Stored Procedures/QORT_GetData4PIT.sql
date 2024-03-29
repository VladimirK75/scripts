create   procedure dbo.QORT_GetData4PIT
( @FirmName      varchar(150) = 'Петухов Сергей Евгеньевич'
, @DateStart     int          = 20200101
, @DateEnd       int          = 20201231
, @TypeOperation smallint     = 0 )
as
    begin
        drop table if exists #tmp_Subaccs
        create table #tmp_Subaccs
        ( ID float
          primary key )
        insert into #tmp_Subaccs
        select s.ID
          from QORT_DB_PROD.dbo.Subaccs s with(nolock)
          inner join QORT_DB_PROD.dbo.Firms f with(nolock) on s.OwnerFirm_ID = f.id
                                                              and f.Name = @FirmName
         where 1 = 1
               and s.Enabled = 0
        if isnull(@TypeOperation, 0) = 0
            select t.id
                 , t.TradeDate
                 , t.NullStatus
              from QORT_DB_PROD.dbo.Trades t with (nolock, index = PK_Trades)
              inner join #tmp_Subaccs ts with(nolock) on t.SubAcc_ID = ts.id
              inner join QORT_DDM.dbo.DDM_fn_DateRange( @DateStart, @DateEnd, 0 ) dt on dt.OperDate = t.TradeDate
             where 1 = 1
                   and t.IsRepo2 = 'n'
                   and t.Enabled = 0
        if isnull(@TypeOperation, 0) = 1
            select p.id
                 , p.PhaseDate
                 , p.Trade_ID
                 , p.PC_Const
                 , p.IsCanceled
              from QORT_DB_PROD.dbo.Phases p with (nolock, index = I_Phases_PhaseDate)
              inner join #tmp_Subaccs ts with(nolock) on p.SubAcc_ID = ts.id
              inner join QORT_DDM.dbo.DDM_fn_DateRange( @DateStart, @DateEnd, 0 ) dt on dt.OperDate = p.PhaseDate
             where 1 = 1
                   and p.Enabled = 0
                   and p.PC_Const not in ( 18 ) 
    end
