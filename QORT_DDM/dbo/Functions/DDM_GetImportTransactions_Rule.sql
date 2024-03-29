CREATE function [dbo].[DDM_GetImportTransactions_Rule](
               @SettlementDetailID bigint)
returns table
as
return
with Stld_rule(RuleID
             , BackID
             , CT_Const
             , CL_Const
             , Infosource
             , Comment2
             , NeedClientInstr
             , InternalNumber
             , InstrNum
             , SettledOnly
             , IsDual
             , STLRuleID
             , DefaultComment
             , IsInternal
             , PDocType_Name
             , TradeDateInt
             , TradeTimeInt
             , BackOfficeNotes
             , ExternalID
             , Direction
             , TranDirection
             , AccruedCoupon
             , Amount
             , MoveAmount
             , TranAmount
             , MovementID
             , MvLoroAccount
             , MvNostroAccount
             , MovementID2
             , Mv2LoroAccount
             , TransactionID
             , ExternalTransactionID
             , SettlementID
             , Currency
             , mvIssue
             , Asset_ShortName
             , Price
             , SubAccCode
             , AccountCode
             , LegalEntity
             , SettledAccCoupon
             , SettledAmount
			 , OriginalCounterparty
             , ReversedID
             , StlExternalID
             , GetLoroAccount
             , GetNostroAccount
             , StlType
             , SettLRuleID
             , StlDateType
             , SettlementDate
             , PlanDate
             , BreakDay
             , MovType
             , Priority
             , IsSynchronized)
     as (select RuleID = isnull(dr.RuleID, 0)
              , BackID = concat(its.ExternalTransactionID, '/', its.ExternalID)
              , CT_Const = isnull(dr.CT_Const, 0)
              , CL_Const = isnull(dr.CL_Const, 0)
              , Infosource = 'BackOffice'
              , Comment2 = concat(its.TxnGID, '/', itsd.MovType, '/', isnull(itsd.ChargeType, ct.OperationType), iif(isnull(its.ReversedID, 0) > 0, concat('(REVERSAL FOR ', its.ReversedID, ')'), ''))
              , NeedClientInstr = isnull(dr.NeedClientInstr, 0)
              , InternalNumber = iif(dr.NeedClientInstr = 1
                                     and iif(dr.IsInternal = 1
                                             or mv.LoroAccount = mv2.LoroAccount
                                                and ct.SourceSystem <> 'PIPELINER', 1, 0) = 0, iif(itsd.MovType = 'CASH', iif(ct.ID is not null, ct.OrderExternalID, its.TxnGID), null), null)
              , InstrNum = iif(dr.NeedClientInstr = 1
                               and iif(dr.IsInternal = 1
                                       or mv.LoroAccount = mv2.LoroAccount
                                          and ct.SourceSystem <> 'PIPELINER', 1, 0) = 0, iif(ct.ID is not null, abs(cast(hashbytes('MD5', ct.OrderExternalID) as int)), abs(cast(hashbytes('MD5', its.TxnGID) as int))), null)
              , SettledOnly = dr.SettledOnly
              , IsDual = dr.IsDual
              , STLRuleID = dr.STLRuleID
              , DefaultComment = dr.DefaultComment
              , IsInternal = iif(dr.IsInternal = 1
                                 or mv.LoroAccount = mv2.LoroAccount
                                    and ct.SourceSystem <> 'PIPELINER', 1, 0)
              , PDocType_Name = dr.PDocType_Name
              , TradeDateInt = convert(int, format(coalesce(its.TradeDate, ct.TradeDate, its.FOAvaliableDate), 'yyyyMMdd'))
              , TradeTimeInt = convert(int, format(coalesce(its.TradeDate, ct.TradeDate, its.FOAvaliableDate), 'HHmmssfff'))
              , BackOfficeNotes = coalesce(ct.BackOfficeNotes, dr.DefaultComment, '')
              , ExternalID = its.ExternalTransactionID
              , Direction = itsd.Direction
              , TranDirection = itsd.Direction * iif(itsd.Type = 'Loro', -1, 1)
              , AccruedCoupon = isnull(itsd.AccruedCoupon, 0)
              , Amount = isnull(itsd.Amount, itsd.Qty)
              , MoveAmount = round(isnull(mv.Amount, 0) + isnull(mv.Qty, 0), 2)
              , TranAmount = round(isnull(itsd.Amount, 0) + isnull(itsd.Qty, 0), 2)
              , MovementID = itsd.MovementID
              , MvLoroAccount = coalesce(mv.LoroAccount, ct.LoroAccount, itsd.LoroAccount)
              , MvNostroAccount = isnull(mv.NostroAccount, itsd.NostroAccount)
              , MovementID2 = isnull(mv2.ID, 0)
              , Mv2LoroAccount = mv2.LoroAccount
              , TransactionID = isnull(its.TransactionID, ct.ID)
              , ExternalTransactionID = its.ExternalTransactionID
              , SettlementID = itsd.SettlementID
              , Currency = replace(itsd.Currency, 'RUB', 'RUR')
              , mvIssue = isnull(mv.Issue, itsd.Issue)
              , Asset_ShortName = iif(itsd.MovType = 'CASH', replace(itsd.Currency, 'RUB', 'RUR'), a.ShortName)
              , Price = iif(itsd.MovType = 'CASH', itsd.Price, null)
              , SubAccCode = QORT_DDM.dbo.DDM_GetLoroAccount(itsd.NostroAccount, ct.LegalEntity, itsd.LoroAccount)
              , AccountCode = QORT_DDM.dbo.DDM_GetNostroAccount(itsd.NostroAccount, ct.LegalEntity, itsd.LoroAccount)
              , LegalEntity = isnull(ct.LegalEntity, 'RENBR')
              , SettledAccCoupon = itsd.AccruedCoupon
              , SettledAmount = isnull(itsd.Amount, itsd.Qty)
			  , OriginalCounterparty = iif(its.OriginalCounterparty in ('RENBR') or (isnull(itsd.LoroAccount,'RENBR') not in ('RENBR') ),null,its.OriginalCounterparty)
              , ReversedID = isnull(its.ReversedID, 0)
              , StlExternalID = its.ExternalID
              , GetLoroAccount = iif(dr.IsDual = 1, QORT_DDM.dbo.DDM_GetLoroAccount(mv2.NostroAccount, ct.LegalEntity, mv2.LoroAccount), null)
              , GetNostroAccount = iif(dr.IsDual = 1, QORT_DDM.dbo.DDM_GetNostroAccount(mv2.NostroAccount, ct.LegalEntity, mv2.LoroAccount), null)
              , StlType = itsd.Type
              , SettLRuleID = sr.STLRuleID
              , StlDateType = sr.SettlementDate
              , SettlementDate = case sr.SettlementDate
                                      when 'FOAvaliableDate' then its.FOAvaliableDate
                                      when 'ActualSettlementDate' then its.ActualSettlementDate
                                      when 'AvaliableDate' then its.AvaliableDate
                                    else null
                                 end
              , PlanDate = iif(dr.IsPlanDate=1, cast(format(itsd.SettlementDate,'yyyyMMdd') as int), null)
              , BreakDay = (select isnull(max(s.Date), 0)
                              from QORT_DB_PROD..Specials s with(nolock)
                              inner join QORT_DB_PROD..Users u with(nolock) on s.User_ID = u.id
                             where u.last_name = 'srvDeadLine_Settlement')
              , MovType = itsd.MovType
              , dr.Priority
              , dr.IsSynchronized
           from QORT_DDM..ImportedTranSettlementDetails itsd with(nolock)
           inner join QORT_DDM..ImportedTranSettlement its with(nolock) on itsd.SettlementID = its.ID
           left join QORT_DDM..CommonTransaction ct with (nolock, index = I_CommonTransaction_ExternalID) on ct.TxnGID = its.TxnGID
                                                                                                             and ct.ExternalID = its.ExternalTransactionID
                                                                                                             and not exists (select 1
                                                                                                                               from QORT_DDM..CommonTransaction ct1 with (nolock, index = I_CommonTransaction_ExternalID)
                                                                                                                              where ct1.ExternalID = ct.ExternalID
                                                                                                                                    and ct1.TxnGID = ct.TxnGID
                                                                                                                                    and iif(ct1.Version > ct.Version, 1, 0) + iif(ct1.Version = ct.Version
                                                                                                                                                                                  and ct1.EventDateTime > ct.EventDateTime, 1, 0) > 0) 
           left join QORT_DDM..Movements mv with(nolock) on mv.TransactionID = ct.ID
                                                            and isnull(itsd.ChargeType, 'SECURITY') = isnull(mv.ChargeType, 'SECURITY')
                                                            and mv.MovType = itsd.MovType
                                                            and iif(itsd.Type = 'loro', -1, 1) * itsd.Direction = mv.Direction
           left join QORT_DDM..Movements mv2 with(nolock) on mv2.TransactionID = mv.TransactionID
                                                             and isnull(mv2.ChargeType, 'SECURITY') = isnull(mv.ChargeType, 'SECURITY')
                                                             and mv2.MovType = mv.MovType
                                                             and mv2.Direction = -1 * mv.Direction
           left join QORT_DDM..ImportTransactions_Rules dr with(nolock) on coalesce(its.OperationType, ct.OperationType, '') like isnull(dr.OperationType, '%')
                                                                           and coalesce(itsd.MovType, mv.MovType, '') like isnull(dr.MovType, '%')
                                                                           and getdate() between dr.StartDate and isnull(dateadd(dd, 1, dr.EndDate), '20501231')
                                                                           and coalesce(itsd.ChargeType, mv.ChargeType, '') like isnull(dr.ChargeType, '%')
                                                                           and coalesce(itsd.LoroAccount, ct.LegalEntity, 'RENBR') like coalesce(dr.LoroAccount, '%')
                                                                           and isnull(itsd.Direction, mv.Direction) = coalesce(dr.Direction, itsd.Direction, mv.Direction)
           left join QORT_DDM..SettlementRules sr with(nolock) on dr.STLRuleID = sr.STLRuleID
                                                                  and sr.Capacity = itsd.Type
           left join QORT_DDM..NonTradingOrders nto with(nolock) on nto.ExternalID = ct.OrderExternalID
                                                                    and abs(round(nto.Amount, 2)) = abs(round(itsd.Amount, 2))
                                                                    and replace(nto.Currency, 'RUB', 'RUR') = replace(itsd.Currency, 'RUB', 'RUR')
                                                                    and nto.SourceLoro = QORT_DDM.dbo.DDM_GetLoroAccount(itsd.NostroAccount, ct.LegalEntity, itsd.LoroAccount)
                                                                    and not exists (select 1
                                                                                      from QORT_DDM..NonTradingOrders nto2 with(nolock)
                                                                                     where nto.ExternalID = nto2.ExternalID
                                                                                           and nto.SourceLoro = nto2.SourceLoro
                                                                                           and nto.Amount = nto2.Amount
                                                                                           and nto.Currency = nto2.Currency
                                                                                           and nto2.ID > nto.ID) 
           left join QORT_DB_PROD..Assets a with(nolock) on a.Marking = isnull(mv.Issue, itsd.Issue)
                                                            and a.Enabled = 0
          where itsd.ID = @SettlementDetailID)
     select sr1.RuleID
          , sr1.BackID
          , sr1.CT_Const
          , sr1.CL_Const
          , IT_Const = case sr1.CT_Const
                            when 7 then 2  /* Вывод ДС = Списание ДС*/
                            when 11 then 3 /* Перевод ДС = Перевод ДС*/
                            when 4 then 4  /* Ввод ЦБ = Зачисление ЦБ*/
                            when 5 then 5  /* Вывод ЦБ = Списание ЦБ*/
                            when 12 then 6 /* Перевод ЦБ = Перевод ЦБ*/
                          else 13        /* Free Form */
                       end
          , sr1.Infosource
          , sr1.Comment2
          , sr1.NeedClientInstr
          , InternalNumber = iif(sr1.NeedClientInstr = 1
                                 and left(sr1.Comment2, 2) in ('QF','TR'), null, sr1.InternalNumber)
          , InstrNum = iif(sr1.NeedClientInstr = 1
                           and left(sr1.Comment2, 2) in ('QF','TR'), null, sr1.InstrNum)
          , InstrStatus = iif(sr1.SettlementDate is not null, 'Executed', 'Executing')
          , sr1.SettledOnly
          , sr1.IsDual
          , sr1.STLRuleID
          , sr1.DefaultComment
          , sr1.IsInternal
          , sr1.PDocType_Name
          , sr1.TradeDateInt
          , sr1.TradeTimeInt
          , sr1.BackOfficeNotes
          , sr1.ExternalID
          , sr1.Direction
          , sr1.TranDirection
          , sr1.AccruedCoupon
          , sr1.Amount
          , sr1.MoveAmount
          , sr1.TranAmount
          , sr1.MovementID
          , sr1.MvLoroAccount
          , sr1.MvNostroAccount
          , sr1.MovementID2
          , sr1.Mv2LoroAccount
          , sr1.TransactionID
          , sr1.ExternalTransactionID
          , sr1.SettlementID
          , sr1.Currency
          , sr1.mvIssue
          , sr1.Asset_ShortName
          , sr1.Price
          , sr1.SubAccCode
          , sr1.AccountCode
          , sr1.LegalEntity
          , sr1.SettledAccCoupon
          , sr1.SettledAmount
		  , sr1.OriginalCounterparty
          , sr1.ReversedID
          , sr1.StlExternalID
          , sr1.GetLoroAccount
          , sr1.GetNostroAccount
          , sr1.StlType
          , sr1.SettLRuleID
          , sr1.StlDateType
          , sr1.PlanDate
          , sr1.SettlementDate
          , SettlementDateInt = isnull(convert(int, format(sr1.SettlementDate, 'yyyyMMdd')), 0)
          , sr1.MovType
          , Msg = case
                       when isnull(sr1.RuleID, 0) = 0 then concat('404. No settlement rule in ImportTransactions_Rules for SettlementDetailID = ', @SettlementDetailID, ' @StlType = ', sr1.StlType)
                       when isnull(sr1.IsSynchronized, 0) = 0 then concat('422. Unprocessable Entity in ImportTransactions_Rules for RuleID = ', sr1.RuleID, ' SettlementDetailID = ', @SettlementDetailID, ' @StlType = ', sr1.StlType)
                     else case
                               when isnull(SettLRuleID, 0) = 0 then concat('500. No settlement rule in SettlementRules for RuleID = ', sr1.RuleID, ' and @StlType = ', sr1.StlType)
                             else case
                                       when sr1.BreakDay > 0
                                            and isnull(convert(int, format(sr1.SettlementDate, 'yyyyMMdd')), 0) > 0
                                            and isnull(convert(int, format(sr1.SettlementDate, 'yyyyMMdd')), 0) < sr1.BreakDay then concat('403. Forbidden. Settlement Date sent ', format(sr1.SettlementDate, 'yyyyMMdd'), '. Have to be older than ', sr1.BreakDay)
                                       when isnull(sr1.IsDual, 0) = 1
                                            and isnull(sr1.MovementID2, 0) = 0 then concat('404. Wait opposite movement for Dual Object. MovementID = ', sr1.MovementID)
                                       when isnull(sr1.IsDual, 0) = 1
                                            and sr1.SubAccCode = 'RENBR' then '404. Wait opposite movement for Dual RENBR Object.'
                                       when isnull(sr1.TranAmount, 0) = 0 then concat('400. CP @BackID = ', sr1.BackID, ' was not inserted because Size = 0  for SettlementDetailID = ', @SettlementDetailID)
                                       when isnull(sr1.Asset_ShortName, '') = ''
                                            and sr1.MovType = 'CASH' then concat('400. Currency is empty for CASH movement for SettlementDetailID = ', @SettlementDetailID)
                                       when isnull(sr1.Asset_ShortName, '') = ''
                                            and sr1.MovType = 'SECURITY' then concat('400. Asset GRDB ID= ', sr1.mvIssue, 'not found for SettlementDetailID = ', @SettlementDetailID)
                                       when isnull(sr1.SettledOnly, 0) = 1
                                            and isnull(year(sr1.SettlementDate), 0) = 0 then concat('400. No Settlement Date. Settlement do not applied by SettlementRules. RuleID = ', sr1.RuleID)
                                       when abs(sign(sr1.CL_Const) - sign(sr1.CT_Const)) = 0 then concat('500. Incorrect Rule definition CT_Const and CL_Const is empty or defined both for RuleID = ', sr1.RuleID)
                                       when sr1.SubAccCode is null then concat('403. Settlement filtered out by LORO. Depends on QORT_DDM..ClientLoroAccount for ', isnull(sr1.MvLoroAccount, 'NULL'))
                                       when sr1.AccountCode is null then concat('403. Settlement filtered out by NOSTRO. Depends on QORT_DDM..NostroMapping for ', isnull(sr1.MvNostroAccount, 'NULL'))
                                     else null
                                  end
                          end
                  end
       from Stld_rule sr1
      where not exists (select 1
                          from Stld_rule sr2
                         where sr1.Priority > sr2.Priority)
