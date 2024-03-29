CREATE function dbo.QORT_GetLimitDepo()
returns table
as
     return
     ( select Limit = 'DEPO'
            , FIRM_ID = 'MC0089500000'
            , SECCODE
            , CLIENT_CODE
            , OPEN_BALANCE
            , OPEN_LIMIT = cast(0 as float)
            , TRDACCID
            , WA_POSITION_PRICE = 0
            , LIMIT_KIND = right(LIMIT_KIND, 1)
         from( select SECCODE = ( select top 1 s.SecCode
                                    from QORT_DB_PROD..Securities s
                                    inner join QORT_DB_PROD..TSSections t with(nolock) on s.TSSection_ID = t.id
                                   where s.Asset_ID = a.ID
                                         and s.Enabled = 0
                                  order by iif(t.TS_ID = 1, acc.TS_ID, t.TS_ID)
                                         , iif(s.IsPriority = 'y', 0, 1)
                                         , iif(s.SecCode = 'USD000UTSTOM', 0, 1)
                                         , s.id desc )
                    , CLIENT_CODE = isnull(nullif(sub.TradeCode, ''), sub.SubAccCode)
                    , OPEN_BALANCE_0 = sum(round(p.VolFree + p.VolBlocked, 2))
                    , OPEN_BALANCE_1 = sum(round(p.VolFree + p.VolForward, 2))
                    , OPEN_BALANCE_2 = sum(round(p.VolFree + p.VolForward, 2))
                    , TRDACCID = isnull(nullif(min(acc.TradeCOde), ''), 'L26+00000F11')
                 from QORT_DB_PROD..Position p with(nolock)
                 inner join QORT_DB_PROD..Accounts acc with(nolock) on p.Account_ID = acc.id
                                                                       and acc.IsCoverage = 'y'
                                                                       and acc.IsTrade = 'y'
                 inner join QORT_DB_PROD.dbo.Subaccs sub with(nolock) on p.Subacc_ID = sub.id
                                                                         and sub.SubaccCode not in('RB0047')
                 inner join QORT_DB_PROD..Assets a with(nolock) on p.Asset_ID = a.id
                                                                   and a.AssetType_Const = 1
                where 1 = 1
                      and cast(abs(p.VolFree) as money) + cast(abs(p.VolBlocked) as money) + cast(abs(p.VolForward) as money) != 0
                group by isnull(nullif(sub.TradeCode, ''), sub.SubAccCode)
                       , a.ID
                       , a.AssetType_Const
                       , acc.TS_ID ) as p unpivot(OPEN_BALANCE for LIMIT_KIND in(OPEN_BALANCE_0
                                                                               , OPEN_BALANCE_1
                                                                               , OPEN_BALANCE_2)) as unpvt )
