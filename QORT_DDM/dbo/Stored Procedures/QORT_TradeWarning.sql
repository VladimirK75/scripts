CREATE procedure [dbo].[QORT_TradeWarning]
as
    begin
        set nocount on;
        declare @tdate int
        set @tdate = ( select session_date
                         from QORT_DB_PROD..[Session] with(nolock) )
        if exists( select tw.Trade_ID
                     from QORT_DB_PROD..TradeWarnings tw with(nolock)
                     join QORT_DB_PROD..trades t with(nolock) on tw.Trade_ID = t.id
                    where 1 = 1
                          and tw.AccountCode in ( 'L22+00000F10', 'L05+00000F01', 'NCC+00090002' )
                          and tw.ClientCode = 'RB'
                          and tw.QuikClassCode in ( 'TADM', 'SADM' )
                   and tw.TradeDate = @tdate
                   and t.IsProcessed = 'n'
                   and t.IsDraft = 'n' )
            begin
                if object_id('tempdb..#tmpTradeID') is not null
                    drop table #tmpTradeID
                select tw.Trade_ID
                into #tmpTradeID
                  from QORT_DB_PROD..TradeWarnings tw with(nolock)
                  join QORT_DB_PROD..trades t with(nolock) on tw.Trade_ID = t.id
                 where 1 = 1
                       and tw.AccountCode in ( 'L22+00000F10', 'L05+00000F01', 'NCC+00090002' )
                       and tw.ClientCode = 'RB'
                       and tw.QuikClassCode in ( 'TADM', 'SADM' )
                and tw.TradeDate = @tdate
                and t.IsProcessed = 'n'
                and t.IsDraft = 'n'
                and t.IsRepo2 = 'n'
                insert into QORT_TDB_PROD.dbo.ImportTrades
                ( id
                , TradeNum
                , TradeDate
                , TT_Const
                , TSSection_Name
                , BuySell
                  /*,[Security_Code]*/
                , SubAcc_Code
                , Comment
                , PutAccount_ExportCode
                , PayAccount_ExportCode
                , IsProcessed
                , ET_Const
                )
                select id = -1
                     , t1.TradeNum
                     , t1.TradeDate
                     , t1.TT_Const
                     , TSSection_Name = ( select name
                                            from QORT_DB_PROD..TSSections with(nolock)
                                           where id = t1.TSSection_ID )
                     , t1.BuySell
                     , SubAcc_Code = case tw.AccountCode
                                         when 'L22+00000F10' then 'RB0331'
                                         when 'L05+00000F01' then 'UMG873'
                                         when 'NCC+00090002' then 'RESEC'
                                     end
                     , Comment = case tw.AccountCode
                                     when 'L22+00000F10' then 'RB0331/'
                                     when 'L05+00000F01' then 'UMG873/'
                                 end
                     , PutAccount_ExportCode = case tw.AccountCode
                                                   when 'L22+00000F10' then 'L22+00000F10'
                                                   when 'L05+00000F01' then 'NDCEM_DEP_RENBR_21C.27'
                                                   when 'NCC+00090002' then 'NCC+00090002'
                                               end
                     , PayAccount_ExportCode = case tw.AccountCode
                                                   when 'L22+00000F10' then 'NKCKB_ANY_RENBR_TE.34'
                                                   when 'L05+00000F01' then 'NKCKB_ANY_RENBR_TE.04'
                                                   when 'NCC+00090002' then 'NCC+00090002'
                                               end
                     , IsProcessed = 1
                     , ET_Const = 4
                  from QORT_DB_PROD..Trades t1 with(nolock)
                  join QORT_DB_PROD..TradeWarnings tw with(nolock) on t1.id = tw.Trade_ID
                 where 1 = 1
                       and t1.ID in( select Trade_ID
                                       from #tmpTradeID )
                waitfor delay '00:01'
                declare @xml nvarchar(max)
                declare @body nvarchar(max)
                set @xml = cast(( select ''
                                       , cast(Modified_System_ID as int) as 'td'
                                       , ''
                                       , IsProcessed as                     'td'
                                       , ''
                                       , ErrorLog as                        'td'
                                    from QORT_TDB_PROD..ImportTrades
                                   where Modified_System_ID in( select Trade_ID
                                                                  from #tmpTradeID )
                                  order by 1 for xml path('tr'), elements ) as nvarchar(max))
                set @body = '<html><body><H3>В TradeWarnings обнаружены необработанные сделки</H3><H4>Результат обработки:</H4>
<table border = 1> 
<tr>
<th> Modified_System_ID </th> <th> IsProcessed </th> <th> ErrorLog </th></tr>'
                set @body = concat(@body , @xml , '</table></body></html>')
                exec msdb.dbo.sp_send_dbmail @profile_name = 'QORTMonitoring'
                                           , @body = @body
                                           , @body_format = 'HTML'
                                           , @recipients = 'ITSupportBackQORT@rencap.com;ExceptionManagementTeamMoscow@rencap.com'
                                           , @subject = 'QORT Monitoring TradeWarnings handler';
                drop table if exists #tmpTradeID
        end
    end
