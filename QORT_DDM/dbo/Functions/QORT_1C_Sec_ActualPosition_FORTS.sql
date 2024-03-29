CREATE function [dbo].[QORT_1C_Sec_ActualPosition_FORTS](
               @date int)
returns table
as
return
with ActualPos(ShortName
             , ISIN
             , Marking
			 , ActualPos
             , TheorPos)
     as (select a.ShortName
              , a.ISIN
              , Marking=isnull(cast(gm.GrdbId as varchar(32)),a.Marking)
              , ActualPos = ph.volfree
              , TheorPos = ph.volfree + ph.volblocked + ph.VolForward
           from QORT_DB_PROD..PositionHist ph with (nolock, index = PK_PositionHist)
           inner join QORT_DB_PROD..subaccs sub with(nolock) on ph.SubAcc_ID = sub.id
                                                                and sub.OwnerFirm_ID = 70746
           inner join QORT_DB_PROD..Assets a with(nolock) on a.id = ph.Asset_ID
                                                             and a.AssetClass_Const in(3, 4) /*AC_FUT, AC_OPT*/
                                                             and a.AssetType_Const = 2 /*AT_FO*/
                                                             and a.AssetSort_Const in(17, 18, 19) /*AS_FUT, AS_OPT_PUT, AS_OPT_CALL*/
	      left join GRDBServices.Publication.GrdbMap gm with(nolock) on a.id=gm.QortId
          where 1 = 1
                and ph.OldDate = @date
                and ph.Account_ID not in (3177, 2279, 3178, 3179, 2180) )
     select a.ShortName
          , a.ISIN
          , a.Marking
          , ActualPos = sum(a.ActualPos)
		  , TheorPos = sum(a.TheorPos)
       from ActualPos a
      group by a.ShortName
             , a.ISIN
             , a.Marking
      having sum(TheorPos)+sum(a.ActualPos) <> 0
