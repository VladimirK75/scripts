CREATE     function [dbo].[DDM_Accounts]()
returns @tbl table ( 
                   id              float
                 , Enabled         float
                 , AccountCode     varchar(50)
                 , TradeCOde       varchar(12)
                 , ExportCode      varchar(32)
                 , FactCode        varchar(64)
                 , DivisionCode    varchar(64)
                 , AssetType       varchar(64)
                 , DepoFirm_ID     varchar(32)
                 , OwnerFirm_ID    varchar(32)
                 , SinglExportCode varchar(32)
				 , DDMAccountCode varchar(128) ) 
as
    begin
        declare 
               @OwnerID float
        select @OwnerID = f.id
          from QORT_DB_PROD..Firms f
         where f.Enabled = 0
               and f.IsOurs = 'y'
               and f.STAT_Const < 6
               and f.IsHeadBrok = 'y'
        insert into @tbl
        select a.id
             , a.Enabled
             , a.AccountCode
             , a.TradeCOde
             , a.ExportCode
             , a.FactCode
             , a.DivisionCode
             , AssetType = atc.Description
             , DepoFirm_ID = depof.BOCode
             , OwnerFirm_ID = ownerf.BOCode
             , SinglExportCode = isnull( (select nullif(a0.ExportCode, '')
                                            from QORT_DB_PROD..AccStructure ac0 with(nolock)
                                            inner join QORT_DB_PROD..Accounts a1 with(nolock) on a1.id = ac0.Father_ID
                                            inner join QORT_DB_PROD..AccountTypes act1 with(nolock) on a1.AccountType_ID = act1.id
                                                                                                       and act1.Name = 'Единый пул'
                                            inner join QORT_DB_PROD..AccStructure ac1 with(nolock) on ac1.Father_ID = ac0.Father_ID
                                            inner join QORT_DB_PROD..Accounts a0 with(nolock) on a0.id = ac1.Child_ID
                                            inner join QORT_DB_PROD..AccountTypes act0 with(nolock) on a0.AccountType_ID = act0.id
                                                                                                       and act0.Name = act1.Name
                                           where ac0.Child_ID = a.id), a.ExportCode)
             , DDMAccountCode = isnull( (select nullif(a0.AccountCode, '')
                                            from QORT_DB_PROD..AccStructure ac0 with(nolock)
                                            inner join QORT_DB_PROD..Accounts a1 with(nolock) on a1.id = ac0.Father_ID
                                            inner join QORT_DB_PROD..AccountTypes act1 with(nolock) on a1.AccountType_ID = act1.id
                                                                                                       and act1.Name = 'Единый пул'
                                            inner join QORT_DB_PROD..AccStructure ac1 with(nolock) on ac1.Father_ID = ac0.Father_ID
                                            inner join QORT_DB_PROD..Accounts a0 with(nolock) on a0.id = ac1.Child_ID
                                            inner join QORT_DB_PROD..AccountTypes act0 with(nolock) on a0.AccountType_ID = act0.id
                                                                                                       and act0.Name = act1.Name
                                           where ac0.Child_ID = a.id), a.AccountCode)
          from QORT_DB_PROD..Accounts a with(nolock)
          inner join QORT_DB_PROD..AssetType_Const atc with(nolock) on atc.[Value] = a.AssetType
          inner join QORT_DB_PROD..Firms depof with(nolock) on depof.id = isnull(nullif(a.DepoFirm_ID, -1), @OwnerID)
          inner join QORT_DB_PROD..Firms ownerf with(nolock) on ownerf.id = isnull(nullif(a.OwnerFirm_ID, -1), @OwnerID)
        return
    end
