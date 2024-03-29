CREATE procedure dbo.DDM_PhaseCancel @ExternalID varchar(255)
                                  , @Trade_SID  numeric(18, 0)
                                  , @msg        nvarchar(4000) output
as
    begin
        declare @BackID   varchar(64)
              , @SystemID bigint
              , @RowID    float
              , @IEC_ID   float
        select @SystemID = p.SystemID
             , @BackID = p.BackID
          from QORT_TDB_PROD..Phases p with(nolock)
         where p.Trade_SID = @Trade_SID
               and isnull(p.IsCanceled, 'n') = 'n'
               and patindex('%' + @ExternalID + '%', p.BackID) + patindex('%' + @ExternalID + '%', p.InfoSource) > 0
               and exists( select 1
                             from QORT_DB_PROD.dbo.Phases p2 with(nolock)
                            where p2.id = p.SystemID
                                  and isnull(p2.IsCanceled, 'n') = 'n' )
        if isnull(@SystemID, 0) = 0 /* target phase not found */
            begin
                select @msg = @msg + '; 000. Phase not found for External Id = ' + @ExternalID + ' and Trade SID = ' + convert(varchar(20), @Trade_SID)
                return
        end
        while @RowID is null
            begin
                exec QORT_TDB_PROD..P_GenFloatValue @RowID output
                                                  , 'phasecancelations_table'
            end
        insert into QORT_TDB_PROD..PhaseCancelations
        ( id
        , SystemID
        , InfoSource
        , BackID
        , IsProcessed
        , IsExecByComm
        )
        values
        ( @RowID
        , @SystemID
        , 'BackOffice'
        , @BackID
        , 1
        , 'Y'
        )
        if @@ROWCOUNT > 0
            begin
                exec QORT_DDM..DDM_ImportExecutionCommands @TC_Const = 8
                                                         , @Oper_ID = @RowID
                                                         , @Comment = @BackID
                                                         , @SystemName = 'DDM_PhaseCancel'
                select @msg = @msg + '; 000. Canceled Phase SystemId = ' + convert(varchar(20), @SystemID) + ' BackID = ' + @BackID
        end
             else
            begin
                select @msg = @msg + '; 500. Insert into QORT_TDB_PROD..PhaseCancelations was failed for Phase SystemId = ' + convert(varchar(20), @SystemID) + ' BackID = ' + @BackID
                return
        end
    end
