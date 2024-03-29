--select * from [GetExchInstruction_DEPO] (20180801, 'RENBR', null, null) where SecISIN = 'RU000A0JPNM1'

--select * from QORT_DB_PROD..AssetCodes

CREATE   function [dbo].[GetExchInstruction_DEPO] (
                @intDate     int,
                @LegalEntity varchar(5),
                @Loro        varchar(50) = null,
                @TCA         varchar(50) = null )
returns @Result table (
                      Depository        varchar(5),
                      Broker            varchar(5),
                      SettlementDate    date,
                      DepoClientID      varchar(50),
                      DepoAccount       varchar(150),
                      MarketName        varchar(15),
                      InstructionID     float,
                      Direction         char(1),
                      SecQty            decimal(34, 10),
                      SecISIN           varchar(20),
                      SecRegCode        varchar(32),
                      EmitentBOCode     varchar(20),
                      SecNSDCode        varchar(100),
                      Amount            decimal(34, 10),
                      AmountCurrencyISO int,
                      CP_BOCode         varchar(10),
                      CP_NSDCode        varchar(100),
                      InstructionType   varchar(10),
                      ID                varchar(100),
                      ExchangeID         varchar(100),
                      TradeDate         date,
                      InternalTradeRef  varchar(100) )
as
    begin
        declare
               @NKCKB_ID float
        select  @NKCKB_ID = id
          from  QORT_DB_PROD..Firms
          where BOCode = 'NKCKB'
    begin
        with Aladdin_Instr(ID
                         , Depository
                         , Broker
                         , SettlementDate
                         , DepoClientID
                         , DepoAccount
                         , MarketName
                         , SecISIN
                         , SecRegCode
                         , SecShortName
                         , SecQty
                         , Direction
                         , InstructionID
                         , SecNSDCode
                         , ExchageID
                         , Amount
                         , AmountCurrencyISO
                         , CP_ID
                         , InstructionType
                         , TradeDate
                         , InternalTradeRef)
             as (
             select   '' as                                                 ID
                    , 'RENBR' as                                            Depository
                    , @LegalEntity as                                       Broker
                    , convert(date, cast(PutPlannedDate as varchar(20))) as SettlementDate
                    , s.Comment as                                          DepoClientID
                    , ac.FactCode+'/'+ac.DivisionCode as                    DepoAccount
                    , 'MICEX Main' as                                       MarketName
                    , i.ISIN as                                             SecISIN
                    , i.RegistrationCode as                                 SecRegCode
/*, i.ShortName as SecShortName*/
                    , emit.BOCode
                    , a.Qty as                                              SecQty
                    , case a.BuySell
                          when 1 then 'B'
                          when 2 then 'S'
                      end as                                                Direction
                    , a.ID as                                               InstructionID
                    , isnull(assc.Code, i.ISIN) as                          SecNSDCode
                    , a.ID as                                               ExchageID
                    , a.Sum as                                              Amount
                    , c.EmitNum as                                          AmountCurrencyISO
                    , case isnull(CPFirm_ID, -1)
                          when-1 then @NKCKB_ID
                          else CPFirm_ID
                      end as                                                CP_ID
                    , case
                          when a.Enabled = 0 then 'NEW'
                          else 'CANCEL'
                      end as                                                InstructionType
                    , convert(date, cast(a.TradeDate as varchar(20))) as    TradeDate
                    , a.Reference as                                        InternalTradeRef
               from   QORT_DB_PROD..Aggregates a with (nolock)
               inner join QORT_DB_PROD..Subaccs s with (nolock) on a.SubAcc_ID = s.ID
               inner join QORT_DB_PROD..Accounts ac with (nolock) on a.PutAccount_ID = ac.ID
               inner join QORT_DB_PROD..Assets i with (nolock) on a.Asset_ID = i.ID
               inner join QORT_DB_PROD..Assets c with (nolock) on a.CurrPayAsset_ID = c.ID
               inner join QORT_DB_PROD..Firms so with (nolock) on s.OwnerFirm_ID = so.ID
               left join QORT_DB_PROD..Firms emit with (nolock) on i.EmitentFirm_ID = emit.id
			   left join QORT_DB_PROD..AssetCodes assc with (nolock) on i.id = assc.Asset_ID and assc.Name = 'Код НРД Aladdin'
               where a.PutPlannedDate = @intDate
/*and (case when @intDate = convert(varchar(10), getdate(), 112) and a.created_date = a.modified_date and a.modified_date <= @intDate
							   then a.Enabled 
							   else 0 
						  end) = 0
					 and a.Enabled = 0*/
                     and ((a.modified_date > @intDate
                           and a.Enabled <> 0)
                          or (a.Enabled = 0))
                     and isnull(@Loro, s.SubAccCode) = s.SubAccCode
                     and isnull(@TCA, ac.ExportCode) = ac.ExportCode
                     and so.BOCode <> @LegalEntity
             union all
             select   '' as                                                 ID
                    , 'RENBR' as                                            Depository
                    , @LegalEntity as                                       Broker
                    , convert(date, cast(PutPlannedDate as varchar(20))) as SettlementDate
                    , s.Comment as                                          DepoClientID
                    , ac.FactCode+'/'+ac.DivisionCode as                    DepoAccount
                    , 'MICEX Main' as                                       MarketName
                    , i.ISIN as                                             SecISIN
                    , i.RegistrationCode as                                 SecRegCode
                    , emit.BOCode
                    , trd.Qty as                                            SecQty
                    , case trd.BuySell
                          when 1 then 'B'
                          when 2 then 'S'
                      end as                                                Direction
                    , p.ID as                                               InstructionID
                    , isnull(assc.Code, i.ISIN) as                          SecNSDCode
                    , p.ID as                                               ExchageID
                    , p.QtyBefore as                                        Amount
                    , c.EmitNum as                                          AmountCurrencyISO
                    , case isnull(CPFirm_ID, -1)
                          when-1 then @NKCKB_ID
                          else CPFirm_ID
                      end as                                                CP_ID
                    , case
                          when p.Enabled = 0 then 'NEW'
                          else 'CANCEL'
                      end as                                                InstructionType
                    , convert(date, cast(p.PhaseDate as varchar(20))) as    TradeDate
                    , p.PDocNum as                                          InternalTradeRef
               from   QORT_DB_PROD.dbo.Phases p with (nolock)
               inner join QORT_DB_PROD..Trades trd with (nolock, index = I_Trades_ID) on trd.id = p.Trade_ID
                                                                                         and trd.TT_Const = 3
               inner join QORT_DB_PROD..Subaccs s with (nolock) on s.ID = p.SubAcc_ID
               inner join QORT_DB_PROD..Assets i with (nolock) on i.ID = p.PhaseAsset_ID
               inner join QORT_DB_PROD..Assets c with (nolock) on c.ID = trd.CurrPayAsset_ID
               inner join QORT_DB_PROD..Firms so with (nolock) on so.ID = s.OwnerFirm_ID
               inner join QORT_DB_PROD..Accounts ac with (nolock) on ac.ID = p.PhaseAccount_ID
               left join QORT_DB_PROD..Firms emit with (nolock) on i.EmitentFirm_ID = emit.id
                left join QORT_DB_PROD..AssetCodes assc with (nolock) on i.id = assc.Asset_ID and assc.Name = 'Код НРД Aladdin'
              
			   where 1 = 1
                     and p.PhaseDate = @intDate
                     and p.IsCanceled = 'n'
                     and p.PC_Const in(22) /* PC_PART_PAY, PC_PAY*/
             union all
             select  '' as                                                 ID
                   , 'RENBR' as                                            Depository
                   , @LegalEntity as                                       Broker
                   , convert(date, cast(PutPlannedDate as varchar(20))) as SettlementDate
                   , s.Comment as                                          DepoClientID
                   , ac.FactCode+'/'+ac.DivisionCode as                    DepoAccount
                   , 'MICEX Main' as                                       MarketName
                   , i.ISIN as                                             SecISIN
                   , i.RegistrationCode as                                 SecRegCode
                   , emit.BOCode
                   , t.Qty as                                              SecQty
                   , case t.BuySell
                         when 1 then 'B'
                         when 2 then 'S'
                     end as                                                Direction
                   , t.ID as                                               InstructionID
                   , isnull(assc.Code, i.ISIN) as                          SecNSDCode
                   , t.ID as                                               ExchageID
                   , t.Volume1 as                                          Amount
                   , c.EmitNum as                                          AmountCurrencyISO
                   , case isnull(t.CPFirm_ID, -1)
                         when-1 then @NKCKB_ID
                         else t.CPFirm_ID
                     end as                                                CP_ID
                   , case
                         when t.Enabled = 0 then 'NEW'
                         else 'CANCEL'
                     end as                                                InstructionType
                   , convert(date, cast(t.TradeDate as varchar(20))) as    TradeDate
                   , 'QR'+ltrim(str(t.id)) as                              InternalTradeRef
               from  QORT_DB_PROD..Trades t with (nolock, index = I_Trades_PutPlannedDate)
               inner loop join(select TSSection_ID
                                 from QORT_DB_PROD..AggRuleTSSections with (nolock)
                                 group by TSSection_ID) tsag on tsag.TSSection_ID = t.TSSection_ID
               inner join QORT_DB_PROD..Subaccs s with (nolock, index = I_Subaccs_ID) on t.SubAcc_ID = s.ID
                                                                                         and isnull(@Loro, s.SubAccCode) = s.SubAccCode
               inner join QORT_DB_PROD..Firms so with (nolock, index = I_Firms_ID) on s.OwnerFirm_ID = so.ID
                                                                                      and patindex(@LegalEntity, so.BOCode) = 0
               inner join QORT_DB_PROD..Accounts ac with (nolock, index = I_Accounts_ID) on t.PutAccount_ID = ac.ID
                                                                                            and isnull(@TCA, ac.ExportCode) = ac.ExportCode
               inner join QORT_DB_PROD..Securities sec with (nolock, index = I_Securities_ID) on sec.id = t.Security_ID
               inner join QORT_DB_PROD..Assets i with (nolock, index = I_Assets_ID) on sec.Asset_ID = i.ID
               inner join QORT_DB_PROD..Assets c with (nolock, index = I_Assets_ID) on t.CurrPayAsset_ID = c.ID
               left join QORT_DB_PROD..Firms emit with (nolock, index = I_Firms_ID) on i.EmitentFirm_ID = emit.id
                left join QORT_DB_PROD..AssetCodes assc with (nolock) on i.id = assc.Asset_ID and assc.Name = 'Код НРД Aladdin'
              
			   where t.PutPlannedDate = @intDate
                     and not exists(select  1
                                      from  QORT_DB_PROD..AggregateTrades att with (nolock)
                                      where att.Trade_ID = t.id))
             insert into @Result
             select a.Depository
                  , a.Broker
                  , a.SettlementDate
                  , a.DepoClientID
                  , a.DepoAccount
                  , a.MarketName
                  , a.InstructionID
                  , a.Direction
                  , abs(a.SecQty)
                  , a.SecISIN
                  , a.SecRegCode
                  , a.SecShortName
                  , a.SecNSDCode
                  , abs(a.Amount)
                  , a.AmountCurrencyISO
/*, a.CP_ID as CP_BOCode*/
                  , f.BOCode as CP_BOCode
                  , fc.Code as  CP_NSDCode
                  , a.InstructionType
                  , a.ID
                  , convert(decimal(20,0),a.ExchageID)
                  , a.TradeDate
                  , a.InternalTradeRef
               from Aladdin_Instr a
               inner join QORT_DB_PROD..Firms f on f.ID = a.CP_ID
               inner join QORT_DB_PROD..FirmCodes fc on fc.Firm_ID = a.CP_ID
                                                        and fc.InfoSource like '%CPAM%'
    end
        return
    end
