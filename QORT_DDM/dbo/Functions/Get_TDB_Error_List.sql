CREATE   function [dbo].[Get_TDB_Error_List]()
returns @tmp_dashboard table
( Section     varchar(32)
, Reprocessed bit
, ID          bigint
, Reference   varchar(48)
, IsProcessed tinyint
, ErrorLog    varchar(254) )
as
     begin
         with tmp_dashboard(Section
                          , Reprocessed
                          , ID
                          , Reference
                          , IsProcessed
                          , ET_Const
                          , ErrorLog
                          , ddm_Status
                          , db_status)
              as (select Section = 'ImportTrades'
                       , Reprocessed = case when( select count(1)
                                                    from QORT_TDB_PROD..ImportTrades it2 with(nolock)
                                                   where it2.AgreeNum = it.AgreeNum
                                                         and it2.tradeNum = it.tradeNum
                                                         and it2.IsProcessed = 3
                                                         and it2.id > it.id ) > 0
                                            then 1 when( select count(1)
                                                           from QORT_TDB_PROD..ImportTrades it2 with(nolock)
                                                          where it2.AgreeNum = it.AgreeNum
                                                                and it2.tradeNum <> it.tradeNum
                                                                and it2.BuySell = it.BuySell
                                                                and it2.IsProcessed = 3
                                                                and it2.id > it.id ) > 0
                                            then 1
                                            else 0
                                       end
                       , ID = it.id
                       , Reference = it.AgreeNum collate Cyrillic_General_CS_AS
                       , it.IsProcessed
                       , ET_Const = isnull(it.ET_Const, iif(isnull(p.IsProcessed, 3) = 3, 8, 4))
                       , it.ErrorLog
                       , ddm_Status = iif(isnull(p.IsProcessed, 1) = 3, 'Cancelled', 'Active')
                       , db_status = iif(isnull(t0.NullStatus, 'y') = 'y', 0, 1)
                    from QORT_TDB_PROD..ImportTrades it with(nolock)
                    left join QORT_TDB_PROD..Trades t0 with(nolock) on t0.AgreeNum = it.AgreeNum
                                                                       and t0.TradeNum = it.TradeNum
                    left join QORT_TDB_PROD..ImportExecutionCommands iec with(nolock) on iec.Oper_ID = it.id
                                                                                         and iec.TC_Const = 1
                    left join QORT_TDB_PROD..Phases p with(nolock) on p.Trade_SID = t0.SystemID
                                                                      and p.PC_Const = 17
                   where 1 = 1
                         and it.ImportInsertDate > 20190900
                         and it.IsProcessed in ( 1, 2, 4 )
              --                        and isnull(iec.IsProcessed, 3) = 3      
                  union all
                  select Section = 'ImportClientInstr'
                       , Reprocessed = case when( select count(1)
                                                    from QORT_TDB_PROD..ImportClientInstr ici2 with (nolock, index = I_ImportClientInstr_ID)
                                                   where ici2.InstrNum = ici.InstrNum
                                                         and ici2.RegNum = ici.RegNum
                                                         and ici2.IsProcessed = 3
                                                         and ici2.ID > 7638410
                                                         and ici2.id > ici.id ) > 0
                                            then 1
                                            else 0
                                       end
                       , ID = ici.id
                       , Reference = ici.RegNum collate Cyrillic_General_CS_AS
                       , ici.IsProcessed
                       , ici.ET_Const
                       , ici.ErrorLog
                       , ddm_Status = ''
                       , db_status = 1
                    from QORT_TDB_PROD..ImportClientInstr ici with (nolock, index = I_ImportClientInstr_ID)
                   where 1 = 1
                         and ici.IsProcessed in ( 1, 2, 4 )
                  and ici.ID > 7638410
                  union all
                  select Section = 'ImportTradeInstrs'
                       , Reprocessed = case when( select count(1)
                                                    from QORT_TDB_PROD..ImportTradeInstrs iti2 with (nolock, index = I_ImportTradeInstrs_ID)
                                                   where iti2.RegisterNum = iti.RegisterNum
                                                         and iti2.IsProcessed = 3
                                                         and iti2.id > 195589
                                                         and iti2.id > iti.id ) > 0
                                            then 1
                                            else 0
                                       end
                       , ID = iti.id
                       , Reference = iti.RegisterNum collate Cyrillic_General_CS_AS
                       , iti.IsProcessed
                       , iti.ET_Const
                       , iti.ErrorLog
                       , ddm_Status = ''
                       , db_status = 1
                    from QORT_TDB_PROD..ImportTradeInstrs iti with (nolock, index = I_ImportTradeInstrs_ID)
                   where 1 = 1
                         and iti.IsProcessed in ( 1, 2, 4 )
                  and iti.id > 195589
                  union all
                  select distinct Section = 'CorrectPositions'
                       , Reprocessed = case when( select count(1)
                                                    from QORT_TDB_PROD..CorrectPositions cp2 with(nolock)
                                                   where cp2.BackID = cp.BackID
                                                         and cp2.IsProcessed = 3
                                                         and cp2.id > cp.id ) > 0
                                            then 1
                                            else 0
                                       end
                       , ID = cp.id
                       , Reference = cp.BackID collate Cyrillic_General_CS_AS
                       , cp.IsProcessed
                       , cp.ET_Const
                       , cp.ErrorLog
                       , ddm_Status = ( select max(its.ddmStatus)
                                          from QORT_DDM..ImportedTranSettlement its with(nolock)
                                         where its.ExternalID = right(cp.BackID, 9) collate Cyrillic_General_CI_AS )
                       , db_status = iif(isnull(cp0.IsCanceled, 'y') = 'y', 0, 1)
                    from QORT_TDB_PROD..CorrectPositions cp with(nolock)
                    left join QORT_DB_PROD..CorrectPositions cp0 with(nolock) on cp.BackID = cp0.BackID
                    left join QORT_TDB_PROD..ImportExecutionCommands iec with(nolock) on iec.Oper_ID = cp.id
                                                                                         and iec.TC_Const = 5
                   where 1 = 1
                         and cp.IsProcessed in ( 1, 2, 4 )
                  --                        and isnull(iec.IsProcessed, 3) in (1, 2, 3)      
                  union all
                  select Section = 'ClientInstr'
                       , Reprocessed = case when( select count(1)
                                                    from QORT_TDB_PROD..ImportClientInstr ici2 with(nolock)
                                                   where ici2.InternalNumber = ici2.InternalNumber
                                                         and ici2.IsProcessed = 3
                                                         and ici2.id > ici.id ) > 0
                                            then 1
                                            else 0
                                       end
                       , ID = ici.id
                       , Reference = ici.InternalNumber collate Cyrillic_General_CS_AS
                       , ici.IsProcessed
                       , ici.ET_Const
                       , ici.ErrorLog
                       , ddm_Status = ''
                       , db_status = iif(isnull(ci.id, 0) = 0, 0, 1)
                    from QORT_TDB_PROD..ImportClientInstr ici with(nolock)
                    left join QORT_DB_PROD..ClientInstr ci with(nolock) on ici.RegNum = ci.RegNum
                   where 1 = 1
                         and ici.IsProcessed in ( 1, 2, 4 ) 
                  union all
                  select Section = 'ImportBlockCommissionOnTrades'
                       , Reprocessed = case when( select count(1)
                                                    from QORT_TDB_PROD..ImportBlockCommissionOnTrades ibcot2 with (nolock, index = I_ImportBlockCommissionOnTrades_ID)
                                                   where ibcot2.BackID = ibcot.BackID
                                                         and ibcot2.IsProcessed = 3
                                                         and ibcot2.id > ibcot.id ) > 0
                                            then 1 when ibcot.ET_Const = 8
                                                        and not exists( select 1
                                                                          from QORT_DB_PROD..BlockCommissionOnTrades bcot2 with(nolock)
                                                                         where bcot2.Trade_ID = ibcot.Trade_SystemID
                                                                               and bcot2.Commission_ID = ibcot.Commission_SID
                                                                               and bcot2.BackID = ibcot.BackID )
                                            then 1
                                            else 0
                                       end
                       , ID = ibcot.id
                       , Reference = ibcot.BackID collate Cyrillic_General_CS_AS
                       , ibcot.IsProcessed
                       , ibcot.ET_Const
                       , ibcot.ErrorLog
                       , ddm_Status = ( select max(its.ddmStatus)
                                          from QORT_DDM..ImportedTradeSettlement its with(nolock)
                                         where its.ExternalID = left(ibcot.BackID, 9) collate Cyrillic_General_CI_AS )
                       , db_status = iif(bcot.id is not null, 1, 0)
                    from QORT_TDB_PROD..ImportBlockCommissionOnTrades ibcot with (nolock, index = I_ImportBlockCommissionOnTrades_IsProcessed)
                    left join QORT_DB_PROD..BlockCommissionOnTrades bcot with(nolock) on bcot.BackID = ibcot.BackID collate Cyrillic_General_CI_AS
                   where 1 = 1
                         and ibcot.IsProcessed in ( 1, 2, 4 ) 
                  union all
                  select Section = 'CancelCorrectPositions'
                       , Reprocessed = case when( select count(1)
                                                    from QORT_TDB_PROD..CancelCorrectPositions cp2 with(nolock)
                                                   where cp2.BackID = cp.BackID
                                                         and cp2.IsProcessed = 3
                                                         and cp2.id > cp.id ) > 0
                                            then 1
                                            else 0
                                       end
                       , ID = cp.id
                       , Reference = cp.BackID collate Cyrillic_General_CS_AS
                       , cp.IsProcessed
                       , ET_Const = 8
                       , cp.ErrorLog
                       , ddm_Status = ( select max(its.ddmStatus)
                                          from QORT_DDM..ImportedTranSettlement its with(nolock)
                                         where its.ExternalID = right(cp.BackID, 9) collate Cyrillic_General_CI_AS )
                       , db_status = iif(isnull(cp0.IsCanceled, 'y') = 'y', 0, 1)
                    from QORT_TDB_PROD..CancelCorrectPositions cp with(nolock)
                    left join QORT_DB_PROD..CorrectPositions cp0 with(nolock) on cp.BackID = cp0.BackID
                   where 1 = 1
                         and cp.IsProcessed in ( 1, 2, 4 ) 
                  union all
                  select Section = 'Phases'
                       , Reprocessed = case when( select count(1)
                                                    from QORT_TDB_PROD..Phases p2 with (nolock, index = I_Phases_ID)
                                                   where p2.BackID = p.BackID
                                                         and p2.IsProcessed = 3
                                                         and p2.id > p.id ) > 0
                                            then 1
                                            else 0
                                       end
                       , ID = p.id
                       , Reference = p.BackID collate Cyrillic_General_CS_AS
                       , p.IsProcessed
                       , p.ET_Const
                       , p.ErrorLog
                       , ddm_Status = ''
                       , db_status = 1
                    from QORT_TDB_PROD..Phases p with(nolock, index = I_Phases_IsProcessed)
                    inner join QORT_TDB_PROD..ImportExecutionCommands iec with(nolock) on iec.Oper_ID = p.id
                                                                                          and iec.TC_Const = 7
                   --                     and iec.IsProcessed in (1,2, 3)
                   where 1 = 1
                         and p.[Date] > 20200900
                         and p.IsProcessed in ( 1,2, 4 ) 
                  union all
                  select Section = 'PhaseCancelations'
                       , Reprocessed = case when( select count(1)
                                                    from QORT_TDB_PROD..PhaseCancelations p2 with (nolock)
                                                   where p2.BackID = p.BackID
                                                         and p2.IsProcessed = 3
                                                         and p2.id > p.id ) > 0
                                            then 1
                                            else 0
                                       end
                       , ID = p.id
                       , Reference = p.BackID collate Cyrillic_General_CS_AS
                       , p.IsProcessed
                       , ET_Const = 8
                       , p.ErrorLog
                       , ddm_Status = isnull(( select max(its.ddmStatus)
                                                 from QORT_DDM..ImportedTradeSettlement its with(nolock)
                                                where its.ExternalID = left(p.BackID, 9) collate Cyrillic_General_CI_AS ), '')
                       , db_status = iif(p2.id is not null
                                         and p2.IsCanceled = 'y', 0, 1)
                    from QORT_TDB_PROD..PhaseCancelations p with(nolock)
                    left join QORT_TDB_PROD..Phases p2 with(nolock) on p.SystemID = p2.SystemID
                   where 1 = 1
                         and p.IsProcessed in ( 1, 2, 4 ) 
						 and p.[Date] > 20200900
                  union all
                  select Section = 'Assets'
                       , Reprocessed = case when( select count(1)
                                                    from QORT_TDB_PROD..Assets a2 with(nolock)
                                                   where concat(a2.ShortName, ' (', a2.Marking, ')') = concat(a.ShortName, ' (', a.Marking, ')')
                                                         and a2.IsProcessed = 3
                                                         and a2.id > a.id ) > 0
                                            then 1
                                            else 0
                                       end
                       , ID = a.id
                       , Reference = concat(a.ShortName, ' (', a.Marking, ')') collate Cyrillic_General_CS_AS
                       , a.IsProcessed
                       , a.ET_Const
                       , a.ErrorLog
                       , ddm_Status = ''
                       , db_status = iif(a2.id is not null, 1, 0)
                    from QORT_TDB_PROD..Assets a with(nolock)
                    left join QORT_DB_PROD..Assets a2 with(nolock) on a2.ShortName = a.ShortName
                                                                      and a2.Marking = a.Marking
                   where 1 = 1
                         and a.IsProcessed in ( 1, 2, 4 ) 
                  union all
                  select Section = 'Coupons'
                       , Reprocessed = case when( select count(1)
                                                    from QORT_TDB_PROD..Coupons c2 with(nolock)
                                                   where concat(c.Asset_ShortName, ' (', c.BeginDate, '-', c.EndDate, ')') = concat(c2.Asset_ShortName, ' (', c2.BeginDate, '-', c2.EndDate, ')')
                                                         and c2.IsProcessed = 3
                                                         and c2.id > c.id ) > 0
                                            then 1
                                            else 0
                                       end
                       , ID = c.id
                       , Reference = concat(c.Asset_ShortName, ' (', c.BeginDate, '-', c.EndDate, ')') collate Cyrillic_General_CS_AS
                       , c.IsProcessed
                       , c.ET_Const
                       , c.ErrorLog
                       , ddm_Status = ''
                       , db_status = 0
                    from QORT_TDB_PROD..Coupons c with(nolock)
                   where 1 = 1
                         and c.IsProcessed in ( 1, 2, 4 ) 
                  union all
				                    select Section = 'Securities'
                       , Reprocessed = case when( select count(1)
                                                    from QORT_TDB_PROD..Securities s2 with(nolock)
                                                   where concat(s.ShortName, '(', s.TSSection_Name, ')') = concat(s2.ShortName, '(', s2.TSSection_Name, ')') 
                                                         and s2.IsProcessed < 4
                                                         and s2.id > s.id ) > 0
                                            then 1
                                            else 0
                                       end
                       , ID = s.id
                       , Reference = concat(s.ShortName, '(', s.TSSection_Name, ')') collate Cyrillic_General_CS_AS
                       , s.IsProcessed
                       , s.ET_Const
                       , s.ErrorLog
                       , ddm_Status = ''
                       , db_status = 0
                    from QORT_TDB_PROD..Securities s with(nolock)
                   where 1 = 1
                         and s.IsProcessed in ( 1, 2, 4 ) 
				  union all
                  select Section = 'Clearings'
                       , Reprocessed = case when( select count(1)
                                                    from QORT_TDB_PROD..Clearings c2 with (nolock, index = I_Clearings_ID)
                                                   where c2.BackID = c.BackID
                                                         and c2.IsProcessed = 3
                                                         and c2.id > c.id ) > 0
                                            then 1
                                            else 0
                                       end
                       , ID = c.id
                       , Reference = c.BackID collate Cyrillic_General_CS_AS
                       , c.IsProcessed
                       , c.ET_Const
                       , c.ErrorLog
                       , ddm_Status = ''
                       , db_status = 1
                    from QORT_TDB_PROD..Clearings c with (nolock, index = Clearings_Idx1)
                   where 1 = 1
                         and c.[Date] > 20190900
                         and c.IsProcessed in ( 1, 2, 4 ) )
              insert into @tmp_dashboard
              select td.Section
                   , Reprocessed = case when td.ET_Const = 8
                                             and db_status = 0
                                             and td.Section in('CancelCorrectPositions', 'PhaseCancelations')
                                        then 1 when td.ET_Const = 8
                                                    and db_status = 1
                                                    and td.ddm_Status = 'Active'
                                        then 1 when td.ET_Const in(2, 4)
                                                    and db_status = 1
                                                    and td.Section not in('CorrectPositions')
                                        then 1 when td.ET_Const in(2, 4)
                                                    and db_status = 0
                                                    and td.ddm_Status = 'Cancelled'
                                        then 1
                                        else td.Reprocessed
                                   end
                   , td.ID
                   , td.Reference
                   , td.IsProcessed
                   , td.ErrorLog
                from tmp_dashboard td
         return
     end
