create   function QORT_GetCashPositionForward_T0
( @Loro     varchar(32)
, @Nostro   varchar(64)
, @Currency varchar(6) )
returns numeric(38, 2)
as
     begin
         declare @Result numeric(38, 2)  = 0
         select @Result = @Result + sum(iif(t.BuySell = 1, -1, 1) * t.Volume1)
           from QORT_DB_PROD..Trades t with (nolock, index = IX_Trades_DMA_DMC)
           inner join QORT_DB_PROD..TT_Const tc with(nolock) on tc.value = t.TT_Const
           inner join QORT_DB_PROD..TSSections ts with(nolock) on ts.id = t.TSSection_ID
           inner join QORT_DB_PROD..Subaccs sub with(nolock) on t.SubAcc_ID = sub.id
                                                                and sub.SubAccCode = @Loro
                                                                and sub.IsAnalytic = 'n'
                                                                and sub.Enabled = 0
           inner join QORT_DB_PROD..Firms f with(nolock) on f.id = sub.OwnerFirm_ID
           inner join QORT_DB_PROD..Assets cur with(nolock) on cur.id = t.CurrPayAsset_ID
                                                               and cur.CBName = @Currency
           inner join QORT_DB_PROD..Accounts a with(nolock) on t.PayAccount_ID = a.id
                                                               and QORT_DDM.dbo.GetDDM_NostroMapping( a.AccountCode, 'Единый пул', 0 ) = @Nostro
           left join QORT_DB_PROD..Phases p with (nolock, index = I_Phases_TradeID_PCConst) on p.Trade_ID = t.id
                                                                                               and p.PC_Const in(29, 17, 18, 20, 26, 7)
                                                                                               and p.IsCanceled = 'n'
                                                                                               and p.PhaseDate > QORT_DDM.dbo.DDM_fn_AddBusinessDay( null, -10, null )
          where 1 = 1
                and t.PayDate = 0
                and t.TT_Const not in ( 4 )
         and t.TradeDate > QORT_DDM.dbo.DDM_fn_AddBusinessDay( null, -10, null )
         and p.id is null
         and t.Enabled = 0
         and t.PayPlannedDate < QORT_DDM.dbo.DDM_fn_AddBusinessDay( null, 1, null )
         return isnull(@Result,0)
     end
