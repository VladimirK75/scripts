CREATE   procedure [dbo].[CLCAB_GetShortPosition_Forward]
( @Style   smallint = 0
, @AddRUR  smallint = 0
, @OldDate int      = null )
as
    begin
        set nocount on;
        declare @CurDate int = format(getdate(), 'yyyyMMdd')
        select @OldDate = isnull(@OldDate, @CurDate)
        drop table if exists #Short_Position
        drop table if exists #Short_Position_Report
        select T = p.OldDate
             , f.firmshortname
             , s.SubAccCode
             , TradeCOde = convert(varchar(12), '')
             , ExportCode = convert(varchar(12), '')
             , ShortName = iif(a.AssetType_Const = 1, a.ShortName, a.CBName)
             , GRDB_ID = iif(isnumeric(a.Marking) = 1, a.Marking, null)
             , FaceAsset = a2.CBName
             , VolFree = cast(p.VolFree + p.VolBlocked as money)
             , VolForwardT0 = cast(0 as money)
             , VolForward = cast(p.VolFree + p.VolForward as money)
             , OnlyVolFree = cast(p.VolFree as money)
             , VolBlocked = cast(p.VolBlocked as money)
             , Nostro = QORT_DDM.dbo.GetDDM_NostroMapping( aa.AccountCode, 'Единый пул', 0 ) collate Cyrillic_General_CS_AS
             , ISIN = a.ISIN
             , AssetType_Const = atc.[Description(eng.)]
             , AssetClass_Const = acc.[Description(eng.)]
             , AssetSort_Const = asort.[Description(eng.)]
             , CommissionName = cast('' as varchar(100))
             , CommissionRate = cast(null as float)
        into #Short_Position
          from( select OldDate = @CurDate
                     , p.Subacc_ID
                     , p.Asset_ID
                     , p.Account_ID
                     , p.VolFree
                     , p.VolBlocked
                     , p.VolForward
                  from QORT_DB_PROD.dbo.Position p with(nolock)
                 where 1 = 1
                       and @CurDate = @OldDate
                       and abs(p.VolFree) + abs(p.VolBlocked) + abs(p.VolForward) + abs(p.VolForwardOut) != 0
                union
                select ph.OldDate
                     , ph.Subacc_ID
                     , ph.Asset_ID
                     , ph.Account_ID
                     , ph.VolFree
                     , ph.VolBlocked
                     , ph.VolForward
                  from QORT_DB_PROD.dbo.PositionHist ph with(nolock)
                 where 1 = 1
                       and ph.OldDate = @OldDate
                       and abs(ph.VolFree) + abs(ph.VolBlocked) + abs(ph.VolForward) + abs(ph.VolForwardOut) != 0 ) p
          inner join QORT_DB_PROD.dbo.Subaccs s with(nolock) on p.Subacc_ID = s.id
                                                                and s.SubaccCode like 'RB0%'
                                                                and s.ownerfirm_id <> 70736 /*-id=RESEC*/
          inner join QORT_DB_PROD.dbo.Firms f with(nolock) on s.ownerfirm_id = f.id
          inner join QORT_DB_PROD.dbo.Assets a with(nolock) on p.Asset_ID = a.id
          inner join QORT_DB_PROD..AssetType_Const atc with(nolock) on atc.[Value] = a.AssetType_Const
          inner join QORT_DB_PROD..AssetClass_Const acc with(nolock) on acc.[Value] = a.AssetClass_Const
          inner join QORT_DB_PROD..AssetSort_Const asort with(nolock) on asort.[Value] = a.AssetSort_Const
          left join QORT_DB_PROD..Assets a2 with(nolock) on a2.id = a.BaseCurrencyAsset_ID
          inner join QORT_DB_PROD.dbo.Accounts aa with(nolock) on aa.id = p.account_id
         where 1 = 1
        update sp
           set sp.TradeCOde = a.TradeCOde
          from #Short_Position sp
          inner join QORT_DB_PROD..Subaccs s with(nolock) on sp.SubAccCode = s.SubAccCode
          inner join QORT_DB_PROD..PayAccs pa with(nolock) on pa.SubAcc_ID = s.id
          inner join QORT_DB_PROD..Accounts a with(nolock) on a.id in ( pa.PutAccount_ID, pa.PayAccount_ID )
          and a.TS_ID != 6
          and a.IsTrade = 'y'
          and a.IsAnalytic = 'n'
          and a.AssetType = 1
          and sp.Nostro = QORT_DDM.dbo.GetDDM_NostroMapping( a.AccountCode, 'Единый пул', 0 ) collate Cyrillic_General_CS_AS
        update sp
           set sp.ExportCode = a.FactCode
          from #Short_Position sp
          inner join QORT_DB_PROD..Subaccs s with(nolock) on sp.SubAccCode = s.SubAccCode
          inner join QORT_DB_PROD..PayAccs pa with(nolock) on pa.SubAcc_ID = s.id
          inner join QORT_DB_PROD..Accounts a with(nolock) on a.id in ( pa.PutAccount_ID, pa.PayAccount_ID )
          and a.TS_ID != 6
          and a.IsAnalytic = 'n'
          and a.AssetType = 3
          and a.AccountType_ID = 14
        update sp
           set sp.TradeCOde = a.TradeCOde
          from #Short_Position sp
          inner join #Short_Position a on sp.SubAccCode = a.SubAccCode
                                          and a.TradeCOde != ''
         where sp.TradeCOde = ''
        update sp
           set sp.ExportCode = a.ExportCode
          from #Short_Position sp
          inner join #Short_Position a on sp.SubAccCode = a.SubAccCode
                                          and a.TradeCOde != ''
         where sp.ExportCode = ''
        update sp
           set sp.TradeCOde = a.TradeCOde
          from #Short_Position sp
          inner join QORT_DB_PROD..Subaccs s with(nolock) on sp.SubAccCode = s.SubAccCode
          inner join QORT_DB_PROD..PayAccs pa with(nolock) on pa.SubAcc_ID = s.id
          inner join QORT_DB_PROD..Accounts a with(nolock) on a.id in ( pa.PutAccount_ID, pa.PayAccount_ID )
          and a.TS_ID != 6
          and a.IsTrade = 'y'
          and a.IsAnalytic = 'n'
          and a.AssetType = 1
         where sp.TradeCOde = ''
        /*update sp
           set sp.CommissionName = ccr.Name
             , sp.CommissionRate = ccr.Rate
          from #Short_Position sp
          inner join #Current_CommissionRates ccr on sp.SubAccCode = ccr.Subacc
                                                     and ccr.LongShort = 'Short'
         where sp.AssetType_Const = 'Securities'
        update sp
           set sp.CommissionName = ccr.Name
             , sp.CommissionRate = ccr.Rate
          from #Short_Position sp
          inner join #Current_CommissionRates ccr on sp.SubAccCode = ccr.Subacc
                                                     and sp.ShortName = ccr.CBName
                                                     and ccr.LongShort = 'Long'
         where sp.AssetType_Const != 'Securities'*/
        create index IX_Short_Position on #Short_Position
        ( SubAccCode, ShortName, Nostro )
        select T = max(sp.T)
             , sp.SubAccCode
             , firmshortname = max(firmshortname)
             , sp.ShortName
             , TradeCOde = sp.TradeCOde
             , ExportCode = max(sp.ExportCode)
             , GRDB_ID = max(GRDB_ID)
             , FaceAsset = max(FaceAsset)
             , VolFree = sum(sp.VolFree)
             , VolForwardT0 = sum(sp.VolForwardT0)
             , VolForward = sum(sp.VolForward)
             , VolBlocked = sum(sp.VolBlocked)
             , OnlyVolFree = sum(sp.OnlyVolFree)
             , Nostro = max(sp.Nostro)
             , ISIN = max(sp.ISIN)
             , AssetType_Const = max(sp.AssetType_Const)
             , AssetClass_Const = max(sp.AssetClass_Const)
             , AssetSort_Const = max(sp.AssetSort_Const)
             , CommissionName = max(sp.CommissionName)
             , CommissionRate = max(sp.CommissionRate)
        into #Short_Position_Report
          from #Short_Position sp
         where 1 = 1
               and 1 = case
                           when @AddRUR = 0 then 1
                           when @AddRUR = 1
                                and not('RUB' in ( isnull(sp.FaceAsset, sp.ShortName), sp.ShortName )
                       or 'RUR' in ( isnull(sp.FaceAsset, sp.ShortName), sp.ShortName ) ) then 1
                           when @AddRUR = 2
                                and ('RUB' in ( isnull(sp.FaceAsset, sp.ShortName), sp.ShortName )
        or 'RUR' in ( isnull(sp.FaceAsset, sp.ShortName), sp.ShortName ) ) then 1
                       end
        /*and exists( select 1
                      from #Short_Position sp1
                     where sp1.SubAccCode = sp.SubAccCode
                     group by sp1.SubAccCode
                            , sp1.ShortName
                     having not(sum(sp1.VolFree) = abs(sum(sp1.VolFree))
                                and sum(sp1.OnlyVolFree) = abs(sum(sp1.OnlyVolFree))) )*/
         group by sp.SubAccCode
                , sp.ShortName
                , sp.TradeCOde
/*                , sp.Nostro
        update spr
           set spr.VolForwardT0 = isnull(spr.VolForwardT0, 0) + isnull(qgcpf.T0,0)
          from #Short_Position_Report spr
          inner join QORT_DDM.dbo.QORT_GetCashPositionForward qgcpf on qgcpf.SubAccCode = spr.SubaccCode
                                                                       and qgcpf.Currency = spr.ShortName
                                                                       and qgcpf.Nostro = spr.Nostro collate Cyrillic_General_CI_AS
                                                                       and qgcpf.PayPlannedDate <= format(dateadd(hh, 1, getdate()), 'yyyyMMdd')
         where spr.AssetType_Const <> 'Securities'
        update spr
           set spr.VolForwardT0 = isnull(spr.VolForwardT0, 0) + isnull(qgapf.T0,0)
          from #Short_Position_Report spr
          inner join QORT_DDM.dbo.QORT_GetAssetPositionForward qgapf on qgapf.SubAccCode = spr.SubaccCode
                                                                        and qgapf.AssetCode = spr.ShortName
                                                                        and qgapf.Nostro = spr.Nostro collate Cyrillic_General_CI_AS
                                                                        and qgapf.PutPlannedDate <= format(dateadd(hh, 1, getdate()), 'yyyyMMdd')
         where spr.AssetType_Const = 'Securities'*/
        select *
          from #Short_Position_Report spr
         where 1 = 1
               and 1 = case
                           when @Style = 0 then 1
                           when @Style = 1
                                and spr.AssetType_Const <> 'Securities' then 1
                           when @Style = 2
                                and spr.AssetType_Const = 'Securities' then 1
                            else 0
                       end
        order by spr.T
               , spr.SubAccCode
               , spr.ISIN
    end
