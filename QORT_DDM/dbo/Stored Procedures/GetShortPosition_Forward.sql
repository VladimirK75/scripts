CREATE procedure [dbo].[GetShortPosition_Forward]
( @Style  smallint
, @AddRUR smallint )
as
    begin
        set nocount on;
        /* Get current position except empty rows */
        declare @CurDate int = format(getdate(), 'yyyyMMdd')
        --drop table if exists #Current_CommissionRates
        --select Subacc = case ct.CalcSubAcc_ID when-1
        --                     then sub1.SubAccCode
        --                     else sub0.SubAccCode
        --                end
        --     , LongShort = case when c.Name like 'Debit%'
        --                        then 'Long' when c.Name like 'Short%'
        --                        then 'Short'
        --                   end
        --     , c.Rate / 100 as Rate
        --     , c.Name
        --     , cur.CBName
        --into #Current_CommissionRates
        --  from QORT_DB_PROD.dbo.ClientTariffs ct
        --  left join QORT_DB_PROD.dbo.TariffCommissions tc on ct.Tariff_ID = tc.Tariff_ID
        --                                                     and tc.Enabled = 0
        --  inner join QORT_DB_PROD.dbo.Commissions c on tc.Commission_ID = c.id
        --                                               and c.Enabled = 0
        --                                               and (c.Name like '%Short sales Interest (securities)%'
        --                                                    or c.Name like '%Debit interest (money) %')
        --  inner join QORT_DB_PROD.dbo.Firms f on f.id = ct.Firm_ID
        --  inner join QORT_DB_PROD.dbo.Assets cur with(nolock) on cur.id = c.CurrPayAsset_ID
        --  inner join QORT_DB_PROD.dbo.Tariffs t on t.id = ct.Tariff_ID
        --  left join QORT_DB_PROD.dbo.Subaccs sub0 on ct.CalcSubAcc_ID = sub0.id
        --  left join QORT_DB_PROD.dbo.ClientAgrees ca on ct.ClientAgree_ID = ca.id
        --  left join QORT_DB_PROD.dbo.Subaccs sub1 on ca.SubAcc_ID = sub1.id
        -- where 1 = 1
        --       and ct.Enabled = 0
        --       and isnull(nullif(tc.StartDate, 0), @CurDate) <= @CurDate
        --       and isnull(nullif(tc.EndDate, 0), @CurDate) >= @CurDate
        --       and isnull(nullif(ct.StartDate, 0), @CurDate) <= @CurDate
        --       and isnull(nullif(ct.EndDate, 0), @CurDate) >= @CurDate
        drop table if exists #Short_Position
        drop table if exists #Short_Position_Report
        select T = format(getdate(), 'yyyyMMdd')
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
          from QORT_DB_PROD.dbo.Position p with(nolock)
          inner join QORT_DB_PROD.dbo.Subaccs s with(nolock) on p.Subacc_ID = s.id
                                                                and s.SubaccCode like 'RB0%'
                                                                and s.ownerfirm_id <> 70736 /*-id=RESEC*/
          inner join QORT_DB_PROD.dbo.Firms f with(nolock) on s.ownerfirm_id = f.id
          inner join QORT_DB_PROD.dbo.Assets a with(nolock) on p.Asset_ID = a.id
          /*and 1 in(a.AssetType_Const, a.AssetClass_Const)*/
          inner join QORT_DB_PROD..AssetType_Const atc with(nolock) on atc.[Value] = a.AssetType_Const
          inner join QORT_DB_PROD..AssetClass_Const acc with(nolock) on acc.[Value] = a.AssetClass_Const
          inner join QORT_DB_PROD..AssetSort_Const asort with(nolock) on asort.[Value] = a.AssetSort_Const
          left join QORT_DB_PROD..Assets a2 with(nolock) on a2.id = a.BaseCurrencyAsset_ID
          inner join QORT_DB_PROD.dbo.Accounts aa with(nolock) on aa.id = p.account_id
         where 1 = 1
               and abs(p.VolFree) + abs(p.VolBlocked) + abs(p.VolForward) + abs(p.VolForwardOut) != 0
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
        --update sp
        --   set sp.CommissionName = ccr.Name
        --     , sp.CommissionRate = ccr.Rate
        --  from #Short_Position sp
        --  inner join #Current_CommissionRates ccr on sp.SubAccCode = ccr.Subacc
        --                                             and ccr.LongShort = 'Short'
        -- where sp.AssetType_Const = 'Securities'
        --update sp
        --   set sp.CommissionName = ccr.Name
        --     , sp.CommissionRate = ccr.Rate
        --  from #Short_Position sp
        --  inner join #Current_CommissionRates ccr on sp.SubAccCode = ccr.Subacc
        --                                             and sp.ShortName = ccr.CBName
        --                                             and ccr.LongShort = 'Long'
        -- where sp.AssetType_Const != 'Securities'
        create index IX_Short_Position on #Short_Position( SubAccCode, ShortName, Nostro )
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
               and 1 = case when @AddRUR = 0
                            then 1 when @AddRUR = 1
                                        and not('RUB' in ( isnull(sp.FaceAsset, sp.ShortName), sp.ShortName )
                       or 'RUR' in ( isnull(sp.FaceAsset, sp.ShortName), sp.ShortName ) )
                            then 1 when @AddRUR = 2
                                        and ('RUB' in ( isnull(sp.FaceAsset, sp.ShortName), sp.ShortName )
        or 'RUR' in ( isnull(sp.FaceAsset, sp.ShortName), sp.ShortName ) )
                            then 1
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
--                , sp.Nostro
        update spr
           set spr.VolForwardT0 = isnull(spr.VolForwardT0, 0) + 
		   isnull((select sum(qgcpf.T0) --over(partition by qgcpf.SubAccCode, qgcpf.Nostro, qgcpf.Currency, qgcpf.IsCoverage )
		   from QORT_DDM.dbo.QORT_GetCashPositionForward qgcpf where qgcpf.SubAccCode = spr.SubaccCode
                                                                       and qgcpf.Currency = spr.ShortName
                                                                       and qgcpf.Nostro = spr.Nostro collate Cyrillic_General_CI_AS
                                                                       and qgcpf.PayPlannedDate <= format(getdate(), 'yyyyMMdd')
																	   
          ),0)
          from #Short_Position_Report spr
         where spr.AssetType_Const <> 'Securities'
        update spr
           set spr.VolForwardT0 = isnull(spr.VolForwardT0, 0) + 
		  isnull((select sum( qgapf.T0)
          from QORT_DDM.dbo.QORT_GetAssetPositionForward qgapf where qgapf.SubAccCode = spr.SubaccCode
                                                                        and qgapf.AssetCode = spr.ShortName
                                                                        and qgapf.Nostro = spr.Nostro collate Cyrillic_General_CI_AS
                                                                        and qgapf.PutPlannedDate <= format(dateadd(hh, 1, getdate()), 'yyyyMMdd')
          ),0)
          from #Short_Position_Report spr
         where spr.AssetType_Const = 'Securities'
        select *
          from #Short_Position_Report spr
         where 1 = 1
               and 1 = case when @Style = 0
                            then 1 when @Style = 1
                                        and spr.AssetType_Const <> 'Securities'
                            then 1 when @Style = 2
                                        and spr.AssetType_Const = 'Securities'
                            then 1
                            else 0
                       end
        order by spr.T
               , spr.SubAccCode
               , spr.ISIN
    end
