CREATE   function [dbo].[DDM_GetNostroAccount] ( 
                @NostroAccount varchar(50)
              , @LegalEntity   varchar(6)
              , @LoroAccount   varchar(6) ) 
returns varchar(50)
as
    begin
        if @LegalEntity is null
            select @LegalEntity = f.BOCode
              from QORT_DB_PROD..Firms f
             where f.Enabled = 0
                   and f.IsOurs = 'y'
                   and f.STAT_Const < 6
                   and f.IsHeadBrok = 'y'
        /* MICEX Unified Pool Settlement Accounts */
        select @NostroAccount = a.ExportCode
          from QORT_DB_PROD..Subaccs s with(nolock)
          inner join QORT_DB_PROD..AccountTypes act with(nolock) on s.AccountType_ID = act.id
                                                                    and act.Name = 'единый пул'
          inner join QORT_DB_PROD..PayAccs pa with(nolock) on pa.SubAcc_ID = s.id
          inner join QORT_DB_PROD..Accounts a with(nolock) on a.id = pa.PayAccount_ID
                                                              and a.Enabled = 0
                                                              and getdate() between iif(a.DateStart < 1, dateadd(dd, -1, getdate()), cast(cast(a.DateStart as char) as date)) and iif(a.DateEnd > 0, cast(cast(a.DateStart as char) as date), dateadd(dd, 1, getdate()))
         where s.SubAccCode = @LoroAccount
        /* set default value by LegalEntity & LoroAccount */
        if nullif(@NostroAccount, '') is null
            select @NostroAccount = first_value(pm.NostroAccount) over(
                   order by pm.Priority)
              from QORT_DDM..POAccountsMapping pm with(nolock)
             where pm.LegalEntity = isnull(@LegalEntity, pm.LegalEntity)
                   and @LoroAccount like pm.LoroAccount
        /* set null value if nm.Ignore=1 */
        if exists (select top 1 1
                     from QORT_DDM..NostroMapping nm with(nolock)
                    where nm.Ignore = 1
                          and nm.Nostro = @Nostroaccount) 
            set @NostroAccount = null
           else
            select @NostroAccount = iif(nm.Ignore = 1, null, isnull(nm.AccountCode, a.ExportCode collate Cyrillic_General_CI_AS))
              from QORT_DB_PROD..Accounts a with(nolock)
              left join QORT_DB_PROD..AccountTypes ca with(nolock) on a.AccountType_ID = ca.ID
              left join QORT_DDM..NostroMapping nm with(nolock) on a.AccountCode like nm.Nostro collate Cyrillic_General_CI_AS
                                                                   and not a.AccountCode = nm.Nostro collate Cyrillic_General_CI_AS
                                                                   and isnull(ca.Name, '') = coalesce(nm.Category, ca.Name, '')
             where a.AccountCode = @NostroAccount
                   and a.Enabled = 0
                   and nullif(a.ExportCode, '') is not null
        return @NostroAccount
    end
