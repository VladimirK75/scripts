create   procedure QORT_GetAttorneyPhasesBreaks
as
begin
drop table if exists #tmp_TradeID
declare @CurrentDate int = format(getdate(),'yyyyMMdd')

select tsd.tradeid, tsd.delivery_phase, tsd.payment_phase
into #tmp_TradeID
from QORT_CACHE_DB..trade_si_details tsd with(nolock) 
where 'No' in (tsd.delivery_phase, tsd.payment_phase)
and left(ltrim(str(cast(tsd.timestamp as bigint),18)),8)>format(dateadd(dd,-60,getdate()),'yyyyMMdd')

alter table #tmp_TradeID add Trade_SID float null

update tti
set tti.Trade_SID= isnull(nullif(it.SystemID,-1), it.Modified_System_ID)
from #tmp_TradeID tti 
inner join QORT_TDB_PROD..ImportTrades it with(nolock) on it.TradeNum = tti.tradeid
and not exists (select 1 from QORT_TDB_PROD..ImportTrades it2 with(nolock) where it2.TradeNum=it.TradeNum and it2.id>it.id and it2.IsProcessed<4)
and it.IsProcessed<4

 

delete from #tmp_TradeID where isnull(Trade_SID,-1) =-1

 

delete from #tmp_TradeID
where exists (select 1 from QORT_DB_PROD..Phases p with(nolock) where p.Trade_ID=Trade_SID and p.IsCanceled='n' and p.PC_Const in (17,18,20,29))

 

alter table #tmp_TradeID add Phase_PUT float null
alter table #tmp_TradeID add PutDate int null
alter table #tmp_TradeID add Phase_PAY float null
alter table #tmp_TradeID add PayDate int null

 

update tti
set PutDate=isnull(nullif(t.PutDate,0),t.PutPlannedDate), PayDate=isnull(nullif(t.PayDate,0),t.PayPlannedDate)
from #tmp_TradeID tti 
inner join QORT_DB_PROD..Trades t with(nolock) on t.id=tti.Trade_SID

 

update tti
set Phase_PUT = p.ID
from #tmp_TradeID tti 
inner join QORT_DB_PROD..Phases p with(nolock) on p.Trade_ID=tti.Trade_SID and p.IsCanceled='n' and p.PC_Const =27

 

update tti
set Phase_PAY = p.ID
from #tmp_TradeID tti 
inner join QORT_DB_PROD..Phases p with(nolock) on p.Trade_ID=tti.Trade_SID and p.IsCanceled='n' and p.PC_Const =26

 

delete from #tmp_TradeID where @CurrentDate<PutDate and @CurrentDate<PayDate

 

select * from #tmp_TradeID tti 
where iif((tti.delivery_phase = 'No' and tti.Phase_PUT is not null)
       or (tti.delivery_phase != 'No' and tti.Phase_PUT is null), 1, 0)+
      iif((tti.payment_phase  = 'No' and tti.Phase_PAY is not null)
      or (tti.payment_phase  != 'No' and tti.Phase_PAY is null)      , 1, 0) != 2
end
