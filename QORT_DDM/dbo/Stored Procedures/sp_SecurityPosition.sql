CREATE procedure [dbo].[sp_SecurityPosition]
( @SubaccList varchar(255)
, @OperDate   date )
as
    begin
        set nocount on
        set @SubaccList = replace(@SubaccList, ' ', '');
        with tmp_trades
             as (select t.id
                      , t.SubAcc_ID
                      , t.TSSection_ID
                      , t.BuySell
                      , t.Qty
                      , t.CurrPayAsset_ID
                      , s.Asset_ID
                   from QORT_DB_PROD.dbo.Trades t with(nolock)
                   inner join QORT_DB_PROD.dbo.Securities s with(nolock) on t.Security_ID = s.id
                   inner join QORT_DB_PROD.dbo.Subaccs sub with(nolock) on t.SubAcc_ID = sub.id
                                                                           and concat(',', @SubaccList, ',') like concat('%,', sub.SubAccCode, ',%')
                  where 1 = 1
				        and t.IsRepo2='n'
                        and t.IsProcessed = 'y'
                        and t.TradeDate = format(@OperDate, 'yyyyMMdd')
                 union
                 select t.id
                      , t.SubAcc_ID
                      , t.TSSection_ID
                      , t.BuySell
                      , t.Qty
                      , t.CurrPayAsset_ID
                      , s.Asset_ID
                   from QORT_DB_PROD.dbo.Trades t with(nolock)
                   inner join QORT_DB_PROD.dbo.Securities s with(nolock) on t.Security_ID = s.id
                   inner join QORT_DB_PROD.dbo.Subaccs sub with(nolock) on t.SubAcc_ID = sub.id
                                                                           and concat(',', @SubaccList, ',') like concat('%,', sub.SubAccCode, ',%')
                  where 1 = 1
                        and t.IsProcessed = 'y'
                        and t.PutDate = format(@OperDate, 'yyyyMMdd')
                 union
                 select t.id
                      , t.SubAcc_ID
                      , t.TSSection_ID
                      , t.BuySell
                      , t.Qty
                      , t.CurrPayAsset_ID
                      , s.Asset_ID
                   from QORT_DB_PROD.dbo.Trades t with(nolock)
                   inner join QORT_DB_PROD.dbo.Securities s with(nolock) on t.Security_ID = s.id
                   inner join QORT_DB_PROD.dbo.Subaccs sub with(nolock) on t.SubAcc_ID = sub.id
                                                                           and concat(',', @SubaccList, ',') like concat('%,', sub.SubAccCode, ',%')
                  where 1 = 1
                        and t.IsProcessed = 'y'
                        and t.PutPlannedDate = format(@OperDate, 'yyyyMMdd'))
             select SubAcc = max(s.SubAccCode)
                  , FirmShortName = max(own.FirmShortName)
                  , TSSection = max(t.Name)
                  , Asset = max(a.ShortName)
                  , Curr = max(cur.ViewName)
                  , Position = sum(tt.Qty * iif(tt.BuySell = 1, 1, -1))
               from tmp_trades tt
               inner join QORT_DB_PROD.dbo.Subaccs s with(nolock) on tt.SubAcc_ID = s.id
               inner join QORT_DB_PROD.dbo.Firms own with(nolock) on s.OwnerFirm_ID = own.id
               left join QORT_DB_PROD.dbo.TSSections t with(nolock) on t.id = tt.TSSection_ID
               left join QORT_DB_PROD.dbo.Assets cur with(nolock) on tt.CurrPayAsset_ID = cur.id
               inner join QORT_DB_PROD.dbo.Assets a with(nolock) on a.id = tt.Asset_ID
                                                                    and a.AssetClass_Const not in(1, 2, 3, 4, 13)
              where 1 = 1
                    and not exists( select 1
                                      from QORT_DB_PROD.dbo.Phases p with(nolock)
                                     where 1 = 1
                                           and p.Trade_ID = tt.id
                                           and tt.TSSection_ID != -1
                                           and p.PC_Const in ( 17, 27, 29 )
                                    and p.IsCanceled = 'n' )
              group by tt.SubAcc_ID
                     , tt.TSSection_ID
                     , tt.Asset_ID
                     , tt.CurrPayAsset_ID
              having sum(tt.Qty * iif(tt.BuySell = 1, 1, -1)) != 0
    end
