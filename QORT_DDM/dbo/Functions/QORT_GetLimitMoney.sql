CREATE function [dbo].[QORT_GetLimitMoney]()
returns table
as
     return
     ( select Limit = 'MONEY'
            , FIRM_ID = 'MC0089500000'
            , TAG = 'EQTV'
            , CURR_CODE
            , CLIENT_CODE
            , OPEN_BALANCE
            , OPEN_LIMIT = cast(0 as float)
            , LEVERAGE
            , LIMIT_KIND = right(LIMIT_KIND, 1)
         from( select CURR_CODE = a.ShortName
                    , CLIENT_CODE = sub.SubaccCode
                    , OPEN_BALANCE_0 = round(sum(p.VolFree + p.VolBlocked), 2)
                    , OPEN_BALANCE_1 = round(sum(p.VolFree + p.VolBlocked + p.VolForward ), 2)
                    , OPEN_BALANCE_2 = round(sum(p.VolFree + p.VolBlocked + p.VolForward ), 2)
                    , LEVERAGE = max(cast(sub.Leverage as numeric(18, 2)))
                 from QORT_DB_PROD..Position p with(nolock)
                 inner join QORT_DB_PROD..Accounts acc with(nolock) on p.Account_ID = acc.id
                                                                       and acc.IsCoverage = 'y'
                                                                       and acc.IsTrade = 'y'
                                                                       and acc.Market&2 != 2 /* without FORTS */
                                                                       and acc.AssetType != 2 /* without FORTS */
                 inner join QORT_DB_PROD.dbo.Subaccs sub with(nolock) on p.Subacc_ID = sub.id
                                                                         and sub.IsQUIK = 'y'
                                                                         and sub.FirmCode != ''
                                                                         and sub.SubAccCode = sub.TradeCode
																		 and sub.SubaccCode not in ('RB0047','RB0331')
                 inner join QORT_DB_PROD..Assets a with(nolock) on p.Asset_ID = a.id
                                                                   and a.AssetType_Const = 3
                where 1 = 1
                      and cast(abs(p.VolFree) as money) + cast(abs(p.VolBlocked) as money) + cast(abs(p.VolForward) as money) + cast(abs(p.VolForwardOut) as money) != 0
                group by sub.SubaccCode
                       , a.ShortName ) as p unpivot(OPEN_BALANCE for LIMIT_KIND in(OPEN_BALANCE_0
                                                                                 , OPEN_BALANCE_1
                                                                                 , OPEN_BALANCE_2)) as unpvt )
