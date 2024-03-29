CREATE procedure [dbo].[TMP_export_MISQL] @DateFrom date
                                   , @DateTo   date
as
    begin
        set nocount on
        declare @NN        bigint
              , @tradeDate int
              , @TimeStamp varchar(1024)
        drop table if exists TMP_export_trades
        drop table if exists TMP_export_settlements
        drop table if exists TMP_export_Corrections
        create table TMP_export_trades
        ( RowID             bigint identity(1, 1) primary key
        , ID                bigint
        , RepoTrade_ID      bigint
        , Repo              varchar(16)
        , TradeNum          bigint
        , OrderNum          bigint
        , TradeDate         int
        , PutPlannedDate    int
        , PutDate           int
        , PayPlannedDate    int
        , PayDate           int
        , SubAccCode        varchar(24)
        , BuySell           smallint
        , GRDB              varchar(24)
        , DVCode            varchar(12)
        , Security_Code     varchar(64)
        , ISIN              varchar(32)
        , Qty               float
        , Price             float
        , Volume1           float
        , Volume1Nom        float
        , Accruedint        float
        , RepoRate          float
        , CurrPrice         varchar(32)
        , CurrPay           varchar(32)
        , QFlags            varchar(16)
        , TSSection_Name    varchar(255)
        , OwnerFirm_Name    varchar(255)
        , OwnerFirm_BOCode  varchar(128)
        , ClearingComission float
        , CpFirm_ShortName  varchar(255)
        , CpFirm_BOCode     varchar(128)
        , BONum             varchar(64) )
		WITH ( DATA_COMPRESSION = PAGE)
        create table TMP_export_settlements
        ( RowID                   bigint identity(1, 1) primary key
        , ID                      bigint
        , Trade_SID               bigint
        , QtyBefore               float
        , QtyAfter                float
        , SubAcc_Code             varchar(32)
        , PhaseAccount_ExportCode varchar(64)
        , InfoSource              varchar(32)
        , TransferType            varchar(32)
        , SettlCur                varchar(32)
        , PhaseDate               int
        , PC_Const                varchar(128)
        , IsCanceled              bit )
		WITH ( DATA_COMPRESSION = PAGE)
        create table TMP_export_Corrections
        ( RowID                     bigint identity(1, 1) primary key
        , id                        float
        , BackID                    varchar(64)
        , RegDate                   int
        , Date                      int
        , Time                      int
        , Loro                      varchar(50)
        , Nostro                    varchar(32)
        , Loro2                     varchar(50)
        , Nostro2                   varchar(32)
        , CT_Const                  nvarchar(512)
        , Curr                      varchar(48)
        , Size                      float
        , IsCanceled                char(1)
        , SubaccOwnerFirm_BOCode    varchar(32)
        , GetSubaccOwnerFirm_BOCode varchar(32)
        , IsInternal                char(1)
        , ModifiedDate              int
        , ModifiedTime              int
        , ImportInsertDate          int
        , ImportInsertTime          int
        , ExtComment                varchar(256)
        , BaseAsset                 varchar(128)
        , BaseAssetGRDB             varchar(128)
        , R2                        float
        , InfoSource                varchar(64)
        , PrevMargin                float
        , Margin                    float )
		WITH ( DATA_COMPRESSION = PAGE)
        while @DateFrom <= @DateTo
            begin
                select @tradeDate = format(@DateFrom, 'yyyyMMdd')
                set @TimeStamp = concat(@tradeDate, ' ', format(getdate(), 'HH:mm:ss.ffff'), ' -- START')
                raiserror(N'%s', 10, 1, @TimeStamp) with nowait
                drop table if exists #tmp_trades
                create table #tmp_trades
                ( ID           bigint
                , RepoTrade_ID bigint null
                , Security_ID  bigint
                , SubAcc_ID    bigint )
                insert into #tmp_trades
                select t.id
                     , RepoTrade_ID = nullif(t.RepoTrade_ID, -1)
                     , t.Security_ID
                     , t.SubAcc_ID
                  from QORT_DB_PROD.dbo.Trades t with(nolock)
                 where 1 = 1
                       and @tradeDate in ( t.TradeDate, t.PutPlannedDate, t.PayPlannedDate, t.PutDate, t.PayDate )
                and t.Enabled = 0
                and isnull(t.NullStatus, 'n') = 'n'
                and not exists( select 1
                                  from #tmp_trades tt
                                 where tt.id = t.id )
                set @TimeStamp = concat(@tradeDate, ' ', format(getdate(), 'HH:mm:ss.ffff'), ' -- Trades extracted')
                raiserror(N'%s', 10, 1, @TimeStamp) with nowait
                insert into TMP_export_trades
                select ID = t.SystemID
                     , RepoTrade_ID = t.RepoTrade_SystemID
                     , Repo = case when t.RepoTrade_SystemID > 0
                                   then iif(t.isrepo2 = 'n', '1 часть', '2 часть')
                                   else ''
                              end
                     , t.TradeNum
                     , t.OrderNum
                     , t.TradeDate
                     , t.PutPlannedDate
                     , t.PutDate
                     , t.PayPlannedDate
                     , t.PayDate
                     , SubAccCode = isnull(( select top 1 cla.LoroAccount
                                               from QORT_DDM..ClientLoroAccount cla with(nolock)
                                              where cla.SubAccount = sub.SubAccCode collate Cyrillic_General_CI_AS ), sub.SubAccCode)
                     , t.BuySell
                     , GRDB = iif(isnumeric(a.Marking) = 0, 0, a.Marking)
                     , DVCode = t.AssetShortName
                     , t.Security_Code
                     , a.ISIN
                     , t.Qty
                     , t.Price
                     , t.Volume1
                     , Volume1Nom = isnull(nullif(t.Volume1Nom, 0), round(Volume1 / isnull(nullif(CrossRate, 0), 1), 2))
                     , t.Accruedint
                     , t.RepoRate
                     , CurrPrice = t.CurrPriceAsset_ShortName
                     , CurrPay = t.CurrPayAsset_ShortName
                     , QFlags = case when QFlags&131072 = 131072
                                     then 'поручения' when t.SubAcc_Code <> 'RENBR'
                                     then 'комиссии'
                                     else 'собственная'
                                end
                     , t.TSSection_Name
                     , OwnerFirm_Name = ow.Name
                     , OwnerFirm_BOCode = ow.BOCode
                     , t.ClearingComission
                     , t.CpFirm_ShortName
                     , t.CpFirm_BOCode
                     , t.BONum
                  from #tmp_trades tt
                  inner join QORT_TDB_PROD.dbo.Trades t with(nolock) on t.SystemID in(tt.id, tt.RepoTrade_ID)
                  inner join QORT_DB_PROD.dbo.Securities s with(nolock) on s.id = tt.Security_ID
                  inner join QORT_DB_PROD.dbo.Assets a with(nolock) on a.id = s.Asset_ID
                  inner join QORT_DB_PROD.dbo.Subaccs sub with(nolock) on sub.id = tt.SubAcc_ID
                  inner join QORT_DB_PROD.dbo.Firms ow with(nolock) on ow.id = sub.OwnerFirm_ID
                 where 1 = 1
                       and not exists( select 1
                                         from dbo.TMP_export_trades tet
                                        where tet.ID in ( tt.id, tt.RepoTrade_ID ) )
                set @TimeStamp = concat(@tradeDate, ' ', format(getdate(), 'HH:mm:ss.ffff'), ' --  Exported Trades')
                raiserror(N'%s', 10, 1, @TimeStamp) with nowait
                insert into TMP_export_settlements
                select ID = p.id
                     , p.Trade_ID
                     , p.QtyBefore
                     , p.QtyAfter
                     , SubAccCode = isnull(( select top 1 cla.LoroAccount
                                               from QORT_DDM..ClientLoroAccount cla with(nolock)
                                              where cla.SubAccount = s.SubAccCode collate Cyrillic_General_CI_AS ), s.SubAccCode)
                     , acc.ExportCode
                     , p.InfoSource
                     , TransferType = isnull(nullif(p.Comment, ''), 'PRINCIPAL')
                     , SettlCur = isnull(nullif(cur.ShortName, ''), a.ShortName)
                     , PhaseDate = p.PhaseDate
                     , PC_Const = pc.Description
                     , IsCanceled = iif(isnull(p.IsCanceled, 'n') = 'n', 0, 1)
                  from QORT_DB_PROD.dbo.Phases p with(nolock)
                  inner join QORT_DB_PROD..Subaccs s with(nolock) on p.SubAcc_ID = s.id
                  inner join QORT_DB_PROD..Assets a with(nolock) on p.PhaseAsset_ID = a.id
                                                                    and a.AssetType_Const = 3 /*Денежные активы*/
                  left join QORT_DB_PROD..Assets cur with(nolock) on p.CurrencyAsset_ID = cur.id
                  inner join QORT_DB_PROD..Accounts acc with(nolock) on p.PhaseAccount_ID = acc.id
                  inner join QORT_DB_PROD..PC_Const pc with(nolock) on pc.[Value] = p.PC_Const
                 where 1 = 1
                       and p.PhaseDate = @tradeDate
                       and nullif(p.QtyBefore, 0) is not null
                       and not exists( select 1
                                         from dbo.TMP_export_settlements tes
                                        where tes.ID = p.ID )
                set @TimeStamp = concat(@tradeDate, ' ', format(getdate(), 'HH:mm:ss.ffff'), ' --  Exported settlements')
                raiserror(N'%s', 10, 1, @TimeStamp) with nowait
                insert into TMP_export_Corrections
                select cp.SystemID
                     , cp.BackID
                     , RegDate = cp.RegistrationDate
                     , cp.[Date]
                     , cp.[Time]
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
                     , cp.ModifiedDate
                     , cp.ModifiedTime
                     , cp.ImportInsertDate
                     , cp.ImportInsertTime
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
                       and @tradeDate in ( cp.date, cp.RegistrationDate )
                and not exists( select 1
                                  from dbo.TMP_export_Corrections tec
                                 where tec.ID = cp.SystemID )
                set @TimeStamp = concat(@tradeDate, ' ', format(getdate(), 'HH:mm:ss.ffff'), ' --  Exported Corrections')
                raiserror(N'%s', 10, 1, @TimeStamp) with nowait
                select @DateFrom = dateadd(dd, 1, @DateFrom)
            end
    end;
