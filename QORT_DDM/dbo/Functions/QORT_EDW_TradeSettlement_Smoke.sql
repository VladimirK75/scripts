CREATE function [dbo].[QORT_EDW_TradeSettlement_Smoke](@DateFrom int
                                                , @DateTo   int)
returns @TradeSettlement_Smoke table
( SystemID             varchar(20)
, ActualSettlementDate date
, EventTime            datetime2(3)
, SettlementType       varchar(8)
, EventStatus          varchar(8)
, [Trade.SystemID]     varchar(20)
, [Trade.TradeDate]    date
, [Trade.Capacity]     varchar(10) )
as
     begin
         insert into @TradeSettlement_Smoke
         select SystemID = cast(P.SystemID as bigint)
              , ActualSettlementDate = stuff(stuff(P.Date, 7, 0, '-'), 5, 0, '-')
              , EventTime = format(dateadd(hour, -3, ( select QORT_DDM.dbo.DDM_GetDateTimeFromInt( P.ModifiedDate, P.ModifiedTime ) )), 'yyyy-MM-ddTHH:mm:ss.fffZ')
              , SettlementType = iif(P.PC_Const in(3, 4)
                                     and P.TT_Const not in(8, 9, 10, 12), 'Security', 'Cash')
              , EventStatus = case isnull(P.IsCanceled, 'n')
                                  when 'y' then 'Canceled'
                                  when 'n' then 'Active'
                                  else '#N/A#'
                              end
              , [Trade.SystemID] = cast(iif(T.IsRepo2 = 'n', P.Trade_SID, T.RepoTrade_SystemID) as bigint)
              , [Trade.TradeDate] = stuff(stuff(P.TradeDate, 7, 0, '-'), 5, 0, '-')
              , [Trade.Capacity] = iif(T.SubAccOwner_BOCode = 'RENBR', 'Principal', 'Agency')
           from QORT_TDB_PROD..Phases P with (nolock, index(I_Phases_ModifiedDate))
           inner loop join QORT_TDB_PROD..Trades T with (nolock, index(PK_Trades)) on P.Trade_SID = T.SystemID
                                                                                      and t.TradeDate >= 20190701
          where 1 = 1
                and P.ModifiedDate between @DateFrom and @DateTo
                and P.PC_Const in ( 3, 4, 5, 7, 8, 9, 21, 22, 30 )
                and (P.TT_Const not in ( 4 )
                     or P.TT_Const = 4
                        and P.PC_Const <> 4
                        and T.TradeDate >= iif(T.SubAccOwner_BOCode in ( 'RENBR', 'RESEC' ) and (left(T.SubAcc_Code,2) not in ('RB', 'DC') 
								     OR T.SubAccOwner_BOCode = 'RESEC' and left(T.SubAcc_Code,2) = 'RB'
									    and (T.Comment like 'RB331//%'
										     or T.Comment like 'RB331/cl%'
											 or T.Comment like '%colibri%'
											 or T.Comment = 'RB441/'
											 or T.Comment = 'RB446/'
											 or T.Comment = 'RB447/'
											 or T.Comment = 'RB448/'
											 or T.Comment = 'RB331/'
											 or T.Comment = 'RB331/93'
											 or T.Comment like 'RB331/RES%'
											 or T.Comment like 'RB331/RB331%'
										     or T.Comment not like '%/D%'
											    and T.Comment not like '%/C%'
											    and T.Comment not like '%/EX%'
											 or exists (select 1
											            from QORT_DB_PROD..SubaccStructure SubS with(nolock)
														join QORT_DB_PROD..Subaccs S with(nolock) on SubS.Child_ID = S.id
														where Father_ID = 4136 /*UMG873 A*/
														and SubS.Enabled = 0
														and S.SubAccCode = T.SubAcc_Code)
													   )
					                ), T.TradeDate, 20210101)
                        and T.QUIKClassCode in ( 'SPBFUT', 'PSFUT', 'SPBOPT', 'PSOPT' )
                     and P.PC_Const in ( 3, 4, 5, 7, 9, 8 ) )
                and (isnull(P.IsCanceled, 'n') = 'n'
                     or exists( select top 1 1
                                  from QORT_TDB_PROD..DataAlerts_Atom with (nolock, index(IX_Record_ID))
                                 where Record_ID = P.id
                                       and TC_Const = 7
                                       and RecordStatus > 0
                                       and IsProcessed = 2 ))
         return
     end
