create procedure GetDuplicatesMailFirms
as
    begin
        drop table if exists #Firms_Information
        drop table if exists #tmp_Mail
        declare @FirmID    float
              , @Mail_List varchar(1024)
              , @pos       int
              , @tmpMail   varchar(64)
        create table #tmp_Mail
        ( id   float
        , Mail varchar(64) )
        select RowID = row_number() over(
               order by f.id)
             , f.id
             , f.BOCode
             , f.FirmShortName
             , s.SubAccCode
             , MarginEMail = replace(s.MarginEMail, ',', ';')
             , Email = replace(f.Email, ',', ';')
             , f.Phones
        into #Firms_Information
          from QORT_DB_PROD..Firms f with(nolock)
          left join QORT_DB_PROD..Subaccs s with(nolock) on f.id = s.OwnerFirm_ID
         where 1 = 1
               and s.Enabled = 0
               and f.Enabled = 0
               and f.id <> 70736
               and (s.MarginEMail != ''
                    or f.Email != ''
                    or f.Phones != '')
        delete from #Firms_Information
         where exists( select 1
                         from #Firms_Information fi1
                        where #Firms_Information.id = fi1.id
                              and concat(#Firms_Information.MarginEMail, #Firms_Information.Email) = concat(fi1.MarginEMail, fi1.Email)
                              and #Firms_Information.RowID > fi1.RowID )
        declare tmp_cur_DataMails cursor local fast_forward
        for select #Firms_Information.id
                 , Mails = concat(#Firms_Information.MarginEMail, iif(#Firms_Information.MarginEMail != '', ';', ''), #Firms_Information.Email)
              from #Firms_Information
        open tmp_cur_DataMails
        fetch next from tmp_cur_DataMails into @FirmID
                                             , @Mail_List
        while @@FETCH_STATUS = 0
            begin
                while charindex(';', @Mail_List) > 0
                    begin
                        select @pos = charindex(';', @Mail_List)
                        select @tmpMail = ltrim(rtrim(substring(@Mail_List, 1, @pos - 1)))
                        if nullif(@tmpMail, '') is not null
                           and not exists( select 1
                                             from #tmp_Mail tl
                                            where tl.id = @FirmID
                                                  and tl.Mail = @tmpMail )
                            insert into #tmp_Mail
                            ( id
                            , Mail
                            )
                            values
                            ( @FirmID
                            , @tmpMail
                            )
                        select @Mail_List = substring(@Mail_List, @pos + 1, len(@Mail_List) - @pos)
                             , @tmpMail = null
                    end
                fetch next from tmp_cur_DataMails into @FirmID
                                                     , @Mail_List
            end
        close tmp_cur_DataMails
        deallocate tmp_cur_DataMails
        select WarnMail = tm.Mail
             , fi.*
          from #tmp_Mail tm
          inner join #Firms_Information fi on fi.id = tm.id
         where exists( select 1
                         from #tmp_Mail tm2
                        where tm2.Mail = tm.Mail
                              and tm2.id != tm.id )
        order by tm.Mail
               , fi.BOCode
               , fi.id
        return
    end
