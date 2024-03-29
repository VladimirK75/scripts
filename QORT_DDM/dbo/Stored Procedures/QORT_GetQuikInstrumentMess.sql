CREATE procedure [dbo].[QORT_GetQuikInstrumentMess]( @Style smallint )
as
    begin
        declare @Class2Exchange table
        ( ClassCode varchar(20)
        , Exchange  varchar(20)
        , Type      varchar(1) )
        insert into @Class2Exchange
        exec quik_73.qexport.dbo.Class2Exchange
        declare @QUIK_Security table
        ( QUIK_ISIN      varchar(16)
        , QUIK_SecCode   varchar(48)
        , QUIK_ShortName varchar(128) )
        insert into @QUIK_Security
		exec QUIK_73.Qexport.dbo.getSecuritiesforQORT
        --select distinct 
        --       QUIK_ISIN = p1.ISINCODE
        --     , QUIK_SecCode = p1.SecCode
        --     , QUIK_ShortName = p1.SecShortName
        --  from quik_73.qexport.dbo.Params p1 with(nolock)
        --  join @Class2Exchange Exch1 on p1.ClassCode = Exch1.ClassCode
        -- where Exch1.Exchange in ( 'MOEX Fond', 'MOEX Fond REPO L', 'OTC' ) 
        declare @QORT_Security table
        ( QORT_SecCode   varchar(48)
        , QORT_ISIN      varchar(16)
        , QORT_ShortName varchar(128)
        , GRDB_ID        varchar(32)
        , QORT_ID        float );
        with tmp_position
             as (select QORT_ISIN = max(a.isin)
                      , QORT_ShortName = max(a.ViewName)
                      , GRDB_ID = max(a.Marking)
                      , QORT_ID = a.id
                      , acc.TS_ID
                   from QORT_DB_PROD..Position p with(nolock)
                   inner join QORT_DB_PROD..Accounts acc with(nolock) on p.Account_ID = acc.id
                   inner join QORT_DB_PROD.dbo.Subaccs sub with(nolock) on p.Subacc_ID = sub.id
                                                                           and sub.SubaccCode like 'RB0%'
                                                                           and sub.ownerfirm_id <> 70736 /*-id=RESEC*/
                   inner join QORT_DB_PROD..Assets a with(nolock) on p.Asset_ID = a.id
                                                                     and a.AssetType_Const = 1
                  where 1 = 1
                        and cast(abs(p.VolFree) as money) + cast(abs(p.VolBlocked) as money) + cast(abs(p.VolForward) as money) + cast(abs(p.VolForwardOut) as money) != 0
                  group by a.id
                         , acc.TS_ID)
             insert into @QORT_Security
             select QORT_SecCode = ( select top 1 s.SecCode
                                       from QORT_DB_PROD..Securities s
                                       inner join QORT_DB_PROD..TSSections t with(nolock) on s.TSSection_ID = t.id
                                      where s.Asset_ID = tp.QORT_ID
                                            and s.Enabled = 0
                                     order by iif(t.TS_ID = 1, tp.TS_ID, t.TS_ID)
                                            , iif(s.IsPriority = 'y', 0, 1)
                                            , t.id
                                            , s.id desc )
                  , tp.QORT_ISIN
                  , tp.QORT_ShortName
                  , tp.GRDB_ID
                  , tp.QORT_ID
               from tmp_position tp
        if @Style in(0, 1)
            begin
                select *
                  from @QORT_Security qs
                  left join @QUIK_Security qs2 on qs.QORT_ISIN = qs2.QUIK_ISIN
                                                  and qs.QORT_SecCode = qs2.QUIK_SecCode
                 where 1 = 1
                       and 0 < iif( @Style = 0                              ,1,0)
                             + iif( @Style = 1 and qs2.QUIK_ISIN is     null,1,0)
                order by qs2.QUIK_SecCode
                       , qs.QORT_SecCode
        end
        if @Style = 2
            begin
                declare @AssetID table( QORT_ID float )
                insert into @AssetID
                select qs.QORT_ID
                  from @QORT_Security qs
                  left join @QUIK_Security qs2 on qs.QORT_ISIN = qs2.QUIK_ISIN
                                                  and qs.QORT_SecCode = qs2.QUIK_SecCode
                 where 1 = 1
                       and qs2.QUIK_ISIN is null
                select s.SubAccCode
                     , ISIN = a.ISIN
                     , GRDB_ID = iif(isnumeric(a.Marking) = 1, a.Marking, null)
                     , ShortName = iif(a.AssetType_Const = 1, a.ShortName, a.CBName)
                     , SecCode = ( select top 1 s.SecCode
                                     from QORT_DB_PROD..Securities s
                                     inner join QORT_DB_PROD..TSSections t with(nolock) on s.TSSection_ID = t.id
                                    where s.Asset_ID = a.id
                                          and s.Enabled = 0
                                   order by iif(t.TS_ID = 1, aa.TS_ID, t.TS_ID)
                                          , iif(s.IsPriority = 'y', 0, 1)
                                          , t.id
                                          , s.id desc )
                     , FaceCurrency = a2.CBName
                     , VolFree = p.VolFree
                     , VolBlocked = p.VolBlocked
                     , VolForwardIn = p.VolForward - p.VolForwardOut
                     , VolForwardOut = p.VolForwardOut
                     , Nostro = QORT_DDM.dbo.GetDDM_NostroMapping( aa.AccountCode, 'Единый пул', 0 ) collate Cyrillic_General_CS_AS
                  from QORT_DB_PROD.dbo.Position p with(nolock)
                  inner join @AssetID ai on ai.QORT_ID = p.Asset_ID
                  inner join QORT_DB_PROD.dbo.Subaccs s with(nolock) on p.Subacc_ID = s.id
                                                                        and s.SubaccCode like 'RB0%'
                                                                        and s.ownerfirm_id <> 70736 /*-id=RESEC*/
                  inner join QORT_DB_PROD.dbo.Firms f with(nolock) on s.ownerfirm_id = f.id
                  inner join QORT_DB_PROD.dbo.Assets a with(nolock) on p.Asset_ID = a.id
                                                                       and a.AssetType_Const = 1
                  left join QORT_DB_PROD..Assets a2 with(nolock) on a2.id = a.BaseCurrencyAsset_ID
                  inner join QORT_DB_PROD.dbo.Accounts aa with(nolock) on aa.id = p.account_id
                 where 1 = 1
                       and abs(p.VolFree) + abs(p.VolBlocked) + abs(p.VolForward) + abs(p.VolForwardOut) > 0
        end
    end
