CREATE VIEW dbo.QORT_ImportRules
AS
select RuleID = 'CP_'+ltrim(str(itr.RuleID))
     , Integration = 'DDM'
     , [Move Type] = itr.MovType
     , [DDM Type] = itr.OperationType
     , BusinessSense = 'N/A'
     , [Transfer Type] = isnull(itr.ChargeType, 'Any')
     , [isClaim] = 'N/A'
     , Direction = iif(itr.Direction is null, 'Any', iif(itr.Direction = -1, 'Pay', 'Receive'))
     , [LoroAccount/Client or PROP] = isnull(nullif(itr.LoroAccount, '%'), 'Any')
     , AccountType = lower(sr.Capacity)
     , [Transfer Status] = iif(itr.SettledOnly = 0, 'Any', 'Settled')
	 , [Registration Date] = 'Trade date'
     , sr.SettlementDate
     , [Two legs] = iif(itr.IsDual = 1, 'Yes', 'No')
     , IsInternal = iif(itr.IsInternal = 0, 'No', 'Yes')
     , [Correction Type] = cc.Description
     , RuleComment = isnull(itr.RuleComment, '')
     , StartDate = format(itr.StartDate, 'yyyy-MM-dd')
     , EndDate = isnull(format(itr.EndDate, 'yyyy-MM-dd'), 'Never')
  from QORT_DDM..ImportTransactions_Rules itr with(nolock)
  inner join QORT_DDM..SettlementRules sr with(nolock) on itr.STLRuleID = sr.STLRuleID
  inner join QORT_DB_PROD..CT_Const cc with(nolock) on cc.[Value] = itr.CT_Const
 where itr.IsSynchronized = 1
union all
select RuleID = 'TRD_'+ltrim(str(tsr.RuleID))
     , Integration = 'DDM'
     , [Move Type] = tsr.MovType
     , [DDM Type] = 'N/A'
     , BusinessSense = 'N/A'
     , [Transfer Type] = isnull(ChargeType, 'Any')
     , [isClaim] = 'N/A'
     , Direction = 'Any'
     , [LoroAccount/Client or PROP] = isnull(nullif(LoroAccount, '%'), 'Any')
     , AccountType = lower(sr.Capacity)
     , [Transfer Status] = 'Any'
	 , [Registration Date] = iif(tsr.TradeEvent like 'AddCommission%','Available Date / Trade Date' ,'')
     , sr.SettlementDate
     , [Two legs] = iif(IsDual = 1, 'Yes', 'No')
     , IsInternal = 'No'
     , [Correction Type] = case tsr.TradeEvent
                                when 'AddCommissionBlock' then isnull(tsr.CommissionName, '')
                                when 'AddCommission' then isnull(tsr.CommissionName+' + ', '')+'Этап (Оплата комиссий брокера)'
                                when 'UpdateTradeAccount' then 'Update Trade Account'
                                when 'CashSettlement' then 'Update Trade Account + Этап (частичная или полная оплата)'
                                when 'SecuritySettlement' then 'Update Trade Account + Этап (частичная или полная поставка)'
                              else ''
                           end
     , RuleComment = ''
     , StartDate = isnull(format(StartDate, 'yyyy-MM-dd'), '')
     , EndDate = isnull(format(EndDate, 'yyyy-MM-dd'), 'Never')
  from QORT_DDM.dbo.Trades_SettlementRules tsr with(nolock)
  inner join QORT_DDM.dbo.SettlementRules sr with(nolock) on tsr.STLRuleID = sr.STLRuleID
union all
select RuleID = 'ECP_'+ltrim(str(ccr.ID))
     , Integration = 'EAI'
     , [Move Type] = iif(ccr.FlowType='SECURITY', 'SECURITY', 'CASH')
     , [DDM Type] = ccr.ProductType
     , BusinessSense = isnull(ccr.BusinessSense,'N/A')
     , [Transfer Type] = rtrim(ltrim(ccr.FlowType))
     , [isClaim]
     , Direction = iif(ccr.Direction is null, 'Any', iif(ccr.Direction = 'PAY', 'Pay', 'Receive'))
     , [LoroAccount/Client or PROP] = 'N/A'
     , AccountType = 'Filter'
     , [Transfer Status] = 'Filter'
     , [Registration Date] = 'Filter'
     , SettlementDate = 'Filter'
     , [Two legs] = isDual
     , IsInternal = 'Filter'
     , [Correction Type] = cc.Description
     , RuleComment = isnull(ccr.Description, '')
     , StartDate = 'N/A'
     , EndDate = 'N/A'
  from QORT_CACHE_DB..CT_Const_Rules ccr  with(nolock)
  inner join QORT_DB_PROD..CT_Const cc with(nolock) on cc.[Value] = ccr.CT_Const
 where ccr.Synchronization = 1
union all
select RuleID = 'ECL_'+ltrim(str(ccr.ID))
     , Integration = 'EAI'
     , [Move Type] = iif(ccr.FlowType='SECURITY', 'SECURITY', 'CASH')
     , [DDM Type] = ccr.ProductType
     , BusinessSense = isnull(ccr.BusinessSense,'N/A')
     , [Transfer Type] = rtrim(ltrim(ccr.FlowType))
     , [isClaim] = 'N'
     , Direction = iif(ccr.Direction is null, 'Any', iif(ccr.Direction = 'PAY', 'Pay', 'Receive'))
     , [LoroAccount/Client or PROP] = 'N/A'
     , AccountType = 'Filter'
     , [Transfer Status] = 'Filter'
     , [Registration Date] = 'Filter'
     , SettlementDate = 'Filter'
     , [Two legs] = 'N'
     , IsInternal = 'Filter'
     , [Correction Type] = cc.Description
     , RuleComment = isnull(ccr.Description, '')
     , StartDate = 'N/A'
     , EndDate = 'N/A'
  from QORT_CACHE_DB..CL_Const_Rules ccr  with(nolock)
  inner join QORT_DB_PROD..CL_Const cc with(nolock) on cc.[Value] = ccr.CL_Const
 where ccr.Synchronization = 1
