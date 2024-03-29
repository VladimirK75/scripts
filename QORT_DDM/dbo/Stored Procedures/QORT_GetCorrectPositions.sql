CREATE procedure dbo.QORT_GetCorrectPositions @FarBack int
as
    begin
        set @FarBack = isnull(@FarBack, 21)
        select Env = 'RENBR'
             , id
             , corr_tr = left(backid, charindex('/', backid) - 1)
             , TransferID = iif(infosource = 'BackOffice', reverse(left(reverse(backid), charindex('/', reverse(backid)) - 1)), left(backid, charindex('/', backid) - 1))
             , iscanceled
             , backid
             , date
             , 'JUSTDNTWNTDECLARE' as CalSt
          from( select id
                     , backid
                     , iscanceled
                     , date
                     , infosource
                     , row_number() over(partition by iif(infosource = 'BackOffice', reverse(left(reverse(backid), charindex('/', reverse(backid)) - 1)), left(backid, charindex('/', backid) - 1))
                       order by iif(iscanceled = 'y', 2, 1) asc) as rn
                  from qort_db_prod.dbo.CorrectPositions cp with (nolock, index = I_CorrectPositions_BackID)
                 where backid in( select backid
                                    from qort_db_prod.dbo.correctpositions with (nolock, index = I_CorrectPositions_Date)
                                   where date > format(dateadd(dd, -1 * @FarBack, getdate()), 'yyyyMMdd')
                                         and len(backid) > 9
                                         and isnumeric(iif(infosource = 'BackOffice', reverse(left(reverse(backid), charindex('/', reverse(backid)) - 1)), left(backid, charindex('/', backid) - 1))) = 1
                                         and len(backid) - len(REPLACE(backid, '/', '')) in ( 1, 2 ) ) ) temp
         where rn = 1
    end
