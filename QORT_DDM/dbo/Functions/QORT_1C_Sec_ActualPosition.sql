CREATE   function [dbo].[QORT_1C_Sec_ActualPosition](
               @date int)
returns table
as
return
(select a.ShortName
      , a.ISIN
      , a.Marking
      , sum(asd.TheorPos) as ActualPos
   from (select ph.Subacc_ID
              , ph.Asset_ID
              , TheorPos = sum(ph.volfree) --+ sum(ph.volblocked) + sum(ph.VolForward)
           from QORT_DB_PROD..PositionHist ph with(nolock, index=PK_PositionHist)
          where ph.Subacc_ID = 2371 /*-RENBR*/
                and ph.OldDate = @date
                and ph.Account_ID not in (3177, 2279, 3178, 3179, 2180)
          group by ph.Subacc_ID
                 , ph.Asset_ID
          having sum(ph.volfree) <> 0) asd
   inner join QORT_DB_PROD..assets a with(nolock, index=I_Assets_ID) on asd.Asset_id = a.id
                                                     and a.AssetClass_Const not in(1, 2)
  group by a.ShortName
         , a.ISIN
         , a.Marking)
 
 
 /*select * from [dbo].[QORT_1C_Sec_ActualPosition](20190906) --T-1, except weekends*/
