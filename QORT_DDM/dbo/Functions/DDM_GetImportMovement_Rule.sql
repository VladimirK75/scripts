create   function dbo.DDM_GetImportMovement_Rule ( 
                @MovementID bigint ) 
returns table
as
return
with Movement_rule(RuleID
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
                 , IsInternal
                 , PDocType_Name
                 , TradeDateInt
                 , TradeTimeInt
                 , BackOfficeNotes
                 , ExternalID
                 , CtVersion
                 , SubAccCode
                 , AccountCode
                 , MvLoroAccount
                 , MvNostroAccount
                 , MovementID2
                 , GetLoroAccount
                 , GetNostroAccount
                 , Currency
                 , mvIssue
                 , ShortName
                 , Asset_ShortName
                 , Price
                 , AccruedCoupon
                 , ChargeType
                 , Direction
                 , Size
                 , SettlementDate
                 , SettlementDateInt
                 , BreakDay
                 , MovType
                 , Priority)
     as (select RuleID = dr.RuleID
              , BackID = concat(ct.ExternalID, '/', isnull(its.ExternalID, mv.ID))
              , CT_Const = isnull(dr.CT_Const, 0)
              , CL_Const = isnull(dr.CL_Const, 0)
              , Infosource = 'BackOffice'
              , Comment2 = ct.TxnGID+'/'+mv.MovType+'/'+isnull(mv.ChargeType, ct.OperationType)
              , NeedClientInstr = isnull(dr.NeedClientInstr, 0)
              , InternalNumber = iif(dr.NeedClientInstr = 1, ct.OrderExternalID, null)
              , InstrNum = iif(dr.NeedClientInstr = 1, abs(cast(hashbytes('MD5', ct.OrderExternalID) as int)), null)
              , SettledOnly = dr.SettledOnly
              , IsDual = dr.IsDual
              , IsInternal = dr.IsInternal
              , PDocType_Name = dr.PDocType_Name
              , TradeDateInt = convert(int, format(ct.TradeDate, 'yyyyMMdd'))
              , TradeTimeInt = convert(int, format(ct.TradeDate, 'HHmmssfff'))
              , BackOfficeNotes = isnull(ct.BackOfficeNotes, dr.DefaultComment)
              , ExternalID = ct.ExternalID
              , CtVersion = ct.Version
              , SubAccCode = QORT_DDM.dbo.DDM_GetLoroAccount ( mv.NostroAccount, ct.LegalEntity, mv.LoroAccount )
              , AccountCode = QORT_DDM.dbo.DDM_GetNostroAccount ( mv.NostroAccount, ct.LegalEntity, mv.LoroAccount )
              , MvLoroAccount = mv.LoroAccount
              , MvNostroAccount = mv.NostroAccount
              , MovementID2 = mv2.ID
              , GetLoroAccount = iif(dr.IsDual = 1, QORT_DDM.dbo.DDM_GetLoroAccount ( mv2.NostroAccount, ct.LegalEntity, mv2.LoroAccount ), null)
              , GetNostroAccount = iif(dr.IsDual = 1, QORT_DDM.dbo.DDM_GetNostroAccount ( mv2.NostroAccount, ct.LegalEntity, mv2.LoroAccount ), null)
              , Currency = replace(isnull(mv.Currency, mv.PriceCurrency), 'RUB', 'RUR')
              , mvIssue = mv.Issue
              , ShortName = a.ShortName
              , Asset_ShortName = iif(mv.MovType = 'CASH', replace(isnull(mv.Currency, mv.PriceCurrency), 'RUB', 'RUR'), a.ShortName)
              , Price = mv.Price
              , AccruedCoupon = round(mv.AccruedCoupon, 2)
              , ChargeType = mv.ChargeType
              , Direction = mv.Direction
              , Size = mv.Direction * round(isnull(mv.Amount, 0) + isnull(mv.Qty, 0), 2)
              , SettlementDate = mv.SettlementDate
              , SettlementDateInt = isnull(convert(int, format(mv.SettlementDate, 'yyyyMMdd')), 0)
              , BreakDay = (select isnull(max(s.Date), 0)
                              from QORT_DB_PROD..Specials s with(nolock)
                              inner join QORT_DB_PROD..Users u with(nolock) on s.User_ID = u.id
                             where u.last_name = 'srvDeadLine_Settlement')
              , MovType = mv.MovType
              , dr.Priority
           from QORT_DDM..Movements mv with(nolock)
           inner join QORT_DDM..CommonTransaction ct with(nolock) on mv.TransactionID = ct.ID
           left join QORT_DDM..ImportedTranSettlement its with(nolock) on its.TransactionID = ct.ID
                                                                                  and its.OperationType = ct.OperationType
                                                                                  and exists (select 1
                                                                                                    from QORT_DDM..ImportedTranSettlementDetails itsd2 with(nolock)
                                                                                                   where itsd2.SettlementID = its.Id
                                                                                                         and itsd2.type = 'Nostro')
           left join QORT_DDM..ImportTransactions_Rules dr with(nolock) on dr.OperationType = ct.OperationType
                                                                           and dr.MovType = mv.MovType
                                                                           and dr.IsSynchronized = 1
                                                                           and getdate() between dr.StartDate and isnull(dateadd(dd, 1, dr.EndDate), '20501231')
                                                                           and isnull(mv.ChargeType, '') like isnull(dr.ChargeType, '%')
                                                                           and QORT_DDM.dbo.DDM_GetLoroAccount ( mv.NostroAccount, ct.LegalEntity, mv.LoroAccount ) like isnull(dr.LoroAccount, '%')
                                                                           and isnull(dr.Direction, mv.Direction) = mv.Direction
           left join QORT_DDM..Movements mv2 with(nolock) on mv.TransactionID = mv2.TransactionID
                                                             and mv.MovType = mv2.MovType
                                                             and mv2.Direction = -1 * mv.Direction
                                                             and isnull(mv2.SettlementDate, 0) = isnull(mv.SettlementDate, 0)
                                                             and isnull(mv2.Issue, 0) = isnull(mv.Issue, 0)
                                                             and isnull(mv2.Qty, 0) = isnull(mv.Qty, 0)
                                                             and isnull(mv2.Price, 0) = isnull(mv.Price, 0)
                                                             and isnull(mv2.AccruedCoupon, 0) = isnull(mv.AccruedCoupon, 0)
                                                             and isnull(mv2.ChargeType, '') = isnull(mv.ChargeType, '')
                                                             and isnull(mv2.Amount, 0) = isnull(mv.Amount, 0)
                                                             and isnull(mv2.Currency, 0) = isnull(mv.Currency, 0)
           left join QORT_DB_PROD..Assets a with(nolock) on a.Marking = mv.Issue
                                                            and a.Enabled = 0
          where mv.ID = @MovementID)
     select mr1.RuleID
          , mr1.BackID
          , mr1.CT_Const
          , mr1.CL_Const
          , IT_Const = case mr1.CT_Const
                            when 7 then 2  /* Вывод ДС = Списание ДС*/
                            when 11 then 3 /* Перевод ДС = Перевод ДС*/
                            when 4 then 4  /* Ввод ЦБ = Зачисление ЦБ*/
                            when 5 then 5  /* Вывод ЦБ = Списание ЦБ*/
                            when 12 then 6 /* Перевод ЦБ = Перевод ЦБ*/
                          else 13        /* Free Form */
                       end
          , mr1.Infosource
          , mr1.Comment2
          , mr1.NeedClientInstr
          , mr1.InternalNumber
          , mr1.InstrNum
          , InstrStatus = iif(mr1.SettlementDate is not null, 'Executed', 'Executing')
          , mr1.SettledOnly
          , mr1.IsDual
          , mr1.IsInternal
          , mr1.PDocType_Name
          , mr1.TradeDateInt
          , mr1.TradeTimeInt
          , mr1.BackOfficeNotes
          , mr1.SubAccCode
          , mr1.ExternalID
          , mr1.CtVersion
          , mr1.AccountCode
          , mr1.MvLoroAccount
          , mr1.MvNostroAccount
          , mr1.MovementID2
          , mr1.GetLoroAccount
          , mr1.GetNostroAccount
          , mr1.Currency
          , mr1.mvIssue
          , mr1.ShortName
          , mr1.Asset_ShortName
          , mr1.Price
          , mr1.AccruedCoupon
          , mr1.ChargeType
          , mr1.Direction
          , mr1.Size
          , mr1.SettlementDate
          , mr1.SettlementDateInt
          , mr1.MovType
          , msg = case
                       when isnull(mr1.RuleID, 0) = 0 then '404. No settlement rule in ImportTransactions_Rules for MovementID = '+ltrim(str(@MovementID, 16))
                     else case
                               when mr1.BreakDay > 0
                                            and isnull(convert(int, format(mr1.SettlementDate, 'yyyyMMdd')), 0) > 0
                                            and isnull(convert(int, format(mr1.SettlementDate, 'yyyyMMdd')), 0) < mr1.BreakDay then concat('403. Forbidden. Settlement Date sent ', format(mr1.SettlementDate, 'yyyyMMdd'), '. Have to be older than ', mr1.BreakDay)
                               when isnull(mr1.Size, 0) = 0 then '400. CP @BackID = '+mr1.BackID+' was not inserted because Size = 0  for MovementID = '+ltrim(str(@MovementID, 16))
                               when isnull(mr1.Asset_ShortName, '') = ''
                                    and mr1.MovType = 'CASH' then '400. Currency is empty for CASH movement. MovementID = '+ltrim(str(@MovementID, 16))
                               when isnull(mr1.Asset_ShortName, '') = ''
                                    and mr1.MovType = 'SECURITY' then '400. Asset GRDB ID= '+mr1.mvIssue+'not found for Security movement. MovementID = '+ltrim(str(@MovementID, 16))
                               when abs(sign(mr1.CL_Const) - sign(mr1.CT_Const)) = 0 then '500. Incorrect Rule definition CT_Const and CL_Const is empty or defined both for RuleID = '+ltrim(str(mr1.RuleID, 16))
                               when isnull(mr1.IsDual, 0) = 1
                                    and isnull(mr1.MovementID2, 0) = 0 then '404. Wait opposite movement for Dual Object. MovementID = '+ltrim(str(@MovementID, 16))
                               when isnull(mr1.IsDual, 0) = 1
                                    and mr1.SubAccCode = 'RENBR' then '404. Wait opposite movement for Dual RENBR Object.'
                               when mr1.SubAccCode is null then '000. Settlement filtered out by LORO. Depends on QORT_DDM..ClientLoroAccount for '+mr1.MvLoroAccount
                               when mr1.AccountCode is null then '000. Settlement filtered out by NOSTRO. Depends on QORT_DDM..NostroMapping for '+mr1.MvNostroAccount
                             else null
                          end
                  end
       from Movement_rule mr1
      where not exists (select 1
                          from Movement_rule mr2
                         where mr1.Priority > mr2.Priority)
