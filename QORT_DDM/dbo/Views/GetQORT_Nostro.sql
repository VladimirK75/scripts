
CREATE view [dbo].[GetQORT_Nostro]
as
     select AccountCode
          , a.Name
          , AssetType = nullif(ltrim(a.AssetType), '')
          , AssetType_Description = nullif(ltrim(atc.[Description(eng.)]), '')
          , AccountType = a.AccountType_ID
          , AccountType_Description = nullif(ltrim(act.Name), '')
          , Comment = nullif(ltrim(a.Comment), '')
          , DateStart = convert(date, convert(varchar(10), nullif(DateStart, 0), 120), 120)
          , DateEnd = convert(date, convert(varchar(10), nullif(DateEnd, 0), 120), 120)
          , ExportCode = nullif(ltrim(a.ExportCode), '')
          , IsCoverage = lower(isnull(a.IsCoverage, 'n'))
          , IsOurs = lower(isnull(a.IsOurs, 'n'))
          , IsTrade = lower(isnull(a.IsTrade, 'n'))
          , DepoFirm_BOCode = nullif(ltrim(f.BOCode), '')
          , DivisionCode = nullif(ltrim(a.DivisionCode), '')
          , FactCode = nullif(ltrim(a.FactCode), '')
          , HigherDepoFirm_BOCode = nullif(ltrim(hf.BOCode), '')
          , IsAnalytic = lower(isnull(a.IsAnalytic, 'n'))
          , OwnerFirm_BOCode = nullif(ltrim(ownf.BOCode), '')
          , Market = nullif(ltrim(a.Market), '')
          , TradeCode = nullif(ltrim(a.TradeCOde), '')
          , IsUseMoney = lower(isnull(a.IsUseMoney, 'n'))
          , Currency = nullif(ltrim(cur.ShortName), '')
          , IsCollatePool = iif(a.ExportCode = QORT_DDM.dbo.GetDDM_NostroMapping( a.ExportCode, 'Единый пул', 0 ), 'n', 'y')
       from QORT_DB_PROD..Accounts a with(nolock)
       left join QORT_DB_PROD.dbo.AssetType_Const atc with(nolock) on a.AssetType = atc.Value
       left join QORT_DB_PROD.dbo.AccountTypes act with(nolock) on a.AccountType_ID = act.id
       left join QORT_DB_PROD.dbo.Assets cur with(nolock) on a.AccCurrencyAsset_ID = cur.id
       left join QORT_DB_PROD.dbo.Firms f with(nolock) on a.DepoFirm_ID = f.id
       left join QORT_DB_PROD.dbo.Firms hf with(nolock) on a.HigherDepoFirm_ID = hf.id
       left join QORT_DB_PROD.dbo.Firms ownf with(nolock) on a.OwnerFirm_ID = ownf.id
      where 1 = 1
            and a.Enabled = 0
