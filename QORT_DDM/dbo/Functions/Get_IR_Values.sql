create     function [dbo].[Get_IR_Values] ( 
                @TSSection_ID float
              , @SubaccCode   varchar(32)
              , @Comment1     varchar(100)
              , @Comment2     varchar(100)
              , @QUIKUID      bigint
              , @Trader       varchar(32)
              , @InfoSource   varchar(64)
              , @HM_Const     smallint ) 
returns table
as
return
with tmp_IR_Rules
     as (select ir.id
              , ir_rank = count(ir.Priority) over(
                order by ir.Priority asc)
              , ir.DM_Const
              , ir.TYPE_Const
              , ir.InstrSort_Const
              , ir.AuthorFIO
              , ir.AuthorPTS
           from QORT_DB_PROD..InstrRules ir(nolock)
          where 1 = 1
                and @TSSection_ID = isnull(nullif(ir.TSSection_ID, -1), @TSSection_ID)
                and @SubaccCode like isnull(nullif(replace(ir.SubaccCode, '*', '%'), ''), '%')
                and iif(@Comment1 like isnull(nullif(replace(ir.Comment, '*', '%'), ''), '%'), 1, 0) + iif(@Comment2 like isnull(nullif(replace(ir.Comment, '*', '%'), ''), '%'), 1, 0) > 0
                and @Trader like isnull(nullif(replace(ir.Trader, '*', '%'), ''), '%')
                and @InfoSource like isnull(nullif(replace(ir.InfoSource, '*', '%'), ''), '%')
                and @QUIKUID = isnull(nullif(ir.QUIKUID, 0), @QUIKUID)
                and @HM_Const = ir.HM_Const)
     select ir.id
          , ir.DM_Const
          , ir.TYPE_Const
          , ir.InstrSort_Const
          , ir.AuthorFIO
          , ir.AuthorPTS
       from tmp_IR_Rules ir
      where ir_rank = 1
