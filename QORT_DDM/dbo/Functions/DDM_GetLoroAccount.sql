CREATE   function [dbo].[DDM_GetLoroAccount] ( 
                @NostroAccount varchar(50)
              , @LegalEntity   varchar(6)
              , @LoroAccount   varchar(50) ) 
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
        set @LoroAccount = isnull(@LoroAccount, @LegalEntity)
        /* case of ClearClient = 1 */
        if nullif(@NostroAccount, '') is not null
           and exists (select top 1 1
                         from QORT_DDM..NostroMapping nm with(nolock)
                         inner join QORT_DB_PROD..AccountTypes act with(nolock) on nm.Category = act.Name
                         inner join QORT_DB_PROD..Accounts a with(nolock) on a.AccountType_ID = act.id
                                                                             and a.Enabled = 0
                                                                             and a.AccountCode like nm.Nostro collate Cyrillic_General_CI_AS
                                                                             and a.AccountCode = @NostroAccount
                        where nm.ClearClient = 1)
                       and exists (select top 1 1
                                     from QORT_DDM..NostroMapping nm with(nolock)
                                    where nm.Nostro = @Nostroaccount
                                          and nm.ClearClient = 0) 
            set @LoroAccount = @LegalEntity
        /* case of Ignore = 1 */
        select @LoroAccount = iif(cla.Ignore = 1, null, isnull(cla.SubAccount, @LoroAccount))
          from QORT_DDM..ClientLoroAccount cla with(nolock)
         where @LoroAccount like LoroAccount
               and isnull(NostroAccount, @NostroAccount) like @NostroAccount
        return @LoroAccount
    end
