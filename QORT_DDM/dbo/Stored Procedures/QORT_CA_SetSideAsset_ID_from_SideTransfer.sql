create   procedure QORT_CA_SetSideAsset_ID_from_SideTransfer
as
    begin
        drop table if exists #tmp_CT_SEC_CHANGE
        select cp.id
             , cp.Asset_ID
             , cp.Size
             , cp.SideAsset_ID
             , cp.SideAssetSize
             , Subacc_ID = s.SubAccCode
             , TradeID = left(cp.Comment, 9)
             , TransferID = left(cp.BackID, 9)
             , cp.Comment
             , cp.BackID
             , cp.RegistrationDate
             , cp.[Date]
        into #tmp_CT_SEC_CHANGE
          from QORT_DB_PROD..CorrectPositions cp with (nolock, index = I_CorrectPositions_RegistrationDate)
          inner join QORT_DB_PROD..Subaccs s with(nolock) on s.id = cp.Subacc_ID
         where cp.CT_Const = 25
               and cp.RegistrationDate > 20190000
               and cp.IsCanceled = 'n'
               and cp.SideAsset_ID < 0
        update tcsc
           set tcsc.SideAsset_ID = t0.Asset_ID
          from #tmp_CT_SEC_CHANGE tcsc
          inner join #tmp_CT_SEC_CHANGE t0 on t0.TradeID = tcsc.TradeID
                                              and t0.Subacc_ID = tcsc.Subacc_ID
                                              and t0.SideAssetSize = tcsc.SideAssetSize
                                              and t0.TransferID != tcsc.TransferID
         where tcsc.SideAsset_ID < 0
        update tcsc
           set tcsc.SideAsset_ID = t0.Asset_ID
          from #tmp_CT_SEC_CHANGE tcsc
          inner join #tmp_CT_SEC_CHANGE t0 on t0.Subacc_ID = tcsc.Subacc_ID
                                              and t0.SideAssetSize = tcsc.SideAssetSize
                                              and t0.TransferID != tcsc.TransferID
                                              and t0.SideAsset_ID < 0
         where tcsc.SideAsset_ID < 0
               and 1 = ( select count(1)
                           from #tmp_CT_SEC_CHANGE t1
                          where t1.Subacc_ID = tcsc.Subacc_ID
                                and t1.SideAssetSize = tcsc.SideAssetSize
                                and t1.TransferID != tcsc.TransferID
                                and t1.SideAsset_ID < 0 )
        update cp
           set cp.SideAsset_ID = t0.SideAsset_ID
             , cp.modified_date = format(dateadd(day, 1, getdate()), 'yyyyMMdd')
          from QORT_DB_PROD..CorrectPositions cp
          inner join #tmp_CT_SEC_CHANGE t0 on t0.id = cp.id
        select tcsc.TradeID
             , tcsc.TransferID
             , SideAsset = tcsc.SideAsset_ID
             , tcsc.Comment
             , QORT_ID = tcsc.id
          from #tmp_CT_SEC_CHANGE tcsc
         where tcsc.SideAsset_ID < 0
        order by tcsc.TradeID
               , tcsc.TransferID
    end
