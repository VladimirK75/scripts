


CREATE   view [dbo].[GetQORT_Traders]
as
select QORT_ID = ft.id
     , Firm_BOCode = ltrim(rtrim(f.BOCode))
     , Firm_Name = ltrim(rtrim(f.Name))
     , ft.TraderUID
	 , Client_BOCode = ltrim(rtrim(isnull(f2.BOCode, f.BOCode)))
     , Client_Name = ltrim(rtrim(isnull(f2.Name, f.Name)))
	 , Firm_Status = sc.[Description(eng.)]
  from QORT_DB_PROD..FirmTraders ft with(nolock)
  inner join QORT_DB_PROD..Firms f with(nolock) on f.id = ft.Firm_ID
  left join QORT_DB_PROD..Firms f2 with(nolock) on f2.id = ft.FirmContact_ID
  left join QORT_DB_PROD..STAT_Const sc with(nolock) on sc.Value = f.STAT_Const
