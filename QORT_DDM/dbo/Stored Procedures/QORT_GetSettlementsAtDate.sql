CREATE     procedure [dbo].[QORT_GetSettlementsAtDate]
( @Date       date
, @IsCanceled bit )
as
    begin
        declare @OperDate int = format(@Date, 'yyyyMMdd')
        select ID = p.id
             , Trade_SID = p.Trade_ID
             , p.QtyBefore
             , p.QtyAfter
             , SubAccCode = isnull(( select top 1 cla.LoroAccount
                                       from QORT_DDM.dbo.ClientLoroAccount cla with(nolock)
                                      where cla.SubAccount = s.SubAccCode collate Cyrillic_General_CI_AS ), s.SubAccCode)
             , acc.ExportCode
             , p.InfoSource
             , TransferType = isnull(nullif(p.Comment, ''), 'PRINCIPAL')
             , SettlCur = isnull(nullif(cur.ShortName, ''), a.ShortName)
             , PhaseDate = stuff(stuff(nullif(p.PhaseDate, 0), 7, 0, '-'), 5, 0, '-')
             , PC_Const = pc.Description
             , IsCanceled = iif(isnull(p.IsCanceled, 'n') = 'n', 0, 1)
          from QORT_DB_PROD.dbo.Phases p with(nolock)
          inner join QORT_DB_PROD.dbo.Assets a with(nolock) on p.PhaseAsset_ID = a.id
                                                               and a.AssetType_Const = 3 /*Денежные активы*/
          left join QORT_DB_PROD.dbo.Subaccs s with(nolock) on p.SubAcc_ID = s.id
          left join QORT_DB_PROD.dbo.Assets cur with(nolock) on p.CurrencyAsset_ID = cur.id
          left join QORT_DB_PROD.dbo.Accounts acc with(nolock) on p.PhaseAccount_ID = acc.id
          left join QORT_DB_PROD.dbo.PC_Const pc with(nolock) on pc.[Value] = p.PC_Const
         where 1 = 1
               and p.PhaseDate = @OperDate
               and p.IsCanceled = iif(@IsCanceled = 'true', 'y', 'n')
               and nullif(p.QtyBefore, 0) is not null
    end
