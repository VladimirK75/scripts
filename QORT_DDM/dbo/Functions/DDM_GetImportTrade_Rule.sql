CREATE function [dbo].[DDM_GetImportTrade_Rule](@SettlementDetailID bigint)
returns table
as
     return
     with Trd_rule(RuleID
                 , BackID
                 , TradeEvent
                 , PC_Const
                 , CT_Const
                 , IsDual
                 , STLRuleID
                 , StlExternalID
                 , ReversedID
                 , ExternalReference
                 , TradeNum
                 , ChargeType
                 , MovType
                 , Issue
                 , Asset_ShortName
                 , Qty
                 , Price
                 , AccruedCoupon
                 , Amount
                 , Direction
                 , Currency
                 , SubAccCode
                 , AccountCode
                 , LegalEntity
                 , AvaliableDate
                 , GetLegalEntity
                 , ExternalID2
                 , GetLoroAccount
                 , GetNostroAccount
                 , StlType
                 , SettLRuleID
                 , StlDateType
                 , CommissionName
                 , SettlementDate
                 , NetSettlementID
                 , BreakDay
                 , Trade_SID
                 , TradeDate
                 , PayCurrency
                 , NullStatus
                 , Priority)
          as (select RuleID = isnull(tsr.RuleID, 0)
                   , BackID = concat(its.ExternalTradeID, '/', its.ExternalID)
                   , TradeEvent = tsr.TradeEvent
                   , PC_Const = isnull(tsr.PC_Const, 0)
                   , CT_Const = isnull(tsr.CT_Const, 0)
                   , IsDual = tsr.IsDual
                   , STLRuleID = tsr.STLRuleID
                   , StlExternalID = its.ExternalID
                   , ReversedID = isnull(its.ReversedID, 0)
                   , ExternalReference = its.TradeGID
                   , TradeNum = its.ExternalTradeID
                   , ChargeType = itsd.ChargeType
                   , MovType = itsd.MovType
                   , Issue = itsd.Issue
                   , Asset_ShortName = isnull(a.ShortName, itsd.Issue)
                   , Qty = isnull(itsd.Qty, 0)
                   , Price = isnull(itsd.Price, 0)
                   , AccruedCoupon = isnull(itsd.AccruedCoupon, 0)
                   , Amount = isnull(itsd.Amount, 0)
                   , Direction = iif(itsd.Type = 'Loro', -1, 1) * itsd.Direction
                   , Currency = replace(itsd.Currency, 'RUB', 'RUR')
                   , SubAccCode = QORT_DDM.dbo.DDM_GetLoroAccount( itsd.NostroAccount, its.LegalEntity, itsd.LoroAccount )
                   , AccountCode = QORT_DDM.dbo.DDM_GetNostroAccount( itsd.NostroAccount, its.LegalEntity, itsd.LoroAccount )
                   , LegalEntity = its.LegalEntity
                   , AvaliableDate = iif(tsr.PC_Const=30, isnull(its.AvaliableDate,its.Tradedate), its.AvaliableDate)
                   , GetLegalEntity = itsd.Counterparty
                   , ExternalID2 = iif(tsr.IsDual = 1, isnull(its2.ExternalID, 0), 0)
                   , GetLoroAccount = iif(tsr.IsDual = 1, QORT_DDM.dbo.DDM_GetLoroAccount( itsd2.NostroAccount, its2.LegalEntity, itsd2.LoroAccount ), null)
                   , GetNostroAccount = iif(tsr.IsDual = 1, iif(isnull(its2.LegalEntity, itsd2.LoroAccount) is not null, QORT_DDM.dbo.DDM_GetNostroAccount( itsd2.NostroAccount, its2.LegalEntity, itsd2.LoroAccount ), null), null)
                   , StlType = itsd.Type
                   , SettLRuleID = isnull(sr.STLRuleID, 0)
                   , StlDateType = sr.SettlementDate
                   , CommissionName = tsr.CommissionName
                   , SettlementDate = case sr.SettlementDate
                                          when 'FOAvaliableDate' then its.FOAvaliableDate
                                          when 'ActualSettlementDate' then its.ActualSettlementDate
                                          when 'AvaliableDate' then its.AvaliableDate
                                           else null
                                      end
                   , NetSettlementID = its.NetSettlementID
                   , BreakDay = ( select isnull(max(s.Date), 0)
                                    from QORT_DB_PROD..Specials s with(nolock)
                                    inner join QORT_DB_PROD..Users u with(nolock) on s.User_ID = u.id
                                   where u.last_name = 'srvDeadLine_Settlement' )
                   , Trade_SID = cast(coalesce(t0.SystemID, t1.SystemID) as bigint)
                   , TradeDate = coalesce(convert(int, format(its.TradeDate, 'yyyyMMdd')), t0.TradeDate, t1.TradeDate)
                   , PayCurrency = coalesce(t0.CurrPayAsset_ShortName, t1.CurrPayAsset_ShortName)
                   , NullStatus = coalesce(t0.NullStatus, t1.NullStatus)
                   , Priority = tsr.Priority
                from QORT_DDM..ImportedTradeSettlement its with(nolock)
                inner join QORT_DDM..ImportedTradeSettlementDetails itsd with(nolock) on itsd.SettlementID = its.ID
                left join QORT_DDM..Trades_SettlementRules tsr with(nolock) on isnull(tsr.TradeType, its.OperationType) = nullif(its.OperationType, 'Trade')
                                                                               and coalesce(tsr.ChargeType, itsd.ChargeType, '') = isnull(itsd.ChargeType, '')
                                                                               and isnull(tsr.MovType, itsd.MovType) = itsd.MovType
                                                                               and isnull(QORT_DDM.dbo.DDM_GetLoroAccount( itsd.NostroAccount, its.LegalEntity, itsd.LoroAccount ), '') like isnull(tsr.LoroAccount, '%')
                left join QORT_DDM..SettlementRules sr with(nolock) on sr.STLRuleID = tsr.STLRuleID
                                                                       and sr.Capacity = itsd.Type
                left join QORT_DDM..ImportedTradeSettlement its2 with(nolock) on its.TradeGID = its2.TradeGID
                                                                                 and isnull(its2.OperationType, its.OperationType) = its2.OperationType
                                                                                 and its.ExternalID <> its2.ExternalID
                                                                                 and exists( select 1
                                                                                               from QORT_DDM..ImportedTradeSettlementDetails itsd0 with(nolock)
                                                                                              where its2.ID = itsd0.SettlementID
                                                                                                    and itsd0.MovType = itsd.MovType
                                                                                                    and itsd0.ChargeType = itsd.ChargeType
                                                                                                    and iif(itsd0.Type = itsd.Type, 1, 0) + iif(itsd0.Direction = itsd.Direction, 1, 0) = 1
                                                                                                    and iif(itsd0.Qty = itsd.Qty
                                                                                                            and itsd.Issue = itsd0.Issue
                                                                                                            and itsd.Price = itsd0.Price
                                                                                                            and itsd.AccruedCoupon = itsd0.AccruedCoupon, 1, 0) + iif(itsd0.Amount = itsd.Amount
                                                                                                                                                                      and itsd.Currency = itsd0.Currency, 1, 0) > 0 )
                                                                                 and not exists( select 1
                                                                                                   from QORT_DDM..ImportedTradeSettlement its3 with(nolock)
                                                                                                  where its3.TradeGID = its.TradeGID
                                                                                                        and its3.ExternalID = its2.ExternalID
                                                                                                        and iif(its3.Version > its2.Version, 1, 0) + iif(its3.Version = its2.Version
                                                                                                                                                         and its3.EventDateTime > its2.EventDateTime, 1, 0) > 0 )
                left join QORT_DDM..ImportedTradeSettlementDetails itsd2 with(nolock) on its2.ID = itsd2.SettlementID
                                                                                         and itsd2.MovType = itsd.MovType
                                                                                         and itsd2.ChargeType = itsd.ChargeType
                                                                                         and iif(itsd2.Type = itsd.Type, 1, 0) + iif(itsd2.Direction = itsd.Direction, 1, 0) = 1
                                                                                         and iif(itsd2.Qty = itsd.Qty
                                                                                                 and itsd.Issue = itsd2.Issue
                                                                                                 and itsd.Price = itsd2.Price
                                                                                                 and itsd.AccruedCoupon = itsd2.AccruedCoupon, 1, 0) + iif(itsd2.Amount = itsd.Amount
                                                                                                                                                           and itsd.Currency = itsd2.Currency, 1, 0) > 0
                left join QORT_TDB_PROD..Trades t0 with(nolock) on t0.SubAcc_Code = iif(QORT_DDM.dbo.DDM_GetLoroAccount( itsd.NostroAccount, its.LegalEntity, itsd.LoroAccount ) <> 'RENBR', QORT_DDM.dbo.DDM_GetLoroAccount( itsd.NostroAccount, its.LegalEntity, itsd.LoroAccount ), QORT_DDM.dbo.DDM_GetLoroAccount( itsd2.NostroAccount, its.LegalEntity, itsd2.LoroAccount ))
and t0.IsRepo2 = 'n'
and t0.TT_Const <> 9
and tsr.ChargeType in(select tsr.ChargeType
                        from QORT_DDM..Trades_SettlementRules tsr with(nolock)
                       where tsr.TradeEvent = 'AddCommission'
                       group by tsr.ChargeType)
and t0.AgreeNum = its.TradeGID collate Cyrillic_General_CS_AS
                left join QORT_TDB_PROD..Trades t1 with(nolock) on t1.SubAcc_Code = iif(QORT_DDM.dbo.DDM_GetLoroAccount( itsd.NostroAccount, its.LegalEntity, itsd.LoroAccount ) <> 'RENBR', QORT_DDM.dbo.DDM_GetLoroAccount( itsd.NostroAccount, its.LegalEntity, itsd.LoroAccount ), QORT_DDM.dbo.DDM_GetLoroAccount( itsd2.NostroAccount, its.LegalEntity, itsd2.LoroAccount ))
and t1.IsRepo2 = 'n'
and t1.TT_Const <> 9
and t1.TradeNum = convert(float, its.ExternalTradeID)
and t1.AgreeNum = its.TradeGID collate Cyrillic_General_CS_AS
                left join QORT_DB_PROD..Assets a with(nolock) on a.Marking = itsd.Issue
                                                                 and a.Enabled = 0
               where itsd.ID = @SettlementDetailID)
          select distinct 
                 tr1.RuleID
               , tr1.BackID
               , tr1.TradeEvent
               , tr1.PC_Const
               , tr1.CT_Const
               , tr1.IsDual
               , tr1.STLRuleID
               , tr1.StlExternalID
               , tr1.ReversedID
               , tr1.ExternalReference
               , tr1.TradeNum
               , tr1.ChargeType
               , tr1.MovType
               , tr1.Issue
               , tr1.Asset_ShortName
               , tr1.Qty
               , tr1.Price
               , tr1.AccruedCoupon
               , tr1.Amount
               , tr1.Direction
               , tr1.Currency
               , tr1.SubAccCode
               , tr1.AccountCode
               , tr1.LegalEntity
               , tr1.AvaliableDate
               , tr1.GetLegalEntity
               , tr1.ExternalID2
               , GetLoroAccount = iif(tr1.GetNostroAccount is null, tr1.GetLoroAccount, isnull(tr1.GetLoroAccount, tr1.LegalEntity))
               , tr1.GetNostroAccount
               , tr1.StlType
               , tr1.SettLRuleID
               , tr1.StlDateType
               , tr1.CommissionName
               , tr1.SettlementDate
               , tr1.NetSettlementID
               , tr1.Trade_SID
               , tr1.TradeDate
               , tr1.PayCurrency
               , TransferStatus = iif(tr1.SettlementDate is null, 'VERIFIED', 'SETTLED')
               , TransferType = iif(tr1.ChargeType in('FACILITATION', 'AGENCY'), tr1.ChargeType, 'PRINCIPAL')
               , msg = case
                           when isnull(tr1.RuleID, 0) = 0 then concat('500. Settlement rule not found in Trades_SettlementRules for SettlementDetailID = ', ltrim(str(@SettlementDetailID, 16)), '. MovementID = ', ' @StlType = ', tr1.StlType)
                            else case
                                     when isnull(tr1.SettLRuleID, 0) = 0 then concat('500. Settlement rule not found by Type in SettlementRules for RuleID = ', ltrim(str(tr1.RuleID, 16)), ' and @StlType = ', tr1.StlType)
                                      else case
                                               when tr1.BreakDay > 0
                                                    and isnull(convert(int, format(tr1.SettlementDate, 'yyyyMMdd')), 0) > 0
                                                    and isnull(convert(int, format(tr1.SettlementDate, 'yyyyMMdd')), 0) < tr1.BreakDay then concat('403. Forbidden. Settlement Date sent ', format(tr1.SettlementDate, 'yyyyMMdd'), '. Have to be older than ', tr1.BreakDay)
                                               when tr1.GetLegalEntity in('MICEX', 'MFB00') then concat('403. Forbidden. Prevent load Settlement for ', tr1.GetLegalEntity)
                                               when isnull(tr1.IsDual, 0) = 1
                                                    and isnull(tr1.ExternalID2, 0) = 0 then '404. Wait opposite movement for Dual Object.'
                                               when isnull(tr1.IsDual, 0) = 1
                                                    and tr1.SubAccCode = 'RENBR' then '404. Wait opposite movement for Dual RENBR Object.'
                                               when tr1.TradeEvent in('AddCommission', 'AddCommissionBlock')
                                                    and tr1.MovType = 'CASH'
                                                    and isnull(tr1.PC_Const, 0) = 0 then concat('500. PC_Const not defined for RuleID = ', ltrim(str(tr1.RuleID, 16)), ',  TradeEvent=', tr1.TradeEvent + ' MovType=', tr1.MovType)
                                               when tr1.TradeEvent = 'AddInterest'
                                                    and tr1.MovType = 'CASH'
                                                    and tr1.SettlementDate is not null
                                                    and isnull(tr1.PC_Const, 0) = 0 then concat('500. PC_Const not defined for RuleID = ', ltrim(str(tr1.RuleID, 16)), ',  TradeEvent=', tr1.TradeEvent, ' MovType=', tr1.MovType)
                                               when tr1.TradeEvent <> 'AddCorrectPosition' then case
                                                                                                    when isnull(tr1.Trade_SID, -1) < 0 then concat('404. Trade_SID not found for SettlementDetailID=', @SettlementDetailID, ' @StlType=', tr1.StlType)
                                                                                                    when tr1.NullStatus = 'y' then concat('404. Trade_SID=', tr1.Trade_SID, ' is canceled for SettlementDetailID=', @SettlementDetailID, ' @StlType=', tr1.StlType)
                                                                                                end
                                                else null
                                           end
                                 end
                       end
            from Trd_rule tr1
           where not exists( select 1
                               from Trd_rule tr2
                              where tr1.SettLRuleID < tr2.SettLRuleID )
                 and not exists( select 1
                                   from Trd_rule tr3
                                  where tr1.Priority > tr3.Priority )
                 and not exists( select 1
                                   from Trd_rule tr4
                                  where iif(tr1.NullStatus = 'y', 0, isnull(tr1.Trade_SID, 0)) < iif(tr4.NullStatus = 'y', 0, isnull(tr4.Trade_SID, 0)) )
