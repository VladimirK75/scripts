CREATE procedure [dbo].[CLCAB_Update_GetQORT_Subaccs]
as
    begin
        drop table if exists #GetQORT_Subaccs
        select [QORT.ID] = s.id
             , [Party.DVCode] = isnull(own.BOCode, 'UNKNOWN')
             , [Account.RCShortID] = s.SubAccCode
             , [Account.RCLongID] = s.SubaccName
             , [Account.Status] = isnull(ac.[Description(eng.)], 'UNKNOWN')
             , [Account.Type] = choose(s.ACTYPE_Const + 1, 'None', 'Own', 'Custodian', 'UNKNOWN')
             , [Account.OpeningDate] = stuff(stuff(coalesce(nullif(ca.DateSign, 0), s.created_date), 7, 0, '-'), 5, 0, '-')
             , [Account.ClosingDate] = stuff(stuff(nullif(ca.DateEnd, 0), 7, 0, '-'), 5, 0, '-')
             , [Account.HFTTrading] = iif(( select count(1)
                                              from QORT_DDM.dbo.GetSecurityLoro( '%', 'HFT_Trading' )
                                             where SubAccCode = s.SubAccCode collate Cyrillic_General_CI_AS ) > 0, 1, 0)
             , [QORT.Enabled] = s.Enabled
             , AuditDateTime = getdate()
             , AuditHash = cast(0 as int)
        into #GetQORT_Subaccs
          from QORT_DB_PROD.dbo.Subaccs s with(nolock)
          left join QORT_DB_PROD.dbo.ACSTAT_Const ac with(nolock) on ac.[Value] = s.ACSTAT_Const /* <----- ТАБЛИЦУ ОБНОВИТЬ*/
          left join QORT_DB_PROD.dbo.Firms own with(nolock) on own.id = s.OwnerFirm_ID
          left join QORT_DB_PROD.dbo.ClientAgrees ca with(nolock) on ca.SubAcc_ID = s.id
                                                                     and ca.Enabled = 0
                                                                     and exists( select 1
                                                                                   from QORT_DB_PROD.dbo.ClientAgreeTypes cat with(nolock)
                                                                                  where ca.ClientAgreeType_ID = cat.id
                                                                                        and cat.IsAgree = 'y'
                                                                                        and cat.ShortName in ( 'DBFR', 'DBFRD', 'DBJR' ) )
               and not exists( select 1
                                 from QORT_DB_PROD.dbo.ClientAgrees ca2 with(nolock)
                                where ca2.SubAcc_ID = s.id
                                      and ca2.Enabled = 0
                                      and ca2.id > ca.id
                                      and exists( select 1
                                                    from QORT_DB_PROD.dbo.ClientAgreeTypes cat2 with(nolock)
                                                   where ca2.ClientAgreeType_ID = cat2.id
                                                         and cat2.IsAgree = 'y'
                                                         and cat2.ShortName in ( 'DBFR', 'DBFRD', 'DBJR' ) ) )
         where 1 = 1
               and s.Enabled = 0
               and s.IsAnalytic = 'n'
        update tsa
           set tsa.AuditHash = binary_checksum([QORT.ID], [Party.DVCode], [Account.RCShortID], [Account.RCLongID], [Account.Status], [Account.Type], [Account.OpeningDate], [Account.ClosingDate], [Account.HFTTrading], [QORT.Enabled])
          from #GetQORT_Subaccs tsa
        /*- (ID нету в архиве)*/
        insert into QORT_DDM.dbo.GetQORT_Subaccs
        select *
             , null
          from #GetQORT_Subaccs tsa
         where not exists( select 1
                             from QORT_DDM.dbo.GetQORT_Subaccs gqs
                            where gqs.[QORT.ID] = tsa.[QORT.ID] )
        /*- (ID есть в архиве, но другой ХЭШ)*/
        update gqs
           set gqs.[Party.DVCode] = tsa.[Party.DVCode]
             , gqs.[Account.RCShortID] = tsa.[Account.RCShortID]
             , gqs.[Account.RCLongID] = tsa.[Account.RCLongID]
             , gqs.[Account.Status] = tsa.[Account.Status]
             , gqs.[Account.Type] = tsa.[Account.Type]
             , gqs.[Account.OpeningDate] = tsa.[Account.OpeningDate]
             , gqs.[Account.ClosingDate] = tsa.[Account.ClosingDate]
             , gqs.[Account.HFTTrading] = tsa.[Account.HFTTrading]
             , gqs.[QORT.Enabled] = tsa.[QORT.Enabled]
             , gqs.AuditDateTime = tsa.AuditDateTime
             , gqs.AuditHash = tsa.AuditHash
          from QORT_DDM.dbo.GetQORT_Subaccs gqs
          inner join #GetQORT_Subaccs tsa on tsa.[QORT.ID] = gqs.[QORT.ID]
                                             and tsa.AuditHash != gqs.AuditHash
    end
