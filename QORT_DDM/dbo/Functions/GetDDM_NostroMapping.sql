CREATE   function [dbo].[GetDDM_NostroMapping] ( 
                @NostroAccount varchar(64)
              , @AccType       varchar(32)
              , @IO            bit ) 
returns varchar(32)
as
    begin
        declare 
               @ExportCode varchar(64)
        if @IO = 0
            begin
                select @ExportCode = nullif(a0.ExportCode, '')
                  from QORT_DB_PROD..Accounts a with(nolock)
                  inner join QORT_DB_PROD..AccStructure ac0 with(nolock) on ac0.Child_ID = a.id
                  inner join QORT_DB_PROD..Accounts a1 with(nolock) on a1.id = ac0.Father_ID
                  inner join QORT_DB_PROD..AccountTypes act1 with(nolock) on a1.AccountType_ID = act1.id
                                                                             and act1.Name = @AccType
                  inner join QORT_DB_PROD..AccStructure ac1 with(nolock) on ac1.Father_ID = ac0.Father_ID
                  inner join QORT_DB_PROD..Accounts a0 with(nolock) on a0.id = ac1.Child_ID
                  inner join QORT_DB_PROD..AccountTypes act0 with(nolock) on a0.AccountType_ID = act0.id
                                                                             and act0.Name = @AccType
                 where nullif(@NostroAccount, '') in (a.ExportCode, a.AccountCode) 
        end
        return isnull(@ExportCode, @NostroAccount)
    end
