CREATE procedure dbo.QORT_GetHistOperationsForLoro @RDate      date null
                                                , @Subac_List varchar(max) null
as
    begin
        declare @ReportDate int
        select @ReportDate = format(isnull(@Rdate, getdate()), 'yyyyMMdd')
        drop table if exists #tmpOperations
        create table #tmpOperations
        ( RowID          int identity(1, 1) primary key
        , TableName      varchar(32)
        , ID             float
        , TradeDate      varchar(10)
        , SettleDate     varchar(10)
        , Modified_Time  varchar(16)
        , SubAcc_Code    varchar(32)
        , Nostro_Code    varchar(48)
        , Section        varchar(64)
        , AssetShortName varchar(32)
        , Qty            float
        , Currency       varchar(6)
        , Volume         float
        , IsCanceled     varchar(1)
        , CP_Hash        int )
        /* step 1 - select Positions changes */
        insert into #tmpOperations
        select TableName = 'CorrectPositions'
             , ID = cp.id
             , TradeDate = convert(varchar(10), cast(str(cp.RegistrationDate) as date), 104)
             , SettleDate = convert(varchar(10), cast(str(nullif(cp.[Date], 0)) as date), 104)
             , modified_time = stuff(stuff(stuff(right(concat('0000000000', cp.modified_time), 9), 7, 0, '.'), 5, 0, ':'), 3, 0, ':')
             , Subacc_Code = tl.Loro
             , Nostro_Code = nostro.AccountCode
             , Section = cc.Description
             , AssetShortName = a.ShortName
             , Qty = iif(cp.Asset_ID = iif(cp.CurrencyAsset_ID = -1, 71273, cp.CurrencyAsset_ID), null, cp.Size)
             , Currency = cur.ShortName
             , Volume = iif(cp.Asset_ID = iif(cp.CurrencyAsset_ID = -1, 71273, cp.CurrencyAsset_ID), cp.Size, null)
             , IsCanceled = isnull(cp.IsCanceled, 'n')
             , CP_Hash = null
          from QORT_DDM.dbo.QORT_GetLoroList( @Subac_List ) tl
          left join QORT_DB_PROD..CorrectPositions cp with(nolock) on cp.Subacc_ID = tl.Subacc_ID
                                                                      and @ReportDate = cp.modified_date
                                                                      and @ReportDate not in(cp.RegistrationDate, cp.[Date])
          /*  and @ReportDate > cp.created_date*/
          left join QORT_DB_PROD..Accounts nostro with(nolock) on nostro.id = cp.Account_ID
          left join QORT_DB_PROD..CT_Const cc with(nolock) on cc.[Value] = cp.CT_Const
          left join QORT_DB_PROD..Assets a with(nolock) on a.id = iif(cp.Asset_ID = iif(cp.CurrencyAsset_ID = -1, 71273, cp.CurrencyAsset_ID), null, cp.Asset_ID)
          left join QORT_DB_PROD..Assets cur with(nolock) on cur.id = iif(cp.CurrencyAsset_ID = -1, 71273, cp.CurrencyAsset_ID)
        update t_cp
           set t_cp.CP_Hash = binary_checksum(t_cp.TableName, t_cp.TradeDate, t_cp.SettleDate, t_cp.SubAcc_Code, t_cp.Nostro_Code, t_cp.Section, t_cp.AssetShortName, t_cp.Qty, t_cp.Currency, t_cp.Volume)
          from #tmpOperations t_cp
        select *
          from #tmpOperations
         where #tmpOperations.ID is not null
    end
