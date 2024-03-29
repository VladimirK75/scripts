CREATE function [dbo].[Get_RepoRerateEvents](
               @TradeID int = 0
             , @Date    int = 0)
returns @RepoRerateEvent table ( 
                               TradeID         int
                             , EventDate       int
                             , EventTime       int
                             , RepoRatePrev    float
                             , RepoRateCurrent float ) 
as
    begin
        ;
        with tb_REPORerate(Founder_ID
                         , Corrected_Date
                         , Corrected_Time
                         , RepoRatePrev
                         , RepoRateCurrent
                         , id)
             as (select th.Founder_ID
                      , th.Corrected_Date
                      , th.Corrected_Time
                      , RepoRatePrev = t0.RepoRate
                      , RepoRateCurrent = th.RepoRate
                      , t0.id
                   from QORT_DB_PROD..TradesHist th with(nolock)
                   inner join QORT_DB_PROD..TradesHist t0 with(nolock) on t0.Founder_ID = th.Founder_ID
                                                                          and t0.modified_date <= th.Corrected_Date
                                                                          and t0.ID < th.ID
                                                                          and t0.RepoRate <> th.RepoRate
                                                                          and t0.IsRepo2 = 'n'
                  where 1 = 1
                        and iif(th.Founder_ID = @TradeID, 1, 0) + iif(isnull(@TradeID, 0) = 0, 1, 0) = 1
                        and iif(th.Corrected_Date = @Date, 1, 0) + iif(isnull(@Date, 0) = 0, 1, 0) = 1)
             insert into @RepoRerateEvent
             select t0.Founder_ID
                  , t0.Corrected_Date
                  , t0.Corrected_Time
                  , t0.RepoRatePrev
                  , t0.RepoRateCurrent
               from tb_REPORerate t0
              where not exists (select 1
                                  from tb_REPORerate t1
                                 where t0.Founder_ID = t1.Founder_ID
                                       and t0.id < t1.id) 
        return
    end
/*
	select * from [Get_RepoRerateEvents] (null, 20181112)
	*/
