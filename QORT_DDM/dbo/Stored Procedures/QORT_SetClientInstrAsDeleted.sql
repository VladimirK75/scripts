CREATE procedure QORT_SetClientInstrAsDeleted @ClientIntsrNum int
as
    begin
        set nocount on;
        drop table if exists #tmp_clientInstr
        declare @TimeStamp    varchar(1024)
              , @InstrDateMin int
              , @InstrDateMax int
              , @Msg          varchar(4000)
        set @TimeStamp = concat('RENBR: START at ', format(getdate(), 'HH:mm:ss.fff'))
        select @Msg = concat(@Msg, @TimeStamp, char(10), char(13))
        raiserror(N'%s', 10, 1, @TimeStamp) with nowait
        create table #tmp_clientInstr
        ( InstNum   int
        , InstrDate int )
        insert into #tmp_clientInstr
        select ci.InstrNum
             , ci.[Date]
          from QORT_DB_PROD..ClientInstr ci with(nolock)
         where ci.InstrNum = @ClientIntsrNum
               and ci.Enabled = 0
        select @InstrDateMin = min(tci.InstrDate)
             , @InstrDateMax = max(tci.InstrDate)
          from #tmp_clientInstr tci
        if @InstrDateMin is not null
            begin	
                /* 1 – отвязать от корректировок, к которым они привязаны  */
                update cp
                   set cp.ClientInstr_ID = -1
                  from QORT_DB_PROD..CorrectPositions cp with(nolock)
                 where cp.ClientInstr_ID in( select ci.id
                                               from QORT_DB_PROD..ClientInstr ci with(nolock)
                                               inner join #tmp_clientInstr tci on tci.InstNum = ci.InstrNum )
                set @TimeStamp = concat('RENBR: "1 – отвязать от корректировок, к которым они привязаны" at ', format(getdate(), 'HH:mm:ss.fff'))
                select @Msg = concat(@Msg, @TimeStamp, char(10), char(13))
                raiserror(N'%s', 10, 1, @TimeStamp) with nowait
                /* 2 -  удалить их из таблицы Регистр поручений клиентов */
                alter table QORT_DB_PROD.dbo.ClientInstr disable trigger T_ON_DISABLE_ClientInstr
                update ci
                   set ci.Enabled = ci.id
                  from QORT_DB_PROD..ClientInstr ci with(nolock)
                  inner join #tmp_clientInstr tci on tci.InstNum = ci.InstrNum
                set @TimeStamp = concat('RENBR: "2 -  удалить их из таблицы Регистр поручений клиентов" at ', format(getdate(), 'HH:mm:ss.fff'))
                select @Msg = concat(@Msg, @TimeStamp, char(10), char(13))
                raiserror(N'%s', 10, 1, @TimeStamp) with nowait
                alter table QORT_DB_PROD.dbo.ClientInstr enable trigger T_ON_DISABLE_ClientInstr
                /* 3 – запустить нумерацию операций за период с 20/05/2019 по 31/12/2019. */
                exec QORT_DB_PROD.dbo.R_RO_RenumberClientInstr_7 @InstrDateMin
                                                               , @InstrDateMax
                set @TimeStamp = concat('RENBR: "3 – запустить нумерацию операций за период с ', @InstrDateMin, ' по ', @InstrDateMax, '" at ', format(getdate(), 'HH:mm:ss.fff'))
                select @Msg = concat(@Msg, @TimeStamp, char(10), char(13))
                raiserror(N'%s', 10, 1, @TimeStamp) with nowait
        end
        set @TimeStamp = concat('RENBR: FINISH at ', format(getdate(), 'HH:mm:ss.fff'))
        select @Msg = concat(@Msg, @TimeStamp, char(10), char(13))
        raiserror(N'%s', 10, 1, @TimeStamp) with nowait
        select Msg = @Msg
    end
