CREATE   procedure [dbo].[QORT_GetOperationsForLoro] @RDate      date null
                                                      , @Subac_List varchar(max) null
as
    begin
        declare @Delimiter  char(1)     = ','
              , @pos        smallint
              , @b          smallint
              , @tmpLoro    varchar(32)
              , @ReportDate int
        select @ReportDate = format(isnull(@Rdate, getdate()), 'yyyyMMdd')
             , @Subac_List = concat(isnull(@Subac_List, 'RBC049,RBF049,RBD049,RB0049,RB0050,RBC050,RBD050,RB0003,RBD003,RBF051,RBD051,RB0051,RBC051,RBF090,RBD090,RB0090,RBC090,RBC091,RBD091,RB0091'),@Delimiter)
        drop table if exists #tmp_Loro
        create table #tmp_Loro
        ( Loro      varchar(32)
          primary key
        , Subacc_ID float )
        while charindex(',', @Subac_List) > 0
            begin
                select @pos = charindex(@Delimiter, @Subac_List)
                select @tmpLoro = ltrim(rtrim(substring(@Subac_List, 1, @pos - 1)))
                if nullif(@tmpLoro,'') is not null
                   and not exists( select 1
                                     from #tmp_Loro tl
                                    where tl.Loro = @tmpLoro )
                    insert into #tmp_Loro( Loro )
                values( @tmpLoro )
                select @Subac_List = substring(@Subac_List, @pos + 1, len(@Subac_List) - @pos)
                     , @tmpLoro = null
            end
        update #tmp_Loro
           set #tmp_Loro.Subacc_ID = s.ID
          from QORT_DB_PROD..Subaccs s with(nolock)
         where s.SubAccCode = #tmp_Loro.Loro collate Cyrillic_General_CI_AS
        drop table if exists #tmpOperations
        create table #tmpOperations
        ( RowID          int identity(1, 1) primary key
        , TableName      varchar(32)
        , ID             float
        , TradeDate      int
        , TradeTime      int
        , SubAcc_Code    varchar(32)
        , Section        varchar(64)
        , BuySell        varchar(6)
        , AssetShortName varchar(32)
        , Qty            float
        , Currency       varchar(6)
        , Volume         float )
        /* step 1 - select Positions changes */
        insert into #tmpOperations
        select TableName = 'Trades'
             , ID = t.id
             , TradeDate = t.TradeDate
             , TradeTime = t.TradeTime
             , Subacc_Code = tl.Loro
             , Section = tsec.Name
             , BueSell = choose(t.BuySell, 'Buy', 'Sell')
             , AssetShortName = a.ShortName
             , Qty = choose(t.BuySell, 1, -1) * t.Qty
             , Currency = cur.ShortName
             , Volume = choose(t.BuySell, -1, 1) * t.Volume1Nom
          from #tmp_Loro tl with(nolock)
          left join QORT_DB_PROD..Trades t with(nolock) on tl.Subacc_ID = t.SubAcc_ID
                                                           and t.TradeDate = @ReportDate
                                                           and t.IsRepo2 = 'n'
														   and t.NullStatus = 'n'
														   and t.Enabled=0
          left join QORT_DB_PROD..TSSections tsec with(nolock) on tsec.id = t.TSSection_ID
          left join QORT_DB_PROD..Securities s with(nolock) on s.id = t.Security_ID
          left join QORT_DB_PROD..Assets a with(nolock) on a.id = s.Asset_ID
          left join QORT_DB_PROD..Assets cur with(nolock) on cur.id = t.CurrPayAsset_ID
        insert into #tmpOperations
        select TableName = 'CorrectPositions'
             , ID = cp.id
             , TradeDate = cp.RegistrationDate
             , TradeTime = cp.[Time]
             , Subacc_Code = tl.Loro
             , Section = cc.Description
             , BuySell = ''
             , AssetShortName = a.ShortName
             , Qty = iif(cp.Asset_ID = iif(cp.CurrencyAsset_ID = -1, 71273, cp.CurrencyAsset_ID), null, cp.Size)
             , Currency = cur.ShortName
             , Volume = cp.Size
          from #tmp_Loro tl with(nolock)
          left join QORT_DB_PROD..CorrectPositions cp with(nolock) on cp.Subacc_ID = tl.Subacc_ID
                                                                      and cp.RegistrationDate = @ReportDate
																	  and cp.IsCanceled='n'
																	  and cp.Enabled=0
          left join QORT_DB_PROD..CT_Const cc with(nolock) on cc.[Value] = cp.CT_Const
          left join QORT_DB_PROD..Assets a with(nolock) on a.id = iif(cp.Asset_ID = iif(cp.CurrencyAsset_ID = -1, 71273, cp.CurrencyAsset_ID), null, cp.Asset_ID)
          left join QORT_DB_PROD..Assets cur with(nolock) on cur.id = iif(cp.CurrencyAsset_ID = -1, 71273, cp.CurrencyAsset_ID)
        select *
          from #tmpOperations
		  where #tmpOperations.ID is not null
    end
