CREATE   function [dbo].[QORT_EDW_TradeSettlement] ( 
                @DateFrom int,
				@DateTo int) 
returns @PhasesModified table (  
                              SystemID     float
                            , PhaseDate    int
                            , Trade_SID    float
                            , TradeDate    int
                            , EventDate    int
                            , EventTime    int
                            , SubAcc_Code  varchar(32)
                            , Direction    varchar(4)
                            , Type         varchar(16)
                            , ChargeType   varchar(16)
                            , CancelStatus varchar(1) ) 
as
    begin
        with DPhases(SystemID, PhaseDate, Trade_SID, TradeDate, EventDate, EventTime, SubAcc_Code, Type, CancelStatus, PhaseSign, TradeSign, 
		             PC_Const, IsRepo2, RepoRate, TradeFee, Comment, QtyBefore, QtyAfter, isProp)
             as (select P.SystemID
                      , PhaseDate = P.Date
                      , Trade_SID = iif(T.IsRepo2 = 'n', P.Trade_SID, T.RepoTrade_SystemID)
                      , P.TradeDate
                      , EventDate = P.ModifiedDate
                      , EventTime = P.ModifiedTime
                      , SubAcc_Code = case when P.PC_Const = 8 and T.SubAccOwner_BOCode = 'RESEC' 					                            
					                       then iif (T.SubAcc_Code not in('RB0331', 'RB0441', 'RB0446', 'RB0447', 'RB0448'), 'UMG873', T.SubAcc_Code)
										   else P.SubAcc_Code
									  end
                      , Type = iif(P.PC_Const in(3, 4), 'Security', 'Cash')
                      , CancelStatus = P.IsCanceled
                      , PhaseSign = iif(sign(P.QtyBefore * P.QtyAfter) > 0, 1, 0)
                      , TradeSign = iif(sign(P.QtyBefore * P.QtyAfter) * sign(T.RepoRate) > 0, 1, 0)
                      , PC_Const = P.PC_Const
                      , T.IsRepo2
					  , T.RepoRate
                      , TradeFee = iif(P.PC_Const in(8) and (P.TT_Const <> 4 and T.ClearingComission <> 0 or 
					                                         P.TT_Const = 4 and T.TSCommission <> 0 and T.FunctionType = 7),  1, 0)|
					               iif(P.PC_Const in(8) and (P.TT_Const <> 4 and T.ExchangeComission <> 0 or
								                             P.TT_Const = 4 and T.TSCommission <> 0 and T.FunctionType <> 7), 2, 0)
					  , p.Comment
					  , p.QtyBefore
					  , p.QtyAfter
					  , isProp = iif (P.SubAcc_Code = 'RENBR' OR T.TT_Const = 4 and T.SubAccOwner_BOCode = 'RENBR', 'y', 'n')
                   from QORT_TDB_PROD..Phases P with (nolock, index(I_Phases_ModifiedDate))
                   inner loop join QORT_TDB_PROD..Trades T with (nolock, index(PK_Trades)) on P.Trade_SID = T.SystemID and t.TradeDate >= 20190701
                   where 1 = 1
                        and P.ModifiedDate >= @DateFrom and P.ModifiedDate <= @DateTo
                        and (P.TT_Const in (1, 2, 3, 5, 6, 7, 14)
						     OR P.TT_Const = 4 AND P.PC_Const <> 4 AND T.TradeDate >= 20191101
							 AND T.QUIKClassCode in ('SPBFUT', 'PSFUT', 'SPBOPT', 'PSOPT')
						    )
                        and (P.PC_Const in (3, 4, 5, 7, 9)
                             or P.PC_Const = 8 
							    and (left(T.SubAcc_Code,2) not in ('RB', 'DC') 
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
					                )
						    )
						and (P.IsCanceled is null or P.IsCanceled = 'n' 
						     or exists (select top 1 * from QORT_TDB_PROD..DataAlerts_Atom with (nolock, index(IX_Record_ID))
						                where Record_ID = P.id and TC_Const = 7 and RecordStatus > 0 and IsProcessed = 2))
                )
             insert into @PhasesModified
             select P.SystemID
                  , PhaseDate = P.PhaseDate
                  , Trade_SID = P.Trade_SID
                  , P.TradeDate
                  , EventDate = P.EventDate
                  , EventTime = P.EventTime
                  , P.SubAcc_Code
                  , Direction = iif(CC.ChargeType = 'INTEREST', DDR.Direction, DD.Direction)
                  , Type = iif(P.PC_Const in(3, 4), 'Security', 'Cash')
                  , ChargeType = CC.ChargeType
                  , CancelStatus = isnull(P.CancelStatus,'n')
               from DPhases P
               inner loop join (select Direction = 'In' union all 
								select Direction = 'Out') DD 
						on DD.Direction = iif(isProp = 'y', iif(p.PhaseSign > 0, 'In', 'Out'), DD.Direction)
               inner loop join (select Direction = 'In' union all 
								select Direction = 'Out') DDR 
						on DDR.Direction = iif(isProp = 'y', iif(p.TradeSign > 0, 'In', 'Out'), DD.Direction)
               inner loop join (select ChargeType = 'Null' union all
								select ChargeType = 'PRINCIPAL' union all
								select ChargeType = 'INTEREST' union all 
								select ChargeType = 'EXCH_CLEAR_FEE' union all
								select ChargeType = 'EXCH_TRADE_FEE') CC 
						on CC.ChargeType in( iif(P.PC_Const in(3, 4), 'Null', '')
										   , iif(P.PC_Const not in(3, 4, 8), 'PRINCIPAL', '')
										   , iif(P.PC_Const not in (3, 4, 8) and P.IsRepo2 = 'y', 'INTEREST', '')
										   , iif(P.PC_Const in(8) and p.TradeFee&1 = 1, 'EXCH_CLEAR_FEE', '')
										   , iif(P.PC_Const in(8) and p.TradeFee&2 = 2, 'EXCH_TRADE_FEE', ''), '')
			   where P.PC_Const not in (9)
			         and (ChargeType <> 'INTEREST'
					      or RepoRate <> 0
						 )
			   union all
			   select P.SystemID
                  , PhaseDate = P.PhaseDate
                  , Trade_SID = P.Trade_SID
                  , P.TradeDate
                  , EventDate = P.EventDate
                  , EventTime = P.EventTime
                  , P.SubAcc_Code
                  , DD.Direction
                  , Type = 'Cash'
                  , ChargeType = p.Comment
                  , CancelStatus = isnull(P.CancelStatus,'n')
               from DPhases P
               inner loop join (select Direction = 'In' union all
			                    select Direction = 'In' union all 
			                    select Direction = 'Out' union all 
								select Direction = 'Out') DD 
						on DD.Direction = iif(P.PhaseSign > 0, 'In', 'Out')
			   where P.PC_Const in (9) and P.QtyBefore <> 0 and 
			         P.SubAcc_Code not in (select Client_Name COLLATE Cyrillic_General_CS_AS from ClientGroupMap where Client_Group = 'RENBR PROP' and Trade_Field	= 'SubAcc_Code') 
        return
    end
