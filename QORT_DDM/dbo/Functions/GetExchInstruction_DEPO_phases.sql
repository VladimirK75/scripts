CREATE   function [dbo].[GetExchInstruction_DEPO_phases]
( @intDate     int
, @LegalEntity varchar(5)
, @Loro        varchar(50) = null
, @TCA         varchar(50) = null )
/* select * from dbo.GetExchInstruction_DEPO_phases (20190812, 'RENBR', null, null)*/
returns @Result table
( Depository        varchar(5)
, Broker            varchar(5)
, SettlementDate    date
, DepoClientID      varchar(50)
, DepoAccount       varchar(150)
, MarketName        varchar(15)
, InstructionID     float
, Direction         char(1)
, SecQty            decimal(34, 10)
, SecISIN           varchar(20)
, SecRegCode        varchar(32)
, EmitentBOCode     varchar(20)
, SecNSDCode        varchar(100)
, Amount            decimal(34, 10)
, AmountCurrencyISO int
, CP_BOCode         varchar(10)
, CP_NSDCode        varchar(100)
, InstructionType   varchar(10)
, ID                varchar(100)
, ExchageID         varchar(100)
, TradeDate         date
, InternalTradeRef  varchar(100) )
as
     begin
         declare @NKCKB_ID float
         select @NKCKB_ID = id
           from QORT_DB_PROD..Firms
          where BOCode = 'NKCKB';
         with tmp_Export
              as (select SettlementDate = convert(date, cast(iif(p.PC_Const <> 22
                                                                 and t.PutDate > 0, t.PutDate, p.PhaseDate) as varchar(20)))
                       , DepoClientID = isnull(( select pa.DepoCode
                                                   from QORT_DB_PROD..PayAccs pa with(nolock)
                                                  where pa.SubAcc_ID = p.SubAcc_ID
                                                        and nullif(pa.DepoCode, '') is not null
                                                        and pa.PutAccount_ID = p.PhaseAccount_ID
                                                  group by pa.DepoCode ), s.Comment)
                       , DepoAccount = concat(ac.FactCode, '/', ac.DivisionCode)
                       , MarketName = iif(t3.Code = 'XPET', '', 'MICEX Main') /* ОЧИЩАТЬ ДЛЯ СПБ */
                       , InstructionID = ltrim(str(p.ID, 15))
                       , Direction = iif(t.BuySell = 1, 'B', 'S')
                       , SecQty = abs(p.QtyBefore)
                       , SecISIN = i.ISIN
                       , SecRegCode = i.RegistrationCode
                       , SecShortName = emit.BOCode
                       , SecNSDCode = isnull(assc.Code, i.ISIN)
                       , Amount = abs(p.QtyBefore) * abs(t.Volume1 / t.Qty)
                       , AmountCurrencyISO = c.EmitNum
                       , CP_BOCode = ( select f.BOCode
                                         from QORT_DB_PROD..Firms f with(nolock)
                                        where f.ID = isnull(nullif(t.CpFirm_ID, -1), @NKCKB_ID) )
                       , CP_NSDCode = isnull(( select fc.Code
                                                 from QORT_DB_PROD..FirmCodes fc with(nolock)
                                                where fc.Firm_ID = isnull(nullif(t.CpFirm_ID, -1), @NKCKB_ID)
                                                      and patindex('%CPAM%', fc.InfoSource) > 0 ), '')
                       , InstructionType = iif(p.Enabled = 0, 'NEW', 'CANCEL')
                       , ExchageID = t.TradeNum
                       , TradeDate = convert(date, cast(t.TradeDate as varchar(20)))
                       , InternalTradeRef = 'QR' + ltrim(str(t.id, 15))
                    from QORT_DB_PROD.dbo.Phases as p with(nolock, index=I_Phases_PhaseDate)
                    inner join QORT_DB_PROD..Trades as t with(nolock, index=I_Trades_ID) on t.id = p.Trade_ID
                                                                         and not exists( select 1
                                                                                           from QORT_DB_PROD.dbo.Phases as p0 with(nolock)
                                                                                          where t.id = p0.Trade_ID
                                                                                                and p0.PC_Const in ( 29 ) /*PC_TERMINATION */   
                                                                         )
                    inner join QORT_DB_PROD..TSSections t2 with(nolock) on t.TSSection_ID = t2.id
                    inner join QORT_DB_PROD..TSs t3 with(nolock) on t2.TS_ID = t3.id
                                                                    and t3.IsMarket = 'y'
                    inner join QORT_DB_PROD..Subaccs as s with(nolock) on s.ID = p.SubAcc_ID
                                                                          and isnull(@Loro, s.SubAccCode) = s.SubAccCode
                    inner join QORT_DB_PROD..Firms as f0 with(nolock) on s.OwnerFirm_ID = f0.ID
                                                                         and patindex(@LegalEntity, f0.BOCode) = 0
                    inner join QORT_DB_PROD..Assets as i with(nolock) on i.ID = p.PhaseAsset_ID and i.AssetType_Const=1
                    inner join QORT_DB_PROD..Assets as c with(nolock) on c.ID = t.CurrPayAsset_ID
                    inner join QORT_DB_PROD..Firms as so with(nolock) on so.ID = s.OwnerFirm_ID
                    inner join QORT_DB_PROD..Accounts as ac with(nolock) on ac.ID = p.PhaseAccount_ID
                                                                            and isnull(@TCA, ac.ExportCode) = ac.ExportCode
                    left join QORT_DB_PROD..AssetCodes assc with(nolock) on i.id = assc.Asset_ID
                                                                            and assc.Name = 'Код НРД Aladdin'
                    left join QORT_DB_PROD..Firms as emit with(nolock) on i.EmitentFirm_ID = emit.id
                   where 1 = 1
                         and p.PhaseDate = @intDate
                         and isnull(p.IsCanceled, 'n') = 'n'
                         and p.PC_Const in ( 3, 4, 22 ) /* PC_PART_PUT, PC_PUT, PC_COMPENSATE_SEC*/ 
                         --and t.id  in (225442393,225442394)
                         and SubAccCode not like 'ARB%')
              insert into @Result
              select Depository = 'RENBR'
                   , Broker = @LegalEntity
                   , SettlementDate
                   , DepoClientID
                   , DepoAccount
                   , MarketName
                   , InstructionID = max(InstructionID)
                   , Direction
                   , SecQty = sum(SecQty)
                   , SecISIN
                   , SecRegCode
                   , SecShortName
                   , SecNSDCode
                   , Amount = round(sum(Amount), 2)
                   , AmountCurrencyISO
                   , CP_BOCode
                   , CP_NSDCode
                   , InstructionType
                   , ID = ''
                   , ExchageID = ltrim(str(max(ExchageID), 12))
                   , TradeDate
                   , InternalTradeRef = max(InternalTradeRef)
                from tmp_Export p
               group by SettlementDate
                      , DepoClientID
                      , DepoAccount
                      , MarketName
                      , SecISIN
                      , SecNSDCode
                      , SecRegCode
                      , SecShortName
                      , Direction
                      , AmountCurrencyISO
                      , CP_BOCode
                      , CP_NSDCode
                      , InstructionType
                      , TradeDate
         return
     end
