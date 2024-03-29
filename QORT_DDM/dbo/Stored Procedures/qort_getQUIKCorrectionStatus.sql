CREATE procedure [dbo].[QORT_getQUIKCorrectionStatus]( @GetDate date )
as
    begin
        declare @CurrentDate date = '2020-09-11'
              , @T0DateInt   int
              , @T1DateInt   int
              , @T2DateInt   int
        set @CurrentDate = isnull(@GetDate, @CurrentDate)
        set @T0DateInt = format(@CurrentDate, 'yyyyMMdd')
        set @T1DateInt = QORT_DDM.dbo.DDM_fn_AddBusinessDay( @T0DateInt, 1, null )
        set @T2DateInt = QORT_DDM.dbo.DDM_fn_AddBusinessDay( @T0DateInt, 2, null )
        drop table if exists #tmp_QuikCorrections
        drop table if exists #tmp_QUIKvsQORT
        drop table if exists #tmp_QORTTrades
        drop table if exists #tmp_Result
        drop table if exists #tmp_Aggregate
        create table #tmp_QUIKCorrections
        ( Date               date
        , ReferenceID        varchar(50)
        , ClientCode         varchar(12)
        , TrdAcc             varchar(50)
        , CorrectionType     varchar(32)
        , CurrCode           varchar(3)
        , CurrLimitT0Value   numeric(18,2)
        , CurrLimitT1Value   numeric(18,2)
        , CurrLimitT2Value   numeric(18,2)
        , ComissCurrCode     varchar(3)
        , ComissValue        numeric(18,2)
        , ISIN               varchar(50)
        , GRDBID             varchar(20)
        , ActiveLimitT0Value numeric(18,2)
        , ActiveLimitT1Value numeric(18,2)
        , ActiveLimitT2Value numeric(18,2)
        , status             smallint )
        insert into #tmp_QUIKCorrections
        exec QUIK_73.Qexport.dbo.getquikcorrectionstatus @date = @CurrentDate
                                                       , @Type = 'QortTable'
        update tq
           set tq.CurrCode = replace(tq.CurrCode, 'RUR', 'RUB')
          from #tmp_QUIKCorrections tq
         where tq.CurrCode like '%RUR%'
        select tq.[Date]
             , tq.ReferenceID
             , tq.ClientCode
             , TrdAcc = cast(max(tq.TrdAcc) as varchar(50))
             , CurrCode = max(tq.CurrCode)
             , CurrLimitT0Value = sum(tq.CurrLimitT0Value)
             , CurrLimitT1Value = sum(tq.CurrLimitT1Value)
             , CurrLimitT2Value = sum(tq.CurrLimitT2Value)
             , ComissTradeCode = cast(max(tq.TrdAcc) as varchar(50))
             , ComissCurrCode = max(tq.ComissCurrCode)
             , ComissValue = sum(tq.ComissValue)
             , ISIN = max(tq.ISIN)
             , ActiveLimitT0Value = sum(tq.ActiveLimitT0Value)
             , ActiveLimitT1Value = sum(tq.ActiveLimitT1Value)
             , ActiveLimitT2Value = sum(tq.ActiveLimitT2Value)
             , Infosource = 'QUIK'
        into #tmp_QUIKvsQORT
          from #tmp_QUIKCorrections tq
         where 1 = 1
               and tq.status = 1
         group by tq.[Date]
                , tq.ReferenceID
                , tq.ClientCode
        select distinct 
               t.id
        into #tmp_QORTTrades
          from( select t.id
                  from QORT_DB_PROD..Trades t with(nolock)
                  inner join QORT_DB_PROD..TSSections t2 with(nolock) on t2.id = t.TSSection_ID
                  inner join QORT_DB_PROD..TSs t3 with(nolock) on t3.id = t2.TS_ID
                                                                  and t3.IsMarket = 'n'
                  inner join QORT_DDM.dbo.QORT_GetLoroList( 'RB%' ) gl on t.SubAcc_ID = gl.Subacc_ID
				  and gl.Loro != 'RB0047'
                 where 1 = 1
                       and t.TradeDate = @T0DateInt
                       and t.NullStatus = 'n'
                       and t.Enabled = 0
                union 
                select t.id
                  from QORT_DB_PROD..Trades t with (nolock, index = I_Trades_ModifiedDate)
                  inner join QORT_DB_PROD..TSSections t2 with(nolock) on t2.id = t.TSSection_ID
                  inner join QORT_DB_PROD..TSs t3 with(nolock) on t3.id = t2.TS_ID
                                                                  and t3.IsMarket = 'n'
                  inner join QORT_DDM.dbo.QORT_GetLoroList( 'RB%' ) gl on t.SubAcc_ID = gl.Subacc_ID
				  and gl.Loro != 'RB0047'
                 where 1 = 1
                       and t.modified_date = @T0DateInt
                       and t.NullStatus = 'n'
                       and t.Enabled = 0
					   and t.RepoTrade_ID < 0
                union 
                select t.id
                  from QORT_DB_PROD..Trades t with(nolock)
                  inner join QORT_DB_PROD..Phases p with(nolock) on t.id = p.Trade_ID
                                                                    and p.PhaseDate in(@T0DateInt, @T1DateInt, @T2DateInt)
                                                                    and p.IsCanceled = 'n'
                  inner join QORT_DB_PROD..TSSections t2 with(nolock) on t2.id = t.TSSection_ID
                  inner join QORT_DB_PROD..TSs t3 with(nolock) on t3.id = t2.TS_ID
                                                                  and t3.IsMarket = 'n'
                  inner join QORT_DDM.dbo.QORT_GetLoroList( 'RB%' ) gl on t.SubAcc_ID = gl.Subacc_ID
				  and gl.Loro != 'RB0047'
                 where 1 = 1
                       and t.NullStatus = 'n'
                       and t.Enabled = 0 ) t
        insert into #tmp_QUIKvsQORT
        select Date = cast(cast(t.TradeDate as varchar) as date)
             , ReferenceID = t.AgreeNum
             , ClientCode = gl.Loro
             , TrdAcc = cast(isnull(nullif(acc.TradeCOde, ''), acc.ExportCode) as varchar(50))
             , CurrCode = replace(max(t.CurrPayAsset_ShortName), 'RUR', 'RUB')
             , CurrLimitT0Value = cast(sum(iif(t.PayPlannedDate <  = @T0DateInt, t.Volume1 * (2 * t.BuySell - 3), 0)) as numeric(18, 2))
             , CurrLimitT1Value = cast(sum(iif(t.PayPlannedDate > @T0DateInt
                                               and t.PayPlannedDate <  = @T1DateInt
											   or ( t.IsRepo2 = 'n' and t.PutPlannedDate <= @T0DateInt and t.PutPlannedDate = t.TradeDate), t.Volume1 * (2 * t.BuySell - 3), 0)) as numeric(18, 2))
             , CurrLimitT2Value = cast(sum(iif(t.PayPlannedDate between @T1DateInt and @T2DateInt
                                               or t.PayPlannedDate > @T2DateInt
											   or ( t.IsRepo2 = 'n' and t.PutPlannedDate <= @T0DateInt and t.PutPlannedDate = t.TradeDate), t.Volume1 * (2 * t.BuySell - 3), 0)) as numeric(18, 2))
             , ComissTradeCode = cast('' as varchar(50))
             , ComissCurrCode = null
             , ComissValue = cast(0 as numeric(18, 2))
             , ISIN = max(t.Asset_ISIN)
             , ActiveLimitT0Value = cast(sum(iif(isnull(nullif(t.PutDate,0),t.PutPlannedDate)  = @T0DateInt, t.Qty * (3 - 2 * t.BuySell), 0)) as bigint)
             , ActiveLimitT1Value = cast(sum(iif((isnull(nullif(t.PutDate,0),t.PutPlannedDate)  > @T0DateInt
                                                 and isnull(nullif(t.PutDate,0),t.PutPlannedDate) <= @T1DateInt)
												 or ( t.IsRepo2 = 'n' and isnull(nullif(t.PutDate,0),t.PutPlannedDate) <= @T0DateInt and isnull(nullif(t.PutDate,0),t.PutPlannedDate) = t.TradeDate), t.Qty * (3 - 2 * t.BuySell), 0)) as bigint)
             , ActiveLimitT2Value = cast(sum(iif(isnull(nullif(t.PutDate,0),t.PutPlannedDate) between @T1DateInt and @T2DateInt
                                                 or isnull(nullif(t.PutDate,0),t.PutPlannedDate) > @T2DateInt
												 or ( t.IsRepo2 = 'n' and isnull(nullif(t.PutDate,0),t.PutPlannedDate) <= @T0DateInt and isnull(nullif(t.PutDate,0),t.PutPlannedDate) = t.TradeDate), t.Qty * (3 - 2 * t.BuySell), 0)) as bigint)
             , Infosource = 'QORT'
          from QORT_TDB_PROD..Trades t with(nolock)
          inner join QORT_DB_PROD..Trades t0 with(nolock) on t0.id = t.SystemID
          inner join QORT_DB_PROD..Accounts acc with(nolock) on t0.PutAccount_ID = acc.id
          inner join #tmp_QORTTrades tt on t.SystemID = tt.id
                                           and t.SubAcc_Code != 'RB0047'
          inner join QORT_DB_PROD..TSSections t2 with(nolock) on t2.Name = t.TSSection_Name
          inner join QORT_DB_PROD..TSs t3 with(nolock) on t3.id = t2.TS_ID
                                                          and t3.IsMarket = 'n'
          inner join QORT_DDM.dbo.QORT_GetLoroList( 'RB%' ) gl on t.SubAcc_Code = gl.Loro collate Cyrillic_General_CS_AS
         where 1 = 1
		 and t.NullStatus='n'
         group by t.TradeDate
                , t.AgreeNum
                , gl.Loro
                , cast(isnull(nullif(acc.TradeCOde, ''), acc.ExportCode) as varchar(50)) option(loop join)
        insert into #tmp_QUIKvsQORT
        select Date = cast(cast(t.TradeDate as varchar) as date)
             , ReferenceID = t.AgreeNum
             , ClientCode = gl.Loro
             , TrdAcc = null
             , CurrCode = null
             , CurrLimitT0Value = cast(0 as numeric(18, 2))
             , CurrLimitT1Value = cast(0 as numeric(18, 2))
             , CurrLimitT2Value = cast(0 as numeric(18, 2))
             , ComissTradeCode = isnull(nullif(cast(acc.TradeCOde as varchar(50)), ''), QORT_DDM.dbo.DDM_GetTradeAccount( gl.Loro ))
             , ComissCurrCode = replace(max(Currency.ShortName), 'RUR', 'RUB')
             , ComissValue = cast(sum(iif(bcot.[Date] >  = @T0DateInt
                                          or bcot.created_date = @T0DateInt, isnull(-1 * bcot.Size, 0), 0)) as numeric(18, 2))
             , ISIN = null
             , ActiveLimitT0Value = cast(0 as numeric(18, 2))
             , ActiveLimitT1Value = cast(0 as numeric(18, 2))
             , ActiveLimitT2Value = cast(0 as numeric(18, 2))
             , Infosource = 'QORT'
          from QORT_TDB_PROD..Trades t with(nolock)
          inner join #tmp_QORTTrades tt on t.SystemID = tt.id
                                           and t.SubAcc_Code != 'RB0047'
          inner join QORT_DB_PROD..TSSections t2 with(nolock) on t2.Name = t.TSSection_Name
          inner join QORT_DB_PROD..TSs t3 with(nolock) on t3.id = t2.TS_ID
                                                          and t3.IsMarket = 'n'
          inner join QORT_DDM.dbo.QORT_GetLoroList( 'RB%' ) gl on t.SubAcc_Code = gl.Loro collate Cyrillic_General_CS_AS
          left join QORT_DB_PROD..BlockCommissionOnTrades bcot with(nolock) on bcot.Trade_ID = t.SystemID
                                                                               and bcot.Subacc_ID = gl.Subacc_ID
          inner join QORT_DB_PROD..Accounts acc with(nolock) on bcot.Account_ID = acc.id
          left join QORT_DB_PROD..Assets Currency with(nolock) on bcot.Calc_Currency_ID = Currency.id
         where 1 = 1
		 and t.NullStatus='n'
         group by t.TradeDate
                , t.AgreeNum
                , gl.Loro
                , isnull(nullif(cast(acc.TradeCOde as varchar(50)), ''), QORT_DDM.dbo.DDM_GetTradeAccount( gl.Loro )) 
		option(loop join)
        insert into #tmp_QUIKvsQORT
        select Date = cast(cast(t.TradeDate as varchar) as date)
             , ReferenceID = t.AgreeNum
             , ClientCode = gl.Loro
             , TrdAcc = isnull(nullif(cast(acc.TradeCOde as varchar(50)), ''), QORT_DDM.dbo.DDM_GetTradeAccount( gl.Loro ))
             , CurrCode = replace(max(t.CurrPayAsset_ShortName), 'RUR', 'RUB')
             , CurrLimitT0Value = cast(sum(iif(p.PC_Const in(5, 7), p.QtyBefore * (2 * t.BuySell - 3), 0)) as numeric(18, 2))
             , CurrLimitT1Value = 0
             , CurrLimitT2Value = 0
             , ComissTradeCode = null
             , ComissCurrCode = null
             , ComissValue = cast(sum(0) as numeric(18, 2))
             , ISIN = max(t.Asset_ISIN)
             , ActiveLimitT0Value = cast(sum(iif(p.PC_Const in(3, 4), p.QtyBefore * (3 - 2 * t.BuySell), 0)) as bigint)
             , ActiveLimitT1Value = cast(sum(iif(t.IsRepo2 = 'y', 0, iif(p.PC_Const in(3, 4), p.QtyBefore * (3 - 2 * t.BuySell), 0))) as bigint)
             , ActiveLimitT2Value = cast(sum(iif(t.IsRepo2 = 'y', 0, iif(p.PC_Const in(3, 4), p.QtyBefore * (3 - 2 * t.BuySell), 0))) as bigint)
             , Infosource = 'QORT'
          from QORT_TDB_PROD..Trades t with(nolock)
          inner join QORT_DB_PROD..Phases p with (nolock, index = I_Phases_PhaseDate_PCConst) on p.Trade_ID = t.SystemID
                                                                                                 and p.PhaseDate = @T0DateInt
                                                                                                 and isnull(p.IsCanceled, 'n') = 'n'
                                                                                                 and p.PC_Const in(3, 4, 5, 7)
          inner join QORT_DB_PROD..Accounts acc with(nolock) on p.PhaseAccount_ID = acc.id
          inner join QORT_DB_PROD..TSSections t2 with(nolock) on t2.Name = t.TSSection_Name
          inner join QORT_DB_PROD..TSs t3 with(nolock) on t3.id = t2.TS_ID
                                                          and t3.IsMarket = 'n'
          inner join QORT_DDM.dbo.QORT_GetLoroList( 'RB%' ) gl on t.SubAcc_Code = gl.Loro collate Cyrillic_General_CS_AS
         where 1 = 1
               and t.NullStatus = 'n'
               and not exists( select 1
                                 from #tmp_QORTTrades tt
                                where t.SystemID = tt.id )
         group by t.TradeDate
                , t.AgreeNum
                , gl.Loro
                , isnull(nullif(cast(acc.TradeCOde as varchar(50)), ''), QORT_DDM.dbo.DDM_GetTradeAccount( gl.Loro ))
        insert into #tmp_QUIKvsQORT
        select Date = cast(cast(ecp.RegistrationDate as varchar) as date)
             , ReferenceID = iif(ecp.infosource = 'BackOffice', left(ecp.comment2, charindex('/', ecp.comment2) - 1), ecp.infosource)
             , ClientCode = gl.Loro
             , TrdAcc = QORT_DDM.dbo.DDM_GetTradeAccount( gl.Loro )
             , CurrCode = iif(ecp.CurrencyAsset_ShortName = ecp.Asset_ShortName, replace(ecp.CurrencyAsset_ShortName, 'RUR', 'RUB'), null)
             , CurrLimitT0Value = cast(sum(iif(ecp.CurrencyAsset_ShortName = ecp.Asset_ShortName, ecp.Size, 0)) as numeric(18, 2))
             , CurrLimitT1Value = cast(sum(iif(ecp.CurrencyAsset_ShortName = ecp.Asset_ShortName, ecp.Size, 0)) as numeric(18, 2))
             , CurrLimitT2Value = cast(sum(iif(ecp.CurrencyAsset_ShortName = ecp.Asset_ShortName, ecp.Size, 0)) as numeric(18, 2))
             , ComissTradeCode = null
             , ComissCurrCode = null
             , ComissValue = cast(0 as numeric(18, 2))
             , ISIN = iif(ecp.CurrencyAsset_ShortName != ecp.Asset_ShortName, a.ISIN, null)
             , ActiveLimitT0Value = cast(sum(iif(ecp.CurrencyAsset_ShortName !  = ecp.Asset_ShortName, ecp.Size, 0)) as numeric(18, 2))
             , ActiveLimitT1Value = cast(sum(iif(ecp.CurrencyAsset_ShortName !  = ecp.Asset_ShortName, ecp.Size, 0)) as numeric(18, 2))
             , ActiveLimitT2Value = cast(sum(iif(ecp.CurrencyAsset_ShortName !  = ecp.Asset_ShortName, ecp.Size, 0)) as numeric(18, 2))
             , Infosource = 'QORT'
          from QORT_TDB_PROD..ExportCorrectPositions ecp with(nolock)
          inner join QORT_DDM.dbo.QORT_GetLoroList( 'RB%' ) gl on ecp.Subacc_Code = gl.Loro collate Cyrillic_General_CS_AS
          left join QORT_DB_PROD.dbo.Assets a with(nolock) on a.ShortName = ecp.Asset_ShortName
                                                              and a.Enabled = 0
         where 1 = 1
               and @T0DateInt in ( ecp.RegistrationDate, ecp.ModifiedDate, ecp.[Date] )
        and ecp.Subacc_Code not in ( 'RB0047', 'RB0331' )
        and ecp.IsCanceled = 'n'
        and ecp.IsInternal = 'n'
        and len(ecp.BackID) > 9
        and len(ecp.BackID) - len(REPLACE(backid, '/', '')) in ( 1, 2 )
         /* and QORT_DDM.dbo.DDM_GetTradeAccount( gl.Loro ) is not null*/  
         group by ecp.RegistrationDate
                , iif(ecp.infosource = 'BackOffice', left(ecp.comment2, charindex('/', ecp.comment2) - 1), ecp.infosource)
                , gl.Loro
                , iif(ecp.CurrencyAsset_ShortName = ecp.Asset_ShortName, replace(ecp.CurrencyAsset_ShortName, 'RUR', 'RUB'), null)
                , QORT_DDM.dbo.DDM_GetTradeAccount( gl.Loro )
                , iif(ecp.CurrencyAsset_ShortName != ecp.Asset_ShortName, a.ISIN, null)
        insert into #tmp_QUIKvsQORT
        select Date = cast(cast(cl.RegistrationDate as varchar) as date)
             , ReferenceID = concat('CL', cl.PDocNum)
             , ClientCode = gl.Loro
             , TrdAcc = QORT_DDM.dbo.DDM_GetTradeAccount( gl.Loro )
             , CurrCode = replace(ecl.CurrencyAsset_ShortName, 'RUR', 'RUB')
             , CurrLimitT0Value = cast(ecl.Volume as numeric(18, 2))
             , CurrLimitT1Value = cast(ecl.Volume as numeric(18, 2))
             , CurrLimitT2Value = cast(ecl.Volume as numeric(18, 2))
             , ComissTradeCode = null
             , ComissCurrCode = null
             , ComissValue = cast(0 as numeric(18, 2))
             , ISIN = null
             , ActiveLimitT0Value = cast(0 as numeric(18, 2))
             , ActiveLimitT1Value = cast(0 as numeric(18, 2))
             , ActiveLimitT2Value = cast(0 as numeric(18, 2))
             , Infosource = 'QORT'
          from QORT_DB_PROD..Clearings cl with(nolock)
          inner join QORT_TDB_PROD..Clearings ecl with(nolock) on ecl.SystemID = cl.id
          inner join QORT_DDM.dbo.QORT_GetLoroList( 'RB%' ) gl on ecl.MonSubAcc_Code = gl.Loro collate Cyrillic_General_CS_AS
         where 1 = 1
               and @T0DateInt in ( cl.[Date], cl.modified_date, cl.RegistrationDate )
        and cl.CL_Const = 1 /* Coupon */
        select tq.[Date]
             , tq.ReferenceID
             , tq.ClientCode
             , TrdAcc = cast(tq.TrdAcc as varchar(50))
             , Assets = tq.CurrCode
             , LimitT0 = tq.CurrLimitT0Value
             , LimitT1 = tq.CurrLimitT1Value
             , LimitT2 = tq.CurrLimitT2Value
             , Infosource = tq.Infosource
        into #tmp_Result
          from #tmp_QUIKvsQORT tq
         where 1 = 1
               /*and nullif(tq.ISIN, '') is not null*/
               and 0 < abs(tq.CurrLimitT0Value) + abs(tq.CurrLimitT1Value) + abs(tq.CurrLimitT2Value)
        union
        select tq.[Date]
             , tq.ReferenceID
             , tq.ClientCode
             , tq.TrdAcc
             , Assets = tq.ISIN
             , LimitT0 = tq.ActiveLimitT0Value
             , LimitT1 = tq.ActiveLimitT1Value
             , LimitT2 = tq.ActiveLimitT2Value
             , Infosource = tq.Infosource
          from #tmp_QUIKvsQORT tq
         where 1 = 1
               and nullif(tq.ISIN, '') is not null
               and 0 < abs(tq.ActiveLimitT0Value) + abs(tq.ActiveLimitT1Value) + abs(tq.ActiveLimitT2Value)
        union
        select tq.[Date]
             , tq.ReferenceID
             , tq.ClientCode
             , tq.ComissTradeCode
             , Assets = tq.ComissCurrCode
             , LimitT0 = tq.ComissValue
             , LimitT1 = 0
             , LimitT2 = 0
             , Infosource = tq.Infosource
          from #tmp_QUIKvsQORT tq
         where 1 = 1 /*nullif(tq.ISIN, '') is not null*/
               and 0 < abs(tq.ComissValue)
        select t.[Date]
             , t.ReferenceID
             , t.ClientCode
             , t.TrdAcc
             , t.Assets
             , LimitT0 = sum(LimitT0)
             , LimitT1 = sum(LimitT1)
             , LimitT2 = sum(LimitT2)
             , t.Infosource
        into #tmp_Aggregate
          from #tmp_Result t
         group by t.[Date]
                , t.ReferenceID
                , t.ClientCode
                , t.TrdAcc
                , t.Assets
                , t.Infosource
        select date = isnull(qort.[Date], quik.[Date])
             , ReferenceID = isnull(qort.ReferenceID, quik.ReferenceID)
             , ClientCode = isnull(qort.ClientCode, quik.ClientCode)
             , QorTrdAcc = qort.TrdAcc
             , QuikTrdAcc = isnull(nullif(quik.TrdAcc, ''), qort.TrdAcc)
             , Assets = isnull(qort.Assets, quik.Assets)
             , QUIK_T0 = isnull(quik.LimitT0, 0)
             , QUIK_T1 = isnull(quik.LimitT1, 0)
             , QUIK_T2 = isnull(quik.LimitT2, 0)
             , QORT_T0 = isnull(qort.LimitT0, 0)
             , QORT_T1 = isnull(qort.LimitT1, 0)
             , QORT_T2 = isnull(qort.LimitT2, 0)
          from #tmp_Aggregate quik
          full outer join #tmp_Aggregate qort on qort.ReferenceID = quik.ReferenceID
                                                 and qort.ClientCode = quik.ClientCode
                                                 /* and qort.TrdAcc = isnull(nullif(quik.TrdAcc, ''), qort.TrdAcc)*/
                                                 and qort.Assets = quik.Assets
                                                 and qort.Infosource = 'QORT'
         where 1 = 1
               and quik.Infosource = 'QUIK'
    end
