
CREATE   function [dbo].[QORT_Analytic_TradeAlerts] ( 
                @DateStart int
              , @TimeStart int
              , @DateEnd   int
              , @TimeEnd   int ) 
returns table
as
return
(select T.SystemID
	  , T.TradeDate TradeDate
      , T.ModifiedDate Date
      , T.ModifiedTime Time
      , Capacity = iif(SubAcc_Code = 'RENBR', 'Principal', 'Agency')
	  , case when TT_Const in (3,6) then 'REPO'	else 
		case when PT_Const = 1 then 'BOND' else
		 'EQUITY' end end Product
--	  , DA.IsProcessed
   from QORT_TDB_PROD..DataAlerts_Atom DA with (nolock, index=IX_DataAlerts_Atom_Date)
   inner loop join QORT_TDB_PROD..Trades T with(nolock, index=I_Trades_ID) on T.ID = DA.Record_ID
        and TT_Const in (1, 2, 3, 5, 6, 7, 14)
		and T.IsRepo2 = 'n'
	where 1=1
	    and T.TradeDate > 20190609
		and DA.Date between @DateStart and @DateEnd
        and DA.Time between @TimeStart and @TimeEnd
		--and DA.IsProcessed = 2
        )

/*
select * from [QORT_DDM].[dbo].[QORT_Analytic_TradeAlerts](20190114,90000000,20190114,190000000)
 where Product = 'BOND'
*/
