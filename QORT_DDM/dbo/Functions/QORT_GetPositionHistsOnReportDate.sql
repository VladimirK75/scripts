CREATE function [dbo].[QORT_GetPositionHistsOnReportDate]
( @ReportDate int )
returns table
as
     return
     ( select ph.OldDate
            , f.BOCode
            , f.Name
            , SynthSubAccCode = stuff(( select ',' + s.SubAccCode
                                          from QORT_DB_PROD.dbo.Subaccs s2 with(nolock)
                                          left join QORT_DB_PROD.dbo.SubaccStructure ss with(nolock) on s2.id = ss.Child_ID
                                                                                                        and ss.Enabled = 0
                                          left join QORT_DB_PROD.dbo.Subaccs s with(nolock) on s.id = ss.Father_ID
                                                                                               and s.IsAnalytic = 'y'
                                         where 1 = 1
                                               and s2.enabled = 0
                                               and s2.id = sub.id for xml path('') ), 1, 1, '')
            , sub.SubAccCode
            , sub.TradeCode
            , STAT = ac.Description
            , IsProhibitUseMoney = ( select max(ca.IsProhibitUseMoney)
                                       from QORT_DB_PROD.dbo.Subaccs s2 with(nolock)
                                       left join QORT_DB_PROD.dbo.SubaccStructure ss with(nolock) on s2.id = ss.Child_ID
                                                                                                     and ss.Enabled = 0
                                       left join QORT_DB_PROD.dbo.Subaccs s with(nolock) on s.id = ss.Father_ID
                                                                                            and s.IsAnalytic = 'y'
                                       left join QORT_DB_PROD.dbo.ClientAgrees ca with(nolock) on ca.SubAcc_ID in(s.id, s2.id)
                                                                                                  and ca.Enabled = 0
                                                                                                  /*and ca.Contact_ID > 0*/
                                                                                                  and @ReportDate between ca.DateCreate and isnull(nullif(ca.DateEnd, 0), @ReportDate)
                                      where 1 = 1
                                            and s2.id = sub.id )
            , acc.AccountCode
            , a.ShortName
            , a.ISIN
            , a.RegistrationCode
            , a.Marking
            , ph.VolFreeStart
            , ph.VolFree
            , ph.VolForward
            , ph.VolBlocked
            , ph.VolGO
            , VolForwardIn = ph.VolForward - ph.VolForwardOut
            , ph.VolForwardOut
            , ph.VolRepoIn
            , ph.VolRepoOut
         from (
                select OldDate=cast(format(getdate(),'yyyMMdd') as int)
                , ph.VolFreeStart
                , ph.VolFree
                , ph.VolForward
                , ph.VolBlocked
                , ph.VolGO
                , ph.VolForwardOut
                , ph.VolRepoIn
                , ph.VolRepoOut
                , ph.Account_ID
                , ph.Subacc_ID
                , ph.Asset_ID
                from QORT_DB_PROD..Position ph with(nolock)
                union all
                select ph.OldDate
                , ph.VolFreeStart
                , ph.VolFree
                , ph.VolForward
                , ph.VolBlocked
                , ph.VolGO
                , ph.VolForwardOut
                , ph.VolRepoIn
                , ph.VolRepoOut
                , ph.Account_ID
                , ph.Subacc_ID
                , ph.Asset_ID
                from QORT_DB_PROD..PositionHist ph with(nolock)
                ) as ph 
         inner join QORT_DB_PROD..Accounts acc with(nolock) on acc.id = ph.Account_ID
         inner join QORT_DB_PROD..Subaccs sub with(nolock) on sub.id = ph.Subacc_ID
         inner join QORT_DB_PROD..ACSTAT_Const ac with(nolock) on sub.ACSTAT_Const = ac.[Value]
         inner join QORT_DB_PROD..Assets a with(nolock) on ph.Asset_ID = a.id
         inner join QORT_DB_PROD..Firms f with(nolock) on f.id = sub.OwnerFirm_ID
                                                          and f.IsOurs = 'n'
        where 1 = 1
              and ph.OldDate = @ReportDate
              and abs(ph.VolFree) + abs(ph.VolBlocked) + abs(ph.VolForward) + abs(ph.VolForwardOut) + abs(ph.VolRepoIn) + abs(ph.VolRepoOut) > 0 )
