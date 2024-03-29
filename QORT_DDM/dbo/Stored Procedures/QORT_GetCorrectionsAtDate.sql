CREATE     procedure [dbo].[QORT_GetCorrectionsAtDate]
( @Date       date
, @IsCanceled bit )
 
as
    begin
        declare @OperDate int = format(@Date, 'yyyyMMdd')
        select cp.SystemID
             , cp.BackID
             , RegDate = stuff(stuff(nullif(cp.RegistrationDate, 0), 7, 0, '-'), 5, 0, '-')
             , [Date] = stuff(stuff(nullif(cp.[Date], 0), 7, 0, '-'), 5, 0, '-')
             , [Time] = stuff(stuff(stuff(right(concat('0000000000', nullif(cp.[Time], 0)), 9), 7, 0, '.'), 5, 0, ':'), 3, 0, ':')
             , Loro = isnull(( select top 1 cla.LoroAccount
                                 from QORT_DDM..ClientLoroAccount cla with(nolock)
                                where cla.SubAccount = cp.Subacc_Code collate Cyrillic_General_CI_AS ), cp.Subacc_Code)
             , Nostro = cp.Account_ExportCode
             , Loro2 = isnull(( select top 1 cla.LoroAccount
                                  from QORT_DDM..ClientLoroAccount cla with(nolock)
                                 where cla.SubAccount = cp.GetSubaccCode collate Cyrillic_General_CI_AS ), cp.GetSubaccCode)
             , Nostro2 = cp.GetAccountCode
             , CT_Const = cc.Description
             , Curr = cp.Asset_ShortName
             , cp.Size
             , cp.IsCanceled
             , cp.SubaccOwnerFirm_BOCode
             , cp.GetSubaccOwnerFirm_BOCode
             , cp.IsInternal
             , ModifiedDate = stuff(stuff(cp.ModifiedDate, 7, 0, '-'), 5, 0, '-')
             , ModifiedTime = stuff(stuff(stuff(right(concat('0000000000', cp.ModifiedTime), 9), 7, 0, '.'), 5, 0, ':'), 3, 0, ':')
             , ImportInsertDate = stuff(stuff(cp.ImportInsertDate, 7, 0, '-'), 5, 0, '-')
             , ImportInsertTime = stuff(stuff(stuff(right(concat('0000000000', cp.ImportInsertTime), 9), 7, 0, '.'), 5, 0, ':'), 3, 0, ':')
             , ExtComment = cp.Comment
             , BaseAsset = a0.ViewName
             , BaseAssetGRDB = isnull(cast(gm.GrdbId as varchar), a0.Marking)
             , cp.R2
             , cp.InfoSource
             , cp.PrevMargin
             , cp.Margin
          from QORT_TDB_PROD..ExportCorrectPositions cp with(nolock)
          inner join QORT_DB_PROD..CT_Const cc with(nolock) on cc.[Value] = cp.CT_Const
          inner join QORT_DB_PROD..Assets a with(nolock) on a.ShortName = cp.Asset_ShortName
          left join QORT_DB_PROD..Assets a0 with(nolock) on a0.ShortName = cp.SideAsset_ShortName
          left join GRDBServices.Publication.GrdbMap gm with(nolock) on gm.QortId = a0.id
         where 1 = 1
               and cp.CT_Const in ( 51, 52 ) /* Variation margin */          
               and @OperDate in ( cp.date, cp.RegistrationDate )
        and cp.IsCanceled = iif(@IsCanceled = 'true', 'y', 'n')
    end
