CREATE procedure [dbo].[QORT_DDM_GetTransfersData] 
                @TransferID varchar(max)
as
    begin
        declare 
               @Delimiter char(1)  = ','
             , @pos       smallint
             , @b         smallint
        drop table if exists #tmp_Transfer
        create table #tmp_Transfer ( 
                     TransferID varchar(32) ) 
        drop table if exists #tmp_TransferReport
        create table #tmp_TransferReport ( 
                     TransferID         varchar(32)
                   , SettlementID       bigint
                   , EventDateTime      datetime
                   , SettlementDetailID bigint null
                   , Section            varchar(32)
                   , BackID             varchar(32) null
                   , DDM_Rule           varchar(8) null
                   , DDM_Status         varchar(255) null
                   , DDM_Message        varchar(255) null
                   , TDB_Message        varchar(255) null
                   , DB_Message         varchar(255) null
                   , ExecDateTime       datetime 
				   , OperationType		varchar(255) null
				   , ChargeType			varchar(255) null )

        create index T_Section on #tmp_TransferReport ( Section ) 
        create index T_Section_BackID on #tmp_TransferReport ( Section, BackID ) 
        while charindex(',', @TransferID) > 0
            begin
                select @pos = charindex(@Delimiter, @TransferID)
                insert into #tmp_Transfer ( TransferID ) 
                select ltrim(rtrim(substring(@TransferID, 1, @pos - 1)))
                select @TransferID = ltrim(rtrim(substring(@TransferID, @pos + 1, len(@TransferID) - @pos)))
            end
        insert into #tmp_Transfer ( TransferID ) 
        select @TransferID
        insert into #tmp_TransferReport ( TransferID
                                        , SettlementID
                                        , EventDateTime
                                        , SettlementDetailID
                                        , Section
                                        , BackID
                                        , DDM_Rule
                                        , DDM_Status
                                        , DDM_Message 
										, OperationType
										, ChargeType ) 
        select its.ExternalID
             , SettlementID = its.ID
             , its.EventDateTime
             , SettlementDetailID = itsd.ID
             , Section = iif(dr.TradeEvent in('CashSettlement', 'SecuritySettlement')
                             and dr.SettlementDate is null, 'UpdateTradeAccount', dr.TradeEvent)
             , BackID = concat(its.ExternalTradeID, '/', its.ExternalID)
             , DDM_Rule = concat('TRD_', dr.RuleID)
             , DDM_Status = its.DdmStatus
             , DDM_Message = itsd.ProcessingMessage
			 , OperationType = its.OperationType
			 , ChargeType = itsd.ChargeType
          from QORT_DDM..ImportedTradeSettlement its with(nolock)
          inner join #tmp_Transfer tt on tt.TransferID = its.ExternalID
          inner join QORT_DDM..ImportedTradeSettlementDetails itsd with(nolock) on its.ID = itsd.SettlementID
          outer apply QORT_DDM..DDM_GetImportTrade_Rule(itsd.ID) dr
         where 1 = 1
               and not exists (select 1
                                 from QORT_DDM..ImportedTradeSettlement its2 with(nolock)
                                 inner join QORT_DDM..ImportedTradeSettlementDetails itsd2 with(nolock) on itsd2.SettlementID = its2.id
                                where its2.ExternalID = its.ExternalID
                                      and its2.id > its.id)
         order by its.EventDateTime
        update #tmp_TransferReport
        set #tmp_TransferReport.DDM_Status = its.DdmStatus
          from #tmp_TransferReport
          inner join QORT_DDM..ImportedTradeSettlement its with(nolock) on its.ExternalID = #tmp_TransferReport.TransferID
                                                                           and not exists (select 1
                                                                                             from QORT_DDM..ImportedTradeSettlement its2 with(nolock)
                                                                                            where its2.ExternalID = its.ExternalID
                                                                                                  and its2.id > its.id) 
        update #tmp_TransferReport
        set #tmp_TransferReport.SettlementID = its.ID
          , #tmp_TransferReport.SettlementDetailID = itsd.ID
          , #tmp_TransferReport.Section = iif(dr.TradeEvent in('CashSettlement', 'SecuritySettlement')
                                              and dr.SettlementDate is null, 'UpdateTradeAccount', dr.TradeEvent)
          , #tmp_TransferReport.DDM_Message = itsd.ProcessingMessage
          , #tmp_TransferReport.DDM_Rule = concat('TRD_', dr.RuleID)
		  , #tmp_TransferReport.OperationType = its.OperationType
		  , #tmp_TransferReport.ChargeType = itsd.ChargeType
          from #tmp_TransferReport
          inner join QORT_DDM..ImportedTradeSettlement its with(nolock) on its.ExternalID = #tmp_TransferReport.TransferID
          inner join QORT_DDM..ImportedTradeSettlementDetails itsd with(nolock) on its.ID = itsd.SettlementID
                                                                                   and itsd.ProcessingState in ('Created', 'Canceled') 
          outer apply QORT_DDM..DDM_GetImportTrade_Rule(itsd.ID) dr
         where 1 = 1
               and not exists (select 1
                                 from QORT_DDM..ImportedTradeSettlement its2 with(nolock)
                                 inner join QORT_DDM..ImportedTradeSettlementDetails itsd2 with(nolock) on its2.ID = itsd2.SettlementID
                                                                                                           and itsd2.ProcessingState in ('Created', 'Canceled')
                                where its2.ExternalID = its.ExternalID
                                      and its2.id > its.id)
        /*AddCommission*/ 
        update #tmp_TransferReport
        set #tmp_TransferReport.TDB_Message = concat(iif(left(#tmp_TransferReport.DDM_Status, 4) = 'Canc', 'Canc:', 'Add:'),
                                                                                                                          case
                                                                                                                               when ibcot.IsProcessed = 1 then 'New'
                                                                                                                               when ibcot.IsProcessed = 1 then 'Started'
                                                                                                                               when ibcot.IsProcessed = 3 then 'Done'
                                                                                                                             else concat('Err: ', ibcot.ErrorLog)
                                                                                                                          end)
          , #tmp_TransferReport.ExecDateTime = iec.ExecutionDateTime
          , #tmp_TransferReport.DB_Message = iif(left(#tmp_TransferReport.DDM_Status, 4) = 'Canc'
                                                 and ibcot.IsProcessed < 4, 'Blank', 'Real')
          from #tmp_TransferReport
          inner join QORT_TDB_PROD..ImportBlockCommissionOnTrades ibcot with(nolock) on ibcot.BackID like concat(#tmp_TransferReport.TransferID, '%')
                                                                                        and ibcot.ET_Const = iif(left(#tmp_TransferReport.DDM_Status, 4) = 'Canc', 8, 2)
          inner join QORT_TDB_PROD..ImportExecutionCommands iec with(nolock) on iec.Oper_ID = ibcot.id
                                                                                and iec.TC_Const = 11
         where 1 = 1
               and #tmp_TransferReport.Section = 'AddCommission'
               and iec.ExecutionDateTime >= #tmp_TransferReport.EventDateTime
        update #tmp_TransferReport
        set #tmp_TransferReport.DB_Message = iif(bcot.id is null, 'Blank', 'Real')
          from #tmp_TransferReport
          inner join QORT_DB_PROD..BlockCommissionOnTrades bcot with(nolock) on bcot.BackID like concat(#tmp_TransferReport.TransferID, '%')
         where 1 = 1
               and #tmp_TransferReport.Section = 'AddCommission'
        /*UpdateTradeAccount */
        /* найти счет */
        update #tmp_TransferReport
        set #tmp_TransferReport.TDB_Message = concat(iif(left(#tmp_TransferReport.DDM_Status, 4) = 'Canc', 'Canc:', 'Add:'),
                                                                                                                          case
                                                                                                                               when it.IsProcessed = 1 then 'New'
                                                                                                                               when it.IsProcessed = 1 then 'Started'
                                                                                                                               when it.IsProcessed = 3 then 'Done'
                                                                                                                             else concat('Err: ', it.ErrorLog)
                                                                                                                          end)
          , #tmp_TransferReport.ExecDateTime = iec.ExecutionDateTime
          , #tmp_TransferReport.DB_Message = iif(left(#tmp_TransferReport.DDM_Status, 4) = 'Canc'
                                                 and it.IsProcessed < 4, 'Blank', 'Real')
          from QORT_TDB_PROD..ImportTrades it with(nolock)
          inner join QORT_TDB_PROD..ImportExecutionCommands iec with(nolock) on iec.Oper_ID = it.id
                                                                                and iec.TC_Const = 1
          inner join QORT_CACHE_DB..trade_transfers tt with(nolock) on tt.tradeid = it.TradeNum
                                                                       and iif(it.PutAccount_ExportCode = tt.put_account, 1, 0) + iif(it.PayAccount_ExportCode = tt.pay_account, 1, 0) > 0
         where 1 = 1
               and #tmp_TransferReport.Section in ('UpdateTradeAccount', 'CashSettlement', 'SecuritySettlement')
               and cast(#tmp_TransferReport.TransferID as int) = tt.transferid
               and not exists (select 1
                                 from QORT_TDB_PROD..ImportTrades it2 with(nolock)
                                where it2.TradeNum = it.TradeNum
                                      and it2.id > it.id)
        /*CashSettlement*/        /*SecuritySettlement*/
        /* найти этап поставки */        /* найти этап оплаты */ 
        update #tmp_TransferReport
        set #tmp_TransferReport.TDB_Message = concat(iif(left(#tmp_TransferReport.DDM_Status, 4) = 'Canc', 'Canc:', 'Add:'),
                                                                                                                          case
                                                                                                                               when p.IsProcessed = 1 then 'New'
                                                                                                                               when p.IsProcessed = 1 then 'Started'
                                                                                                                               when p.IsProcessed = 3 then 'Done'
                                                                                                                             else concat('Err: ', p.ErrorLog)
                                                                                                                          end)
          , #tmp_TransferReport.ExecDateTime = iec.ExecutionDateTime
          , #tmp_TransferReport.DB_Message = iif(left(#tmp_TransferReport.DDM_Status, 4) = 'Canc'
                                                 and p.IsProcessed < 4, 'Blank', 'Real')
          from #tmp_TransferReport
          inner join QORT_TDB_PROD..Phases p with(nolock) on p.BackID like #tmp_TransferReport.TransferID + '/%'
                                                             and p.[Date] > 20171000
          inner join QORT_TDB_PROD..ImportExecutionCommands iec with(nolock) on iec.Oper_ID = p.id
                                                                                and iec.TC_Const = 7
         where 1 = 1
               and #tmp_TransferReport.Section in ('UpdateTradeAccount','CashSettlement', 'SecuritySettlement') 
        update #tmp_TransferReport
        set #tmp_TransferReport.TDB_Message = concat(iif(left(#tmp_TransferReport.DDM_Status, 4) = 'Canc', 'Canc:', 'Add:'),
                                                                                                                          case
                                                                                                                               when p.IsProcessed = 1 then 'New'
                                                                                                                               when p.IsProcessed = 1 then 'Started'
                                                                                                                               when p.IsProcessed = 3 then 'Done'
                                                                                                                             else concat('Err: ', p.ErrorLog)
                                                                                                                          end)
          , #tmp_TransferReport.ExecDateTime = iec.ExecutionDateTime
          , #tmp_TransferReport.DB_Message = iif(left(#tmp_TransferReport.DDM_Status, 4) = 'Canc'
                                                 and p.IsProcessed < 4, 'Blank', 'Real')
          from #tmp_TransferReport
          inner join QORT_TDB_PROD..PhaseCancelations p with(nolock) on p.BackID like #tmp_TransferReport.TransferID + '/%'
          inner join QORT_TDB_PROD..ImportExecutionCommands iec with(nolock) on iec.Oper_ID = p.id
                                                                                and iec.TC_Const = 7
         where 1 = 1
               and #tmp_TransferReport.Section in ('UpdateTradeAccount','CashSettlement', 'SecuritySettlement') 
        update #tmp_TransferReport
        set #tmp_TransferReport.DB_Message = iif(p.id is null, 'Blank', iif(p.IsCanceled = 'y', 'Canc', 'Real'))
          from #tmp_TransferReport with(nolock)
          left join QORT_DB_PROD..Phases p with (nolock, index=I_Phases_BackID) on p.BackID like #tmp_TransferReport.TransferID + '/%'
                                                         and p.PhaseDate > 20171000
         where 1 = 1
               and #tmp_TransferReport.Section in ('UpdateTradeAccount','CashSettlement', 'SecuritySettlement') 
        /* Correct Position */
        insert into #tmp_TransferReport ( TransferID
                                        , SettlementID
                                        , EventDateTime
                                        , SettlementDetailID
                                        , Section
                                        , BackID
                                        , DDM_Rule
                                        , DDM_Status
                                        , DDM_Message 
										, OperationType
										, ChargeType ) 
        select its.ExternalID
             , SettlementID = its.ID
             , its.EventDateTime
             , SettlementDetailID = itsd.ID
             , Section = 'CorrectSettlement'
             , BackID = concat(its.ExternalTransactionID, '/', its.ExternalID)
             , DDM_Rule = '#'
             , DDM_Status = concat(its.DdmStatus, iif(its.ActualSettlementDate is not null, ':Settled', ':Plan'))
             , DDM_Message = itsd.ProcessingMessage
			 , OperationType = its.OperationType
			 , ChargeType = itsd.ChargeType
          from QORT_DDM..ImportedTranSettlement its with(nolock)
          inner join #tmp_Transfer tt on tt.TransferID = its.ExternalID
          inner join QORT_DDM..ImportedTranSettlementDetails itsd with(nolock) on its.ID = itsd.SettlementID
                                                                                  and itsd.ProcessingState <> 'Skipped'
         where 1 = 1
               and not exists (select 1
                                 from QORT_DDM..ImportedTranSettlement its2 with(nolock)
                                 inner join QORT_DDM..ImportedTranSettlementDetails itsd2 with(nolock) on itsd2.SettlementID = its2.id
                                                                                                          and itsd2.ProcessingState <> 'Skipped'
                                where its2.ExternalID = its.ExternalID
                                      and its2.id > its.id)
         order by its.EventDateTime
        update #tmp_TransferReport
        set DDM_Rule = concat('CP_', dr.RuleID)
          from #tmp_TransferReport
          outer apply QORT_DDM..DDM_GetImportTransactions_Rule(#tmp_TransferReport.SettlementDetailID) dr
         where 1 = 1
               and Section = 'CorrectSettlement'
        update #tmp_TransferReport
        set #tmp_TransferReport.DDM_Status = concat(its.DdmStatus, iif(its.ActualSettlementDate is not null, ':Settled', ':Plan'))
          from #tmp_TransferReport
          inner join QORT_DDM..ImportedTranSettlement its with(nolock) on its.ExternalID = #tmp_TransferReport.TransferID
         where 1 = 1
               and #tmp_TransferReport.Section = 'CorrectSettlement'
               and not exists (select 1
                                 from QORT_DDM..ImportedTranSettlement its2 with(nolock)
                                where its2.ExternalID = its.ExternalID
                                      and its2.ProcessingState = 'Processed'
                                      and its2.id > its.id) 
        update #tmp_TransferReport
        set #tmp_TransferReport.SettlementID = its.ID
          , #tmp_TransferReport.SettlementDetailID = itsd.ID
          , #tmp_TransferReport.EventDateTime = its.EventDateTime
          , #tmp_TransferReport.DDM_Message = itsd.ProcessingMessage
          , #tmp_TransferReport.DDM_Rule = '#'
		  , #tmp_TransferReport.OperationType = its.OperationType
		  , #tmp_TransferReport.ChargeType = itsd.ChargeType
          from #tmp_TransferReport
          inner join QORT_DDM..ImportedTranSettlement its with(nolock) on its.ExternalID = #tmp_TransferReport.TransferID
          inner join QORT_DDM..ImportedTranSettlementDetails itsd with(nolock) on its.ID = itsd.SettlementID
                                                                                  and itsd.ProcessingState in ('Created', 'Canceled') 
         where 1 = 1
               and #tmp_TransferReport.Section = 'CorrectSettlement'
               and not exists (select 1
                                 from QORT_DDM..ImportedTranSettlement its2 with(nolock)
                                 inner join QORT_DDM..ImportedTranSettlementDetails itsd2 with(nolock) on its2.ID = itsd2.SettlementID
                                                                                                          and itsd2.ProcessingState in ('Created', 'Canceled')
                                where its2.ExternalID = its.ExternalID
                                      and its2.id > its.id) 
        update #tmp_TransferReport
        set #tmp_TransferReport.DDM_Rule = concat('CP_', dr.RuleID)
          from #tmp_TransferReport
          outer apply QORT_DDM..DDM_GetImportTransactions_Rule(#tmp_TransferReport.SettlementDetailID) dr
         where 1 = 1
               and #tmp_TransferReport.Section = 'CorrectSettlement'
        update #tmp_TransferReport
        set #tmp_TransferReport.TDB_Message = case
                                                   when cp.IsProcessed = 1 then 'Add New'
                                                   when cp.IsProcessed = 1 then 'Add Started'
                                                   when cp.IsProcessed = 3 then 'Added'
                                                 else concat('Add: ', cp.ErrorLog)
                                              end
          , #tmp_TransferReport.ExecDateTime = iec.ExecutionDateTime
          from #tmp_TransferReport
          inner join QORT_TDB_PROD..CorrectPositions cp with(nolock) on cp.BackID = #tmp_TransferReport.BackID
          inner join QORT_TDB_PROD..ImportExecutionCommands iec with(nolock) on iec.Oper_ID = cp.id
                                                                                and iec.TC_Const = 5
         where 1 = 1
               and #tmp_TransferReport.Section = 'CorrectSettlement'
               and iec.ExecutionDateTime >= #tmp_TransferReport.EventDateTime
        update #tmp_TransferReport
        set #tmp_TransferReport.TDB_Message = case
                                                   when cp.IsProcessed = 1 then 'Canc New'
                                                   when cp.IsProcessed = 1 then 'Canc Started'
                                                   when cp.IsProcessed = 3 then 'Cancelled'
                                                 else concat('Del: ', cp.ErrorLog)
                                              end
          , #tmp_TransferReport.ExecDateTime = iec.ExecutionDateTime
          from #tmp_TransferReport
          inner join QORT_TDB_PROD..CancelCorrectPositions cp with(nolock) on cp.BackID = #tmp_TransferReport.BackID
          inner join QORT_TDB_PROD..ImportExecutionCommands iec with(nolock) on iec.Oper_ID = cp.id
                                                                                and iec.TC_Const = 16
         where 1 = 1
               and #tmp_TransferReport.Section = 'CorrectSettlement'
               and left(#tmp_TransferReport.DDM_Status, 4) = 'Canc'
               and iec.ExecutionDateTime >= #tmp_TransferReport.EventDateTime
        update #tmp_TransferReport
        set #tmp_TransferReport.DB_Message = iif(cp.IsCanceled = 'y', 'Cancelled', concat('Real', iif(isnull(cp.[Date], 0) <> 0, ':Settled', ':Plan')))
          from #tmp_TransferReport
          inner join QORT_DB_PROD..CorrectPositions cp with(nolock) on cp.BackID = #tmp_TransferReport.BackID
         where 1 = 1
               and #tmp_TransferReport.Section = 'CorrectSettlement'
        select tt.TransferID
             , ttr.EventDateTime
             , ttr.Section
             , ttr.DDM_Status
             , ttr.TDB_Message
             , ttr.DB_Message
             , ttr.DDM_Rule
             , DDM_Message = case
                                  when left(ttr.DDM_Message, 3) = '000' then 'Ok'
                                else ttr.DDM_Message
                             end
             , ExecDateTime
			 , OperationType
			 , ChargeType
          from #tmp_Transfer tt
          left join #tmp_TransferReport ttr on tt.TransferID = ttr.TransferID
        order by ttr.EventDateTime
    end
