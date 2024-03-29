CREATE   function [dbo].[GetDDM_IM] ( 
                @intDate  int
              , @LoroID   varchar(6)  = null
              , @ClientID varchar(5)  = null
              , @NostroID varchar(50) = null ) 
returns @Result table ( 
                      ID                  float
                    , EntityID            varchar(10)
                    , EntityCode          varchar(10)
                    , BookID              varchar(20)
                    , BookCode            varchar(20)
                    , CounterpartyID      varchar(20)
                    , CounterpartyCode    varchar(20)
                    , ClientID            varchar(5)
                    , ClientCode          varchar(5)
                    , SubAccCode          varchar(20)
                    , LoroID              varchar(32)
                    , LoroCode            varchar(6)
                    , NostroID            varchar(50)
                    , NostroCode          varchar(50)
                    , TraderID            varchar(100)
                    , TraderName          varchar(100)
                    , UserID              varchar(50)
                    , UserName            varchar(50)
                    , TradeDate           int
                    , SettleDate          int
                    , Direction           int
                    , Currency            varchar(10)
                    , Amount              float
                    , BackOfficeNotes     varchar(255)
                    , ChargeType          varchar(100)
                    , TransactingCapacity varchar(100)
                    , IssueID             varchar(20)
                    , IssueCode           varchar(20)
                    , TCA                 varchar(100)
                    , ExchangeSector      varchar(100)
                    , ExchangeID          varchar(100)
                    , ExchangeCode        varchar(100)
                    , MIC                 varchar(100) ) 
as
    begin
        declare 
               @datetime datetime
        select @datetime = left(convert(varchar(8), @intDate), 4) + '-' + substring(convert(varchar(8), @intDate), 5, 2) + '-' + right(convert(varchar(8), @intDate), 2)
        if datepart(weekday, @datetime) in(1, 7)
           and exists (select 1
                         from QORT_DB_PROD.dbo.CalendarDates
                        where Calendar_ID = 5
                              and Date = @intDate)
           or datepart(weekday, @datetime) not in(1, 7)
           and not exists (select 1
                             from QORT_DB_PROD.dbo.CalendarDates
                            where Calendar_ID = 5
                                  and Date = @intDate)
        /*  if datepart(weekday,@datetime) not in (1,7)*/ 
            begin
                with DDM_IM(ID
                          , EntityID
                          , BookID
                          , CounterpartyID
                          , ClientID
                          , SubAccCode
                          , LoroID
                          , NostroID
                          , TraderID
                          , UserID
                          , TradeDate
                          , Currency
                          , Amount
                          , Direction
                          , BackOfficeNotes
                          , ChargeType
                          , TransactingCapacity
                          , IssueID
                          , IssueCode
                          , TCA
                          , ExchangeSector
                          , ExchangeID
                          , ExchangeCode
                          , MIC)
                     as (select ID = POS.ID
                              , EntityID = 'RENBR'
                              , BookID = 'NONE'
                              , CounterpartyID = 'TSRTS'
                              , ClientID = F.BOCode
                              , SubAccCode = SA.SubAccCode
                              , LoroID = case
                                              when SA.SubaccCode like 'DC%' then 'RBF331'
                                              when F.BOCode = 'RENBR' then ''
                                              when SA.SubaccCode in('RESEC', 'RESECEQ', 'RESECFI', 'SPBFUT00RDP', 'SPBFUT00RES', 'SPBFUT00EPG', 'SPBFUT00RUS', 'SPBFUT77RES', 'SPBFUT77EPG', 'SPBFUT00RST', 'SPBFUT00RSTSGK', 'SPBFUT00TSS', 'SPBFUTZZ000','SPBFUT05RDP') then 'UMG873'
                                            else SA.SubaccCode
                                         end
                              , NostroID = ACC.ExportCode
                              , TraderID = 'NONE'
                              , UserID = 'NONE'
                              , TradeDate = POS.OldDate
                              , Currency = replace(A.ShortName, 'RUR', 'RUB')
                              , Amount = abs(POS.VolGO)
                              , Direction = -1
                              , BackOfficeNotes = 'FORTS Initial margin'
                              , ChargeType = 'INITIAL_MARGIN'
                              , TransactingCapacity = iif(F.BOCode = 'RENBR', 'Principal', 'Agency')
                              , IssueID = null
                              , IssueCode = ''
                              , TCA = SA.TradeCode
                              , ExchangeSector = 'FORTS'
                              , ExchangeID = 'TSRTS'
                              , ExchangeCode = 'TSRTS'
                              , MIC = 'RTSX'
                           from QORT_DB_PROD..PositionHist POS with(nolock)
                           join QORT_DB_PROD..SubAccs SA with(nolock) on SA.id = POS.Subacc_ID
                           join QORT_DB_PROD..Firms F with(nolock) on F.id = SA.OwnerFirm_ID
                           join QORT_DB_PROD..Assets A with(nolock) on A.id = POS.Asset_ID
                           join QORT_DB_PROD..Accounts ACC with(nolock) on ACC.id = POS.Account_ID
                          where POS.OldDate = @intDate
                                and POS.VolGO <> 0
                                and POS.Asset_ID = 71273
                         )
                     insert into @Result
                     select ID
                          , EntityID
                          , EntityID as       EntityCode
                          , BookID
                          , BookID as         BookCode
                          , CounterpartyID
                          , CounterpartyID as CounterpartyCode
                          , ClientID
                          , ClientID as       ClientCode
                          , SubAccCode
                          , LoroID
                          , LoroID as         LoroCode
                          , NostroID = QORT_DDM.dbo.GetDDM_NostroMapping(NostroID, 'Единый пул', 0)
                          , NostroID as       NostroCode
                          , TraderID
                          , TraderID as       TraderName
                          , UserID
                          , UserID as         UserName
                          , TradeDate as      TradeDate
                          , TradeDate as      SettleDate
                          , Direction
                          , Currency
                          , Amount
                          , BackOfficeNotes
                          , ChargeType
                          , TransactingCapacity
                          , IssueID
                          , IssueCode
                          , TCA
                          , ExchangeSector
                          , ExchangeID
                          , ExchangeCode
                          , MIC
                       from DDM_IM
                      where 1 = 1
                            and LoroID = isnull(@LoroID, LoroID)
                            and ClientID = isnull(@ClientID, ClientID)
                            and NostroID = isnull(@NostroID, NostroID)
        end
        return
    end
