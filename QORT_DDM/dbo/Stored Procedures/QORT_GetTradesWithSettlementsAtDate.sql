CREATE   procedure [dbo].[QORT_GetTradesWithSettlementsAtDate]( @Date date )
as
    begin
        declare @OperDate int = format(@Date, 'yyyyMMdd')
        drop table if exists #tmp_trades
        create table #tmp_trades
        ( ID           float
          primary key
        , RepoTrade_ID float )
        create index IX_RepoTrade_ID on #tmp_trades( RepoTrade_ID asc );
        with tmp_Trades
             as (select distinct 
                        p.Trade_ID
                   from QORT_DB_PROD.dbo.Phases p with (nolock, index = I_Phases_PhaseDate)
                  where p.PhaseDate = @OperDate
                        and p.PC_Const not in ( 17, 18, 20 ) /*PC_CANCEL, PC_CLOSE, PC_NULL*/    
        )
             insert into #tmp_trades
             select t.id
                  , t.RepoTrade_ID
               from QORT_DB_PROD.dbo.Trades t with (nolock, index = I_Trades_ID)
               inner join tmp_Trades tt on tt.Trade_ID = t.id
        insert into #tmp_trades
        select id = t.RepoTrade_ID
             , RepoTrade_ID = t.id
          from #tmp_trades t
         where t.RepoTrade_ID > 0
               and t.RepoTrade_ID not in( select t.ID
                                            from #tmp_trades t with(nolock) )
        /**/
        select ID = t.ID
             , RepoTrade_ID = t.RepoTrade_ID
             , Repo = iif(t.RepoTrade_ID > 0, iif(t.isrepo2 = 'n', '1 часть', '2 часть'), '')
             , t.TradeNum
             , t.OrderNum
             , TradeDate = stuff(stuff(nullif(t.TradeDate, 0), 7, 0, '-'), 5, 0, '-')
             , PutPlannedDate = stuff(stuff(nullif(t.PutPlannedDate, 0), 7, 0, '-'), 5, 0, '-')
             , PutDate = stuff(stuff(nullif(t.PutDate, 0), 7, 0, '-'), 5, 0, '-')
             , PayPlannedDate = stuff(stuff(nullif(t.PayPlannedDate, 0), 7, 0, '-'), 5, 0, '-')
             , PayDate = stuff(stuff(nullif(t.PayDate, 0), 7, 0, '-'), 5, 0, '-')
             , SubAccCode = isnull(( select top 1 cla.LoroAccount
                                       from QORT_DDM.dbo.ClientLoroAccount cla with(nolock)
                                      where cla.SubAccount = sub.SubAccCode collate Cyrillic_General_CI_AS ), sub.SubAccCode)
             , t.BuySell
             , GRDB = iif(isnumeric(a.Marking) = 0, 0, a.Marking)
             , DVCode = a.ShortName  /*NA*/
             , Security_Code = s.SecCode /*NA*/
             , a.ISIN
             , t.Qty
             , t.Price
             , Volume1 = t.Volume1 + iif(t.IsAccrued = 'y', 0, t.AccruedInt)
             , Volume1Nom = isnull(nullif(t.Volume1Nom, 0), round(t.Volume1 + iif(t.IsAccrued = 'y', 0, t.AccruedInt) / isnull(nullif(t.CrossRate, 0), 1), 2))
             , t.Accruedint
             , t.RepoRate
             , CurrPrice = currPrice.ShortName  /*NA*/
             , CurrPay = currPay.ShortName  /*NA*/
             , QFlags = case
                            when t.QFlags&131072 = 131072 then 'поручения'
                             else iif(sub.SubAccCode = 'RENBR', 'собственная', 'комиссии')
                        end
             , TSSection_Name = tss.Name /*NA*/
             , OwnerFirm_Name = ow.Name
             , OwnerFirm_BOCode = ow.BOCode
             , t.ClearingComission
             , CpFirm_ShortName = frm.FirmShortName  /*NA*/
             , CpFirm_BOCode = frm.BOCode
             , t.BONum
             , IsAccrued = iif(t.IsAccrued = 'y', 1, 0)
          from #tmp_trades tt
          inner join QORT_DB_PROD.dbo.Trades t with(nolock) on t.id = tt.id
          left join QORT_DB_PROD.dbo.Securities s with(nolock) on s.id = t.Security_ID
          left join QORT_DB_PROD.dbo.Assets a with(nolock) on a.id = s.Asset_ID
          left join QORT_DB_PROD.dbo.Subaccs sub with(nolock) on sub.id = t.SubAcc_ID
          left join QORT_DB_PROD.dbo.Firms ow with(nolock) on ow.id = sub.OwnerFirm_ID
          left join QORT_DB_PROD.dbo.TSSections as tss with(nolock) on tss.id = t.TSSection_ID
          left join QORT_DB_PROD.dbo.Firms as frm with(nolock) on frm.id = t.CpFirm_ID
          left join QORT_DB_PROD.dbo.Assets as currPay with(nolock) on currPay.id = t.CurrPayAsset_ID
          left join QORT_DB_PROD.dbo.Assets as currPrice with(nolock) on currPrice.id = t.CurrPriceAsset_ID
    end
