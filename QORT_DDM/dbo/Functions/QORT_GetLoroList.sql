CREATE function [dbo].[QORT_GetLoroList](@Subac_List varchar(max))
returns @tmp_Loro table
( Loro         varchar(32)
, Subacc_ID    float
, IsAnalytic   bit
, TradeCode    varchar(12)
, FirmCode     varchar(32)
, ACSTAT_Const smallint )
as
     begin
         declare @Delimiter char(1)     = ','
               , @pos       smallint
               , @b         smallint
               , @tmpLoro   varchar(32)
         select @Subac_List = concat(isnull(@Subac_List, ''), @Delimiter)
         while charindex(',', @Subac_List) > 0
             begin
                 select @pos = charindex(@Delimiter, @Subac_List)
                 select @tmpLoro = ltrim(rtrim(substring(@Subac_List, 1, @pos - 1)))
                 if nullif(@tmpLoro, '') is not null
                    and not exists( select 1
                                      from @tmp_Loro tl
                                     where tl.Loro = @tmpLoro )
                     insert into @tmp_Loro
                     ( Loro
                     , Subacc_ID
                     , IsAnalytic
                     , TradeCode
                     , FirmCode
                     , ACSTAT_Const
                     )
                     select s.SubAccCode
                          , s.ID
                          , iif(s.IsAnalytic = 'y', 1, 0)
                          , s.TradeCode
                          , s.FirmCode
                          , s.ACSTAT_Const
                       from QORT_DB_PROD.dbo.Subaccs s with(nolock)
                      where 1 = 1
                            and s.SubAccCode like @tmpLoro
                        --  and s.IsAnalytic = 'n'
                            and s.Enabled = 0
                     union 
                     select s2.SubAccCode
                          , s2.ID
                          , iif(s2.IsAnalytic = 'y', 1, 0)
                          , s.TradeCode
                          , s.FirmCode
                          , s.ACSTAT_Const
                       from QORT_DB_PROD.dbo.SubaccStructure ss with(nolock)
                       inner join QORT_DB_PROD.dbo.Subaccs s with(nolock) on s.id = ss.Father_ID
                                                                             and s.SubAccCode like @tmpLoro
                                                                             and s.IsAnalytic = 'y'
                       inner join QORT_DB_PROD.dbo.Subaccs s2 with(nolock) on s2.id = ss.Child_ID
                                                                              and s2.enabled = 0
                 select @Subac_List = substring(@Subac_List, @pos + 1, len(@Subac_List) - @pos)
                      , @tmpLoro = null
             end
         return
     end
