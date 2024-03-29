CREATE   procedure [dbo].[DDM_ImportExecutionCommands] 
                 @TC_Const   smallint
               , @Oper_ID    float(53)
               , @Comment    varchar(256)
               , @SystemName varchar(32)
			   , @Priority int = null
as
    begin
    set nocount on
        declare 
               @IEC_ID float
        set @IEC_ID = null
        while nullif(@IEC_ID, -1) is null
            begin
                exec QORT_TDB_PROD.dbo.P_GenFloatValue @IEC_ID output
                                                     , 'ImportExecutionCommands_table'
            end
		if @TC_Const <> 8
		set @Priority= (case
							when @TC_Const in (18,19) then 5
							when @TC_Const in (1) then 4
							when @TC_Const in (11) then 3
							when @TC_Const in (7) then 2
							when @TC_Const in (5,16) then 1
						end)

        insert into QORT_TDB_PROD.dbo.ImportExecutionCommands ( id
                                                              , TC_Const
                                                              , Oper_ID
                                                              , IsProcessed
                                                              , Comment
															  , [Priority] ) 
        values ( @IEC_ID
               , @TC_Const
               , @Oper_ID
               , 1
               , @SystemName + ' ' + @Comment+' at '+format(getdate(), 'yyyy-MM-dd HH:mm:ss.ffff') 
			   , @Priority) 
        return 0
    end
