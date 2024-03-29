create 
 
 procedure [dbo].[CLCAB_GetQORT_CA] (@DateStart date, @DateEnd date)
as
    begin


select 
  [ID] = SystemID
, [UpdateTime] = qort_ddm.[dbo].[DDM_GetDateTimeFromInt](ModifiedDate,ModifiedTime)
, [TransactionType] = IIF(CT_Const In (4, 5, 25, 59), 'SecurityCA', 'CashCA')
, [ChargeType] = QORT_DDM.dbo.QORT_GetListNumber(ecp.Comment,'/',3)
, [BusinessSense] = QORT_DDM.dbo.QORT_GetListNumber(ecp.Comment,'/',4)
, [TradeDate] = cast(qort_ddm.[dbo].[DDM_GetDateTimeFromInt](RegistrationDate,0) as date)
, [Timestamp] = qort_ddm.[dbo].[DDM_GetDateTimeFromInt](nullif(Date,0),Time)
, [Book] = 'DUMMYCA'
, [LegalEntity] = 'RENBR'
, [Counterparty] = SubaccOwnerFirm_BOCode
, [LoroAccount] = Subacc_Code
, [NostroAccount] =  ecp.Account_ExportCode
, [Direction] = IIF(Size<0, 'In', 'Out')
, [SettlementDate] = cast(qort_ddm.[dbo].[DDM_GetDateTimeFromInt](nullif(Date,0),0) as date)
, [Issue.ShortName] = ecp.SideAsset_ShortName
, [Issue.GRDB_ID] = a.Marking
, [Quantity] = IIF(CT_Const In (4, 5, 25, 59),ABS(Size),null)
, [ExchangeSector] = 'OTC'
, [Exchange] = 'OTC'
, [Currency] = replace(CurrencyAsset_ShortName,'RUR','RUB')
, [Amount] = IIF(CT_Const In (4, 5, 25, 59),null,ABS(Size))
, [IsCanceled] = IsCanceled
       from QORT_TDB_PROD..ExportCorrectPositions ecp with (nolock)
	   left join QORT_DB_PROD..Assets a with(nolock) on a.ShortName = ecp.SideAsset_ShortName and a.Enabled=0
       where 1=1
	   and ecp.SubaccOwnerFirm_BOCode != 'RENBR'
       and ecp.ModifiedDate between format(@DateStart,'yyyyMMdd') and format(@DateEnd,'yyyyMMdd')
	   and ecp.InfoSource != 'BackOffice'
	   and (ecp.CT_Const In (4, 5, 25, 59)
	   or patindex('%/CA/%',ecp.Comment)+patindex('%/DIVIDEND/%',ecp.Comment)+patindex('%/CORPORATE_ACTIONS/%',ecp.Comment)>0)
end
