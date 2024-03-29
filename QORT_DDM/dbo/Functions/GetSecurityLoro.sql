CREATE   function [dbo].[GetSecurityLoro]
( @Num varchar(32) 
, @Category varchar(32) )
returns @tbl table
( SubAccCode varchar(16)
, Num        varchar(64)
, Comment    varchar(128) )
as
     begin
         declare @CurDate int = format(getdate(), 'yyyyMMdd')
         set @CurDate = ( select top 1 od.Day
                            from QORT_DB_PROD..OperationDays od
                          order by id desc )
         insert into @tbl
         select distinct sub.SubAccCode
              , ca.Num
              , ca.Comments
           from QORT_DB_PROD..ClientAgrees ca with(nolock)
           inner join QORT_DB_PROD..ClientAgreeTypes cat with(nolock) on ca.ClientAgreeType_ID = cat.id
                                                                         and cat.ShortName = @Category --'OTC_MOEX'
           inner join QORT_DB_PROD..Subaccs sub with(nolock) on ca.SubAcc_ID = sub.id
          where 1 = 1
                and ca.Enabled = 0
				and ca.Num like @Num
                and isnull(nullif(ca.DateSign, 0), @CurDate) <= @CurDate
                and isnull(nullif(ca.DateEnd, 0), @CurDate) >= @CurDate
         return
     end
