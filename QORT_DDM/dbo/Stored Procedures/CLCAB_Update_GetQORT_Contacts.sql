create   procedure dbo.CLCAB_Update_GetQORT_Contacts
as
    begin
        drop table if exists #GetQORT_Contacts
        select [QORT.ID] = f.id
             , [QORT.Trustee.ID] = f.id
             , [Party.Type] = iif(f.IsFirm = 'y', 'Company', 'Individual')
             , [Trustee.RoleType] = 'Owner'
             , [Trustee.RoleStatus] = cast('Head (first person)' as varchar(128))
             , [Party.DVCode] = f.BOCode
             , [Trustee.DVCode] = f.BOCode
             , [Trustee.Name] = f.Name
             , [Trustee.GenName] = f.GenName
             , [Trustee.Phones] = f.Phones
             , [Trustee.Email] = f.Email
             , [Trustee.VerifiedEmail] = nullif(f.VerifiedEmail, '')
             , [Trustee.INN] = f.INN
             , [QORT.DOCSTAT] = f.DOCSTAT_Const
             , [QORT.Enabled] = f.Enabled
             , AuditDateTime = getdate()
             , AuditHash = binary_checksum(f.id, f.id, f.IsFirm, f.BOCode, f.BOCode, f.Name, f.GenName, f.Phones, f.Email, f.VerifiedEmail, f.INN, f.DOCSTAT_Const, f.Enabled)
        into #GetQORT_Contacts
          from QORT_DB_PROD..Firms f with(nolock)
         where IsFirm = 'n'
               and f.FT_Flags&1 = 1
               and Enabled = 0
        union
        select [QORT.ID] = f.id
             , [QORT.Trustee.ID] = f2.id
             , [Party.Type] = iif(f.IsFirm = 'y', 'Company', 'Individual')
             , [Trustee.RoleType] = cast(fct.[Description(eng.)] as varchar(128))
             , [Trustee.RoleStatus] = cast(ps.[Description(eng.)] as varchar(128))
             , [Party.DVCode] = f.BOCode
             , [Trustee.DVCode] = f2.BOCode
             , [Trustee.Name] = f2.Name
             , [Trustee.GenName] = f2.GenName
             , [Trustee.Phones] = f2.Phones
             , [Trustee.Email] = f2.Email
             , [Trustee.VerifiedEmail] = nullif(f2.VerifiedEmail, '')
             , [Trustee.INN] = f2.INN
             , [QORT.DOCSTAT] = f.DOCSTAT_Const
             , [QORT.Enabled] = f.Enabled
             , AuditDateTime = getdate()
             , AuditHash = binary_checksum(f.id, f2.id, f.IsFirm, f.BOCode, f2.BOCode, f2.Name, f2.GenName, f2.Phones, f2.Email, f2.VerifiedEmail, f2.INN, f.DOCSTAT_Const, f.Enabled)
          from QORT_DB_PROD..FirmContacts fc with(nolock)
          join QORT_DB_PROD..Firms f with(nolock) on f.id = fc.Firm_ID
          join QORT_DB_PROD..Firms f2 with(nolock) on f2.id = fc.Contact_ID
          join QORT_DB_PROD..PS_Const ps with(nolock) on ps.Value = FC.PositionStatus
          join QORT_DB_PROD..FCT_Const fct with(nolock) on fct.[Value] = FC.FCT_Const
         where f.Enabled = 0
               and f.FT_Flags&1 = 1
        /*- (ID нету в архиве)*/
        insert into QORT_DDM.dbo.GetQORT_Contacts
        ( [QORT.ID]
        , [QORT.Trustee.ID]
        , [Party.Type]
        , [Trustee.RoleType]
        , [Trustee.RoleStatus]
        , [Party.DVCode]
        , [Trustee.DVCode]
        , [Trustee.Name]
        , [Trustee.GenName]
        , [Trustee.Phones]
        , [Trustee.Email]
        , [Trustee.VerifiedEmail]
        , [Trustee.INN]
        , [QORT.DOCSTAT]
        , [QORT.Enabled]
        , AuditDateTime
        , AuditHash
        )
        select *
          from #GetQORT_Contacts gqf2
         where not exists( select 1
                             from QORT_DDM.dbo.GetQORT_Contacts gqf
                            where gqf.[QORT.ID] = gqf2.[QORT.ID]
                                  and gqf.[QORT.Trustee.ID] = gqf2.[QORT.Trustee.ID] )
        /*- (ID есть в архиве, но другой ХЭШ)*/
        update gqf
           set gqf.[Party.Type] = gqf2.[Party.Type]
             , gqf.[Trustee.RoleType] = gqf2.[Trustee.RoleType]
             , gqf.[Trustee.RoleStatus] = gqf2.[Trustee.RoleStatus]
             , gqf.[Party.DVCode] = gqf2.[Party.DVCode]
             , gqf.[Trustee.DVCode] = gqf2.[Trustee.DVCode]
             , gqf.[Trustee.Name] = gqf2.[Trustee.Name]
             , gqf.[Trustee.GenName] = gqf2.[Trustee.GenName]
             , gqf.[Trustee.Phones] = gqf2.[Trustee.Phones]
             , gqf.[Trustee.Email] = gqf2.[Trustee.Email]
             , gqf.[Trustee.VerifiedEmail] = gqf2.[Trustee.VerifiedEmail]
             , gqf.[Trustee.INN] = gqf2.[Trustee.INN]
             , gqf.[QORT.DOCSTAT] = gqf2.[QORT.DOCSTAT]
             , gqf.[QORT.Enabled] = gqf2.[QORT.Enabled]
             , gqf.AuditHash = gqf2.AuditHash
             , gqf.AuditDateTime = gqf2.AuditDateTime
          from QORT_DDM.dbo.GetQORT_Contacts gqf
          inner join #GetQORT_Contacts gqf2 on gqf.[QORT.ID] = gqf2.[QORT.ID]
                                               and gqf.[QORT.Trustee.ID] = gqf2.[QORT.Trustee.ID]
                                               and gqf.AuditHash != gqf2.AuditHash
    end
