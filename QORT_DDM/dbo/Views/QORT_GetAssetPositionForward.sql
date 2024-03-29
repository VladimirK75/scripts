

CREATE view [dbo].[QORT_GetAssetPositionForward]
as
     select t.TradeDate
          , sub.SubAccCode
          , a.AccountCode
          , Nostro = QORT_DDM.dbo.GetDDM_NostroMapping( a.AccountCode, 'Единый пул', 0 )
          , a.IsCoverage
          , AssetCode = issue.ShortName
          , t.PutPlannedDate
          , T0 = iif(t.BuySell = 1, 1, -1)  * t.Qty
       from QORT_DB_PROD..Trades t with(nolock)
       inner join QORT_DB_PROD..TT_Const tc with(nolock) on tc.value = t.TT_Const
       inner join QORT_DB_PROD..TSSections ts with(nolock) on ts.id = t.TSSection_ID
       inner join QORT_DB_PROD..Subaccs sub with(nolock) on t.SubAcc_ID = sub.id
       inner join QORT_DB_PROD..Firms f with(nolock) on f.id = sub.OwnerFirm_ID
       inner join QORT_DB_PROD..Securities sec with(nolock) on t.Security_ID = sec.id
       inner join QORT_DB_PROD..Assets issue with(nolock) on issue.id = sec.Asset_ID
       inner join QORT_DB_PROD..Accounts a with(nolock) on t.PutAccount_ID = a.id
       left join QORT_DB_PROD..Phases p with (nolock, index = I_Phases_TradeID_PCConst) on p.Trade_ID = t.id
                                                                                           and p.PC_Const in(29, 17, 18, 20, 26, 4)
                                                                                           and p.IsCanceled = 'n'
																						   and p.PhaseDate in (select OperDate from qort_ddm.[dbo].[DDM_fn_DateRange]( QORT_DDM.dbo.DDM_fn_AddBusinessDay( null, -10, null ), QORT_DDM.dbo.DDM_fn_AddBusinessDay( null, +10, null ),0))
      where 1 = 1
            and t.PutDate = 0
            and t.TT_Const not in ( 4 )
            and t.TradeDate in (select OperDate from qort_ddm.[dbo].[DDM_fn_DateRange]( QORT_DDM.dbo.DDM_fn_AddBusinessDay( null, -10, null ), QORT_DDM.dbo.DDM_fn_AddBusinessDay( null, +10, null ),0))
            and p.id is null
            and t.Enabled = 0
            and t.PayPlannedDate in (select OperDate from qort_ddm.[dbo].[DDM_fn_DateRange]( QORT_DDM.dbo.DDM_fn_AddBusinessDay( null, -10, null ), QORT_DDM.dbo.DDM_fn_AddBusinessDay( null, +10, null ),0))
            and t.NullStatus = 'n'
