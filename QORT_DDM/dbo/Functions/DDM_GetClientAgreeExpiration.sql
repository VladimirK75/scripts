create   function DDM_GetClientAgreeExpiration(@FairForward int) returns @tbl table
( FirmShortName varchar(150)
, SubAccCode    varchar(12)
, ShortName     varchar(16)
, Num           varchar(64)
, DateCreate    date
, DateEnd       date ) as begin
                          insert into @tbl
                          select f.FirmShortName
                               , s.SubAccCode
                               , cat.ShortName
                               , ca.Num
                               , DateCreate = qort_ddm.dbo.DDM_GetDateTimeFromInt( ca.DateCreate, 0 )
                               , DateEnd = qort_ddm.dbo.DDM_GetDateTimeFromInt( ca.DateEnd, 0 )
                            from QORT_DB_PROD..ClientAgrees ca with(nolock)
                            left join QORT_DB_PROD..ClientAgreeTypes cat with(nolock) on cat.id = ca.ClientAgreeType_ID
                            inner join QORT_DB_PROD..Subaccs s with(nolock) on s.id = ca.SubAcc_ID
                            left join QORT_DB_PROD..Firms f with(nolock) on f.id = s.OwnerFirm_ID
                           where ca.DateEnd between qort_ddm.dbo.DDM_fn_AddBusinessDay( null, 0, null ) and qort_ddm.dbo.DDM_fn_AddBusinessDay( null, @FairForward, null )
return
end
