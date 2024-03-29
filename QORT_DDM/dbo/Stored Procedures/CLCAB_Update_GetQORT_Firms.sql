CREATE procedure [dbo].[CLCAB_Update_GetQORT_Firms]
as
    begin
        drop table if exists #GetQORT_Firms
        select [QORT.ID] = f.id
             , [Party.LegalName] = f.Name
             , [Party.EngLegalName] = f.EngName
             , [Party.ShortName] = f.FirmShortName
             , [Party.DVCode] = f.BOCode
             , [Party.Type] = iif(f.IsFirm = 'y', 'Company', 'Individual')
             , [Party.Profile] = iif(f.FT_Flags&1 = 1, 'Client', 'Other') /*- (создать функцию, которая вернет через запятую список)*/
             , [Party.Phones] = f.Phones
             , [KYC.OverallStatus] = isnull(ac.[Description(eng.)], 'UNKNOWN')
             , [QORT.DOCSTAT] = f.DOCSTAT_Const /* ЗАМЕНИТЬ на isnull(dc.[Description(eng.)], 'UNKNOWN')*/
             , [QORT.Gender] = cast(choose(f.GNDR_Const + 1, null, 'M', 'F') as varchar(1))
             , [QORT.Enabled] = f.Enabled
             , AuditDateTime = getdate()
             , AuditHash = binary_checksum(f.id, f.Name, f.EngName, f.FirmShortName, f.BOCode, f.IsFirm, f.FT_Flags, f.Phones, f.STAT_Const, f.DOCSTAT_Const, f.GNDR_Const, f.Enabled)
        into #GetQORT_Firms
          from QORT_DB_PROD.dbo.Firms f with(nolock)
          left join QORT_DB_PROD.dbo.ACSTAT_Const ac with(nolock) on ac.[Value] = f.STAT_Const /* <----- ТАБЛИЦУ ОБНОВИТЬ*/
         /*    left join QORT_DB_PROD.dbo.DOCSTAT_Const dc with(nolock) on dc.[Value] = f.DOCSTAT_Const /* <----- ТАБЛИЦУ ДОБАВИТЬ */*/
         where f.Enabled = 0
               and f.FT_Flags&1 = 1
        /*- (ID нету в архиве)*/
        insert into QORT_DDM.dbo.GetQORT_Firms
        select *,null
          from #GetQORT_Firms gqf
         where not exists( select 1
                             from QORT_DDM.dbo.GetQORT_Firms gqf2
                            where gqf.[QORT.ID] = gqf2.[QORT.ID] )
        /*- (ID есть в архиве, но другой ХЭШ)*/
        update gqf
           set gqf.[Party.LegalName] = gqf2.[Party.LegalName]
             , gqf.[Party.EngLegalName] = gqf2.[Party.EngLegalName]
             , gqf.[Party.ShortName] = gqf2.[Party.ShortName]
             , gqf.[Party.DVCode] = gqf2.[Party.DVCode]
             , gqf.[Party.Type] = gqf2.[Party.Type]
             , gqf.[Party.Profile] = gqf2.[Party.Profile]
             , gqf.[Party.Phones] = gqf2.[Party.Phones]
             , gqf.[KYC.OverallStatus] = gqf2.[KYC.OverallStatus]
             , gqf.[QORT.DOCSTAT] = gqf2.[QORT.DOCSTAT]
             , gqf.[QORT.Gender] = gqf2.[QORT.Gender]
             , gqf.[QORT.Enabled] = gqf2.[QORT.Enabled]
             , gqf.AuditHash = gqf2.AuditHash
             , gqf.AuditDateTime = gqf2.AuditDateTime
          from QORT_DDM.dbo.GetQORT_Firms gqf
          inner join #GetQORT_Firms gqf2 on gqf.[QORT.ID] = gqf2.[QORT.ID]
                                            and gqf.AuditHash != gqf2.AuditHash
    end
