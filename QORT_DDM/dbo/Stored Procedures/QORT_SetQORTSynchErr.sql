CREATE procedure dbo.QORT_SetQORTSynchErr
with execute as caller
as
    begin
        declare @TextQuery varchar(max)
              , @ExecSQL   varchar(max)
        declare tmp_cur_SetQORTSynchErr cursor local
        for select SQL_Query = concat('update QORT_TDB_PROD.dbo.', Section, ' with(rowlock) set IsProcessed=97 where id=', ID, ';')
              from QORT_DDM.dbo.Get_TDB_Error_List()
             where Reprocessed = 1
        open tmp_cur_SetQORTSynchErr
        fetch next from tmp_cur_SetQORTSynchErr into @TextQuery
        while @@FETCH_STATUS = 0
            begin
                exec (@TextQuery)
                fetch next from tmp_cur_SetQORTSynchErr into @TextQuery
            end
        close tmp_cur_SetQORTSynchErr
        deallocate tmp_cur_SetQORTSynchErr
        declare tmp_cur_SetQORTSynchErr cursor local
        for select SQL_Query = concat('update QORT_TDB_PROD.dbo.', Section, ' with(rowlock) set IsProcessed=1 where id=', ID, ';')
              from QORT_DDM.dbo.Get_TDB_Error_List()
             where Reprocessed = 0
                   and Section = 'Coupons'
        open tmp_cur_SetQORTSynchErr
        fetch next from tmp_cur_SetQORTSynchErr into @TextQuery
        while @@FETCH_STATUS = 0
            begin
                exec (@TextQuery)
                fetch next from tmp_cur_SetQORTSynchErr into @TextQuery
            end
        close tmp_cur_SetQORTSynchErr
        deallocate tmp_cur_SetQORTSynchErr
        select @TextQuery = 'update pc set pc.IsProcessed=97 from QORT_TDB_PROD..PhaseCancelations pc with(nolock) where pc.IsProcessed >=4 and pc.ErrorLog = ''The record Phases not found'''
        exec (@TextQuery)
    end
