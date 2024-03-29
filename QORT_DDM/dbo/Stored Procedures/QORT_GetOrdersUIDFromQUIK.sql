CREATE   procedure [dbo].[QORT_GetOrdersUIDFromQUIK]
as
    begin
        set nocount on
        declare @DateFrom   date
              , @DateTo     date
              , @TimeStamp  varchar(1024)
              , @Msg        varchar(4000)
              , @QUIK       int
              , @SQL_Query  varchar(max)
              , @SQL_Update varchar(max)
              , @subject    varchar(256)
              , @body       nvarchar(max)
              , @body_table nvarchar(max)
              , @body_sign  nvarchar(max)
              , @recipients varchar(256)  = 'ITSupportBackQORT@rencap.com'
              , @Recipcopy  varchar(256)  = 'vkruglov@rencap.com;TReshetnikova@rencap.com'
        declare @ServerQUIK table
        ( id           int identity(1, 1)
        , LinkedServer varchar(32) )
        select @DateFrom = dateadd(week, -2, getdate())
             , @DateTo = getdate()
        while @DateFrom < @DateTo
            begin
                insert into @ServerQUIK( LinkedServer )
            values( 'QUIK_50' ), ( 'QUIK_60' ), ( 'QUIK_62' ), ( 'QUIK_65' ), ( 'QUIK_70' ), ( 'QUIK_101' ), ('QUIK_04'), ('QUIK_61')
                set @SQL_Query =  N'update tmp_o
   set tmp_o.TraderUID = t.user_id
     , tmp_o.status = 1
  from #tmp_Orders tmp_o
  inner join LINKEDSERVER.QUIK_DB.dbo.TRANS as t with(nolock) 
   on  tmp_o.OrderNum  = t.ts_number
  and len(t.TRANS_DATA) > 30
  and t.user_id >= 1
  and convert(date, SERVER_TIME, 120) = ''' + format(@DateFrom, 'yyyy-MM-dd') + '''
 where 1 = 1
       and tmp_o.TraderUID = 0
	   and tmp_o.status = 0
	   
update tmp_o
   set tmp_o.TraderUID = t.user_id
     , tmp_o.status = 1
  from #tmp_Orders tmp_o
  inner join LINKEDSERVER.QUIK_DB.dbo.TRANS as t with(nolock) 
   on  tmp_o.OrderNum * iif(len(tmp_o.OrderNum) < 19, 10,1) = t.ts_number
  and len(t.TRANS_DATA) > 30
  and t.user_id >= 1
  and convert(date, SERVER_TIME, 120) = ''' + format(@DateFrom, 'yyyy-MM-dd') + '''
 where 1 = 1
       and tmp_o.TraderUID = 0
	   and tmp_o.status = 0'
                set @TimeStamp = concat('RENBR-1: Поиск UID=0 за ', format(@DateFrom, 'yyyy-MM-dd'), ' at ', format(getdate(), 'HH:mm:ss.fff'))
                select @Msg = concat(@Msg, @TimeStamp, char(10), char(13))
                raiserror(N'%s', 10, 1, @TimeStamp) with nowait
                drop table if exists #tmp_Orders
                create table #tmp_Orders
                ( OrderNum  bigint
                , OrderDate int
                , TraderUID int
                , id        float
                , status    bit )
                insert into #tmp_Orders
                ( OrderNum
                , OrderDate
                , TraderUID
                , id
                , status
                )
                select o.OrderNum
                     , o.OrderDate
                     , o.TraderUID
                     , o.id
                     , status = 0
                  from QORT_DB_PROD.dbo.orders o with (nolock, index = PK_Orders)
                 where 1 = 1
                       and o.orderdate = format(@DateFrom, 'yyyyMMdd')
                       and o.TraderUID = 0
                set @TimeStamp = concat('RENBR-2: Поиск UID в QUIK at ', format(getdate(), 'HH:mm:ss.fff'))
                select @Msg = concat(@Msg, @TimeStamp, char(10), char(13))
                raiserror(N'%s', 10, 1, @TimeStamp) with nowait
/* 
        update tmp_o
           set tmp_o.TraderUID = t.uid
             , tmp_o.status = 1
          from #tmp_Orders tmp_o
          inner join QUIK_73.QExport.dbo.Orders_History t with(nolock) on t.OrderNum = tmp_o.OrderNum
                                                                          and convert(date, t.Tradedate, 120) = @DateFrom
                                                                          and t.uid != tmp_o.TraderUID
*/
                while( select count(1)
                         from @ServerQUIK ) > 0
                    begin
                        select @QUIK = min(id)
                          from @ServerQUIK
                        select @SQL_Update = replace(@SQL_Query, 'LINKEDSERVER', sq.LinkedServer)
                             , @TimeStamp = concat('RENBR-2: Проверка UID из ', sq.LinkedServer, ' at ', format(getdate(), 'HH:mm:ss.fff'))
                          from @ServerQUIK sq
                         where sq.id = @QUIK
                        select @Msg = concat(@Msg, @TimeStamp, char(10), char(13))
                        raiserror(N'%s', 10, 1, @TimeStamp) with nowait
                        exec (@SQL_Update)
                        delete sq
                          from @ServerQUIK sq
                         where sq.id = @QUIK
                    end
                set @TimeStamp = concat('RENBR-3: Очистка UID=0  at ', format(getdate(), 'HH:mm:ss.fff'))
                select @Msg = concat(@Msg, @TimeStamp, char(10), char(13))
                raiserror(N'%s', 10, 1, @TimeStamp) with nowait
                delete tmp_o
                  from #tmp_Orders tmp_o
                 where tmp_o.status = 0
                set @TimeStamp = concat('RENBR-4: установка UID на Orders за ', format(@DateFrom, 'yyyy-MM-dd'), ' at ', format(getdate(), 'HH:mm:ss.fff'))
                select @Msg = concat(@Msg, @TimeStamp, char(10), char(13))
                raiserror(N'%s', 10, 1, @TimeStamp) with nowait
                update o
                   set o.TraderUID = t.TraderUID
                  from QORT_DB_PROD.dbo.orders o with(rowlock)
                  inner join #tmp_Orders t on o.id = t.id
                                              and o.orderdate = t.orderdate
                 where 1 = 1
                set @TimeStamp = concat('RENBR-5: установка UID на Trades за ', format(@DateFrom, 'yyyy-MM-dd'), ' at ', format(getdate(), 'HH:mm:ss.fff'))
                select @Msg = concat(@Msg, @TimeStamp, char(10), char(13))
                raiserror(N'%s', 10, 1, @TimeStamp) with nowait
                alter table QORT_DB_PROD.dbo.Trades disable trigger T_ON_DISABLE_Trades
                update trd
                   set trd.TraderUID = o.TraderUID
                  from QORT_DB_PROD.dbo.Trades trd with (nolock, index = PK_Trades)
                  inner join QORT_DB_PROD.dbo.orders o with (nolock, index = PK_Orders) on o.OrderNum = trd.OrderNum
                                                                                           and o.orderdate = trd.TradeDate
                                                                                           and o.TraderUID != trd.TraderUID
                 where 1 = 1
                       and trd.TradeDate = format(@DateFrom, 'yyyyMMdd')
                alter table QORT_DB_PROD.dbo.Trades enable trigger T_ON_DISABLE_Trades
                select @subject = concat('QORT RENBR Orders (UID) - records for ', format(@DateFrom, 'yyyy-MM-dd'))
                select @body = '<html><body><head>
<style type="text/css">
.myTable {border-collapse:collapse;}
.myTable td, .myTable th {padding: 3px; border: 1px solid #000}
.myTable th {background-color: #C0C0C0; text-align: center; font-family: "Arial", Sans-serif; font-size: 13px}
.myTable td {font-family: "Arial", Sans-serif; font-size: 12px; text-align: center}
p {margin: 4px 0px 4px; font-family: "Arial", Sans-serif; font-size: 14px; color: #006600}
</style>
</head>
'
                select @body_table = replace(replace(cast(( select td = concat(OrderDate, '</td> <td>', TraderUID, '</td> <td>', NN)
                                                              from( select OrderDate
                                                                         , TraderUID
																		 , NN = count(1)
                                                                      from #tmp_Orders
                                                                     group by OrderDate, TraderUID ) tt
                                                            order by OrderDate for xml path('tr'), type ) as varchar(max)), '&lt;', '<'), '&gt;', '>')
                if isnull(@body_table, '') <> ''
                    begin
                        set @body_table = concat('<table class="myTable" width=450px>' + '<tr><th>Trade Date</th><th>TraderUID</th><th>Count</th></tr>', replace(replace(@body_table, '&lt;', '<'), '&gt;', '>'), '</table>')
                end
                     else
                    set @body_table = concat('<p style="font-size: 12px;color:#A52A2A">There are no Orders without TraderUID in QUIK to setup in QORT fot last month till ', format(getdate(), 'yyyy-MM-dd'), '</p>')
                select @body_sign = '<hr />
<p style="font-size: 9px">
Server:&nbsp; S-MSK01-SQL08\QORT_RENBR<br /> 
Job:&nbsp; Update_TraderUID_Orders.Subplan_1<br />
Step:&nbsp;Daily Orders checkup<br />
Author: vkruglov@rencap.com
</p> '
                select @body = concat(@body, @body_table, @body_sign, '</body></html>')
                select tt.OrderDate
                     , tt.TraderUID
                     , CountOrders = count(tt.OrderNum)
                into ##Mail_Orders
                  from #tmp_Orders tt
                 group by tt.OrderDate
                        , tt.TraderUID
                if exists( select 1
                             from #tmp_Orders )
                    begin
                        exec msdb.dbo.sp_send_dbmail @profile_name = 'QORTMonitoring'
                                                   , @recipients = @recipients
                                                   , @copy_recipients = @Recipcopy
                                                   , @subject = @subject
                                                   , @body = @body
                                                   , @body_format = 'HTML'
                                                   , @query = 'select * from ##Mail_Orders'
                                                   , @attach_query_result_as_file = 1
                                                   , @query_result_separator = ','
                                                   , @query_result_no_padding = 1
                end
                drop table if exists #tmp_Orders
                drop table if exists ##Mail_Orders
                select @DateFrom = dateadd(dd, 1, @DateFrom)
            end
    end
