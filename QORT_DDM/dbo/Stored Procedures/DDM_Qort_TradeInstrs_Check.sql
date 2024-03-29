/***********************
Author:   Vladimir Kruglov
Jira:     QORT-690, QORT-1004
Date:     2018-05-22
modified: 2019-05-17
***********************/
create   procedure dbo.DDM_Qort_TradeInstrs_Check
                          @DateFrom     datetime = null
                        , @DateTo       datetime = null
                        , @OnlyDiscr    bit      = 1
                        , @ErrDefine    bit      = 1
                        , @WithoutRENBR bit      = 1
as
     begin
        print 'START - '+convert(varchar , getdate() , 20)
        declare @FromDate int
              , @ToDate   int
        set @FromDate = coalesce(convert(int, format(@DateFrom, 'yyyyMMdd')), QORT_DDM.dbo.DDM_fn_AddBusinessDay(convert(int, format(getdate(), 'yyyyMMdd')), -2, 'Календарь_2010'));
        set @ToDate   = coalesce(convert(int, format(@DateTo  , 'yyyyMMdd')), QORT_DDM.dbo.DDM_fn_AddBusinessDay(convert(int, format(getdate(), 'yyyyMMdd')), -1, 'Календарь_2010'));
/***********************
 constructor tmp tables 
***********************/
           if object_id('tempdb..#tmpTradeInsr') is not null drop table #tmpTradeInsr
           create table #tmpTradeInsr (
                        Trade_ID  int
                      , Instr_ID  int
                      , ErrorCode varchar(1024) )
           if object_id('tempdb..#tmpErrorCodeTradeInsr') is not null drop table #tmpErrorCodeTradeInsr
           create table #tmpErrorCodeTradeInsr (
		                id int not null identity(1,1)
                      , ErrorCode          varchar(5)
                      , DefineErrorCodeRus varchar(1024)
                      , DefineErrorCodeEng varchar(1024) )
/***********************
 constructor tmp tables 
***********************/           
		insert into #tmpErrorCodeTradeInsr
               select 'MT_01', 'Сделка биржевая, ордер бумажный, номер поручения пустой', 'Market Trade: The paper order has not number'
        union  select 'MT_02', 'MX сделка может быть связана с MX поручением', 'The OTC MX_ trade could be matched with MX_ order'
        union  select 'OT_00', 'Сделка внебиржевая, поручение отсутствует', 'The OTC Trade without Order'
        union  select 'OT_01', 'Сделка внебиржевая, номер поручения пустой', 'The OTC Order has not number'
		union  select 'OT_02', 'Дата и время заключения сделки меньше даты и времени поручения', 'The Trade Initiation date and time is early than linked order one'
		union  select 'OT_03', 'Сделка отличается от поручения по инструменту, секции или направлению', 'The OTC Trade details has diff with linked Order by Security, Section or BuySell'
		union  select 'OT_04', 'Сделка отменена, ордер - действующий', 'The cancelled trade has non-canceled order'
		union  select 'OT_05', 'Сделка с подозрительным курсом оплаты', 'The trade with a suspicious cross rate'
		union  select 'OO_00', 'У поручения нет сделки', 'The Order without the Trade'
		union  select 'OO_01', 'o.qty = t.qty -> Статус поручения должен быть "Исполнено"', 'o.qty = t.qty -> The Order status need to be "Executed"'
		union  select 'OO_02', 'o.qty > t.qty -> Статус поручения должен быть "Частично Исполнено"', 'o.qty > t.qty -> The Order status need to be "Executing"'
		union  select 'OO_03', 'o.qty < t.qty -> Количество инструмента в поручении меньше количества во всех сделках', 'o.qty < t.qty -> The Qty of Order is not enough to execute all linked trades'
		union  select 'OO_04', 'Дата и время исполнения пустые', 'The datetime of the Order is empty'
		union  select 'OO_05', 'Дата и время исполнения меньше даты и времени заключения', 'The execution of trades look older than datetime of the Order'
		union  select 'OO_06', 'Поручение исполнено, дата и время исполнения в сделке другие', 'The Executed Order has different execution datetime with linked Trades'
		union  select 'OO_07', 'Поля поручения Автор, Тех.система, BONum должны быть заполнены', 'Fields AuthorFIO, AuthorPTS, BONum need to be filled'
		union  select 'OO_08', 'В реквизитах сделки ожидаем "Комиссию"', 'The trade details looks like Commission'
		union  select 'OO_09', 'В реквизитах сделки ожидаем "Поручение"', 'The trade details looks like Agreement'
		union  select 'OO_10', 'Поручение отказано, время снятия пустое', 'The Canceled Order without Cancel Time'
		union  select 'OO_11', 'Поручение отличается от сделки по цене', 'The Order has different price with the Trade'
/******
 Start 
******/
           print 'START [insert into #tmpTradeInsr] - '+convert(varchar , getdate() , 20)
/**********************************
 OT_00 : The trades without orders 
**********************************/
           insert into #tmpTradeInsr
                  select Trade_ID = t.id
                       , Instr_ID = null
                       , ErrorCode = iif(t.TradeInstr_ID = -1, 'OT_00,','')
                    from QORT_DB_PROD.dbo.Trades t with (nolock , index = PK_Trades)
                    inner join QORT_DB_PROD.dbo.TSSections tss with (nolock , index = PK_TSSections) on tss.id = t.TSSection_ID
                                                                                                        and tss.TS_ID = 6 --OTC	Внебиржевой рынок
                                                                                                        and tss.Enabled = 0
                    inner join QORT_DB_PROD.dbo.Subaccs sub with (nolock , index = I_Subaccs_ID) on sub.id = t.SubAcc_ID
                                                                                                    and (@WithoutRENBR = 0
                                                                                                         or (@WithoutRENBR = 1
                                                                                                             and sub.SubAccCode <> 'RENBR'))
                                                                                                    and sub.IsAnalytic = 'n'
                                                                                                    and sub.Enabled = 0
                   where 1 = 1
                         and t.TradeDate between @FromDate and @ToDate
                         and t.Enabled = 0 option(force order)
/************************************
 OT_01 : The Order without the Trade 
************************************/
           update #tmpTradeInsr
           set    Instr_ID = ti.id
                , ErrorCode = ErrorCode+iif(ti.RegisterNum = '' , 'OT_01,','')
             from #tmpTradeInsr tii
             inner join QORT_DB_PROD.dbo.Trades t with (nolock , index = I_Trades_ID) on t.id = tii.Trade_ID
                                                                                         and t.Enabled = 0
             inner join QORT_DB_PROD.dbo.TradeInstrs ti with (nolock , index = PK_TradeInstrs_NOINDEX) on ti.id = t.TradeInstr_ID
                                                                                                          and ti.Enabled = 0
            where 1 = 1 option(force order)
           print 'END [OT_01] - '+convert(varchar , getdate() , 20)
/***************************************
 MT_01 : The paper order has not number 
***************************************/
           insert into #tmpTradeInsr
                  select Trade_ID = t.id
                       , Instr_ID = ti.id
                       , ErrorCode = 'MT_01,'
                    from QORT_DB_PROD.dbo.TradeInstrs ti with (nolock , index = PK_TradeInstrs_NOINDEX)
                    inner join QORT_DB_PROD.dbo.Subaccs sub with (nolock , index = I_Subaccs_ID) on sub.id = ti.AuthorSubAcc_ID
                                                                                                    and (@WithoutRENBR = 0
                                                                                                         or (@WithoutRENBR = 1
                                                                                                             and sub.SubAccCode <> 'RENBR'))
                                                                                                    and sub.IsAnalytic = 'n'
                                                                                                    and sub.Enabled = 0
                    inner join QORT_DB_PROD.dbo.TSSections tss with (nolock , index = PK_TSSections) on tss.id = ti.Section_ID
                                                                                                        and tss.Enabled = 0
                    inner join QORT_DB_PROD.dbo.TSs ts1 with (nolock) on ts1.id = tss.TS_ID
                                                                         and ts1.IsMarket = 'y'
                    left join QORT_DB_PROD.dbo.Trades t with (nolock , index = I_Trades_TradeInstrID) on t.TradeInstr_ID = ti.id
                                                                                                         and t.Enabled = 0
                   where 1 = 1
                         and ti.Date between @FromDate and @ToDate
                         and ti.DM_Const = 3
                         and ti.Enabled = 0
                         and ti.RegisterNum = '' option(force order)
           print 'END [MT_01] - '+convert(varchar , getdate() , 20)
/****************************************
 OO_00 : All manual Orders without trades
****************************************/
           insert into #tmpTradeInsr
                  select Trade_ID = null
                       , Instr_ID = ti.id
                       , ErrorCode = case
                                          when ti.IS_Const < 6 then 'OO_00,'
                                          else ''
                                     end
                    from QORT_DB_PROD.dbo.TradeInstrs ti with (nolock , index = PK_TradeInstrs_NOINDEX)
                   where 1 = 1
                         and ti.date between @FromDate and @ToDate
                         and ti.Enabled = 0
                         and not exists(select 1
                                          from QORT_DB_PROD.dbo.Trades t with (nolock , index = I_Trades_TradeInstrID)
                                         where 1 = 1
                                               and t.TradeInstr_ID = ti.id
                                               and t.Enabled = 0)
           print 'END [OO_00] - '+convert(varchar , getdate() , 20)
           print 'END [insert into #tmpTradeInsr] - '+convert(varchar , getdate() , 20)
/**************************************************************************
 OT_02 : The Trade Initiation date and time is early than linked order one 
**************************************************************************/
           update #tmpTradeInsr
           set    ErrorCode = tti.ErrorCode+'OT_02,'
             from #tmpTradeInsr tti
             inner join QORT_DB_PROD.dbo.TradeInstrs ti with (nolock) on ti.id = tti.Instr_ID
             inner join QORT_DB_PROD.dbo.Trades t with (nolock , index = I_Trades_ID) on ti.id = tti.Trade_ID
            where 1 = 1
                  and CONCAT(str(t.TradeDate) , str(t.TradeTime)) < CONCAT(str(ti.Date) , str(ti.Time))
           print 'END [OT_02] - '+convert(varchar , getdate() , 20)
/*****************************************************************************************
 OT_03 : The OTC Trade details has diff with linked Order by Security, Section or BuySell 
*****************************************************************************************/
           update #tmpTradeInsr
           set    ErrorCode = tti.ErrorCode+'OT_03,'
             from #tmpTradeInsr tti
             inner join QORT_DB_PROD.dbo.TradeInstrs ti with (nolock) on ti.id = tti.Instr_ID
             inner join QORT_DB_PROD.dbo.Trades t with (nolock , index = I_Trades_ID) on t.id = tti.Trade_ID
                                                                                         and t.IsRepo2 = 'n'
             left join QORT_DB_PROD.dbo.Securities s0 with (nolock) on s0.id = ti.Security_ID
             left join QORT_DB_PROD.dbo.Assets a0 with (nolock) on a0.id = s0.Asset_ID
             left join QORT_DB_PROD.dbo.Securities s1 with (nolock) on s1.id = t.Security_ID
             left join QORT_DB_PROD.dbo.Assets a1 with (nolock) on a1.id = s1.Asset_ID
            where 1 = 1
                  and (ti.Section_ID <> t.TSSection_ID
                       or ((case
                                 when ti.[Type] in(7 , 8) then(ti.[Type] - 6)
                                 when ti.[Type] in(9 , 10) then(11 - ti.[Type])
                                 else t.BuySell
                            end) <> t.BuySell)
                       or s0.Asset_ID <> s1.Asset_ID)
           print 'END [OT_03] - '+convert(varchar , getdate() , 20)
/***************************************************
 OT_04 : The cancelled trade has non-canceled order 
***************************************************/
           update #tmpTradeInsr
           set    ErrorCode = tti.ErrorCode+'OT_04,'
             from #tmpTradeInsr tti
             inner join QORT_DB_PROD.dbo.TradeInstrs ti with (nolock) on ti.id = tti.Instr_ID
             inner join QORT_DB_PROD.dbo.Trades t with (nolock , index = I_Trades_ID) on t.id = tti.Trade_ID
            where 1 = 1
                  and (t.NullStatus = 'y'
                       and ti.IS_Const < 6)
           print 'END [OT_04] - '+convert(varchar , getdate() , 20)
/***********************************************
 OT_05 : The trade with a suspicious cross rate
***********************************************/
           update #tmpTradeInsr
           set    ErrorCode = tti.ErrorCode+'OT_05,'
             from #tmpTradeInsr tti
             inner join QORT_DB_PROD.dbo.Trades t with (nolock , index = I_Trades_ID) on t.id = tti.Trade_ID
			 inner join QORT_DB_PROD.dbo.TSSections tss with (nolock) on tss.id = t.TSSection_ID
			 inner join QORT_DB_PROD.dbo.TSs ts1 with (nolock) on ts1.id = tss.TS_ID and ts1.IsMarket = 'n'
            where 1 = 1
			      and t.NullStatus = 'n'
                  and t.CurrPriceAsset_ID <> t.CurrPayAsset_ID
                  and 0.2 < abs(1 - (t.CrossRate / coalesce((select  1 / (max((cr.Bid + cr.Ask)/cr.Qty) / 2)
                                                     from  QORT_DB_PROD.dbo.CrossRatesHist cr with (nolock, index=PK_CrossRatesHist)
                                                     where 1 = 1
                                                           and cr.PriceAsset_ID = t.CurrPriceAsset_ID
                                                           and cr.TradeAsset_ID = t.CurrPayAsset_ID
                                                           and cr.OldDate = t.TradeDate)
												, (select  max((cr.Bid + cr.Ask)/cr.Qty) / 2
                                                     from  QORT_DB_PROD.dbo.CrossRatesHist cr with (nolock, index=PK_CrossRatesHist)
                                                     where 1 = 1
                                                           and cr.TradeAsset_ID = t.CurrPriceAsset_ID
                                                           and cr.PriceAsset_ID = t.CurrPayAsset_ID
                                                           and cr.OldDate = t.TradeDate)
											    , (select  max((cr.Bid + cr.Ask)/cr.Qty) / 2
                                                     from  QORT_DB_PROD.dbo.CrossRatesHist cr with (nolock, index=PK_CrossRatesHist)
                                                     where 1 = 1
                                                           and cr.TradeAsset_ID = t.CurrPriceAsset_ID
                                                           and cr.PriceAsset_ID = 71273 /* RUR */
                                                           and cr.OldDate = t.TradeDate) 
												/ (select  max((cr.Bid + cr.Ask)/cr.Qty) / 2
                                                     from  QORT_DB_PROD.dbo.CrossRatesHist cr with (nolock, index=PK_CrossRatesHist)
                                                     where 1 = 1
                                                           and cr.TradeAsset_ID = t.CurrPayAsset_ID
                                                           and cr.PriceAsset_ID = 71273 /* RUR */
                                                           and cr.OldDate = t.TradeDate)
											   , t.CrossRate / 2) -- also marked as break when any of the currencies is not defined in CrossRate table
								))
           print 'END [OT_05] - '+convert(varchar , getdate() , 20)
/****************************************************************
 OO_01 : o.qty = t.qty -> The Order status need to be "Executed" 
****************************************************************/
/*****************************************************************
 OO_02 : o.qty > t.qty -> The Order status need to be "Executing" 
*****************************************************************/
/*************************************************************************************
 OO_03 : o.qty < t.qty -> The Qty of Order is not enough to execute all linked trades 
*************************************************************************************/
           update              #tmpTradeInsr
           set                 ErrorCode = tti.ErrorCode + tt0.ErrorCode
             from              #tmpTradeInsr tti
             inner join(select tti.Instr_ID
                             , ErrorCode = iif(ti.IS_Const <= 4 and (round(sum(t.Qty) over(partition by ti.id) , 2) = round(ti.Qty , 2)), 'OO_01,','')
                                         + iif(ti.IS_Const  = 5 and (round(sum(t.Qty) over(partition by ti.id) , 2) < round(ti.Qty , 2)), 'OO_02,','')
                                         + iif(round(sum(t.Qty) over(partition by ti.id) , 2) > round(ti.Qty , 2)                       , 'OO_03,','')
                          from #tmpTradeInsr tti
                          inner join QORT_DB_PROD.dbo.Trades t with (nolock , index = I_Trades_ID) on t.id = tti.Trade_ID
                          inner join QORT_DB_PROD.dbo.TradeInstrs ti with (nolock) on t.TradeInstr_ID = ti.id
                          inner join QORT_DB_PROD.dbo.TSSections tss with (nolock) on t.TSSection_ID = tss.id
                                                                                      and tss.TT_Const not in(3 , 6) -- для 'РЕПО' пока ищем способ считать  
                         where 1 = 1
                               and ti.IS_Const <= 5
                               and (case
                                         when ti.[Type] in(7 , 8)  then  6 + t.BuySell
										 when ti.[Type] in(9 , 10) then 11 - t.BuySell
                                         else ti.[Type]
                                    end) = ti.[Type]
                               and t.IsRepo2 = 'n') as tt0 on tt0.Instr_ID = tti.Instr_ID
           print 'END [O0_01 - OO_03] - '+convert(varchar , getdate() , 20)
/*******************************************
 OO_04 : The datetime of the Order is empty 
*******************************************/
           update #tmpTradeInsr
           set    ErrorCode = tti.ErrorCode+'OO_04,'
             from #tmpTradeInsr tti
             inner join QORT_DB_PROD.dbo.TradeInstrs ti with (nolock) on tti.Instr_ID = ti.id
                                                                         and ti.IS_Const = 5
                                                                         and (ti.FinishDate = 0
                                                                              or ti.FinishTime = 0)
           print 'END [OO_04] - '+convert(varchar , getdate() , 20)
/**********************************************************************
 OO_05 : The execution of trades look older than datetime of the Order 
**********************************************************************/
           update #tmpTradeInsr
           set    ErrorCode = tti.ErrorCode+'OO_05,'
             from #tmpTradeInsr tti
             inner join QORT_DB_PROD.dbo.TradeInstrs ti with (nolock) on tti.Instr_ID = ti.id
            where 1 = 1
                  and ti.IS_Const <= 5
                  and not(isnull(ti.FinishDate , 0) = 0
                          or isnull(ti.FinishTime , 0) = 0)
                  and left(ltrim(str(ti.FinishDate))+ltrim(replace(str(ti.FinishTime , 9) , ' ' , '0')) , 14) < left(ltrim(str(ti.Date))+ltrim(replace(str(ti.Time , 9) , ' ' , '0')) , 14)
           print 'END [OO_05] - '+convert(varchar , getdate() , 20)
/*******************************************************************************
 OO_06 : The Executed Order has different execution datetime with linked Trades 
*******************************************************************************/
           update #tmpTradeInsr
           set    ErrorCode = tti.ErrorCode+'OO_06,'
             from #tmpTradeInsr tti
             inner join QORT_DB_PROD.dbo.TradeInstrs ti with (nolock) on tti.Instr_ID = ti.id
                                                                         and ti.IS_Const = 5
                                                                         and not(ti.FinishDate = 0
                                                                                 or ti.FinishTime = 0)
             inner join(select t.TradeInstr_ID
                             , tDateTime = max(ltrim(str(t.TradeDate))+ltrim(replace(str(t.TradeTime , 9) , ' ' , '0')))
                          from #tmpTradeInsr tti
                          inner join QORT_DB_PROD.dbo.Trades t with (nolock , index = I_Trades_ID) on t.id = tti.Trade_ID
                         group by t.TradeInstr_ID) as t on t.TradeInstr_ID = ti.id
            where 1 = 1
                  and left(ltrim(str(ti.FinishDate))+ltrim(replace(str(ti.FinishTime , 9) , ' ' , '0')) , 14) <> left(t.tDateTime , 14)
           print 'END [OO_06] - '+convert(varchar , getdate() , 20)
/*************************************************************
 OO_07 : Fields AuthorFIO, AuthorPTS, BONum need to be filled 
*************************************************************/
           update #tmpTradeInsr
           set    ErrorCode = tti.ErrorCode+'OO_07,'
             from #tmpTradeInsr tti
             inner join QORT_DB_PROD.dbo.TradeInstrs ti with (nolock) on tti.Instr_ID = ti.id
            where nullif(ti.AuthorFIO , '') is null
                  or nullif(ti.AuthorPTS , '') is null
                  or nullif(ti.BONum , '') is null
           print 'END [OO_07] - '+convert(varchar , getdate() , 20)
/************************************************
 OO_08 : The trade details looks like Commission 
************************************************/
           update #tmpTradeInsr
           set    ErrorCode = tti.ErrorCode+'OO_08,'
             from #tmpTradeInsr tti
             inner join QORT_DB_PROD.dbo.Trades t with (nolock , index = I_Trades_ID) on t.id = tti.Trade_ID
             inner join QORT_DB_PROD.dbo.TradeInstrs ti with (nolock) on ti.id = tti.Instr_ID
            where 1 = 1
                  and ti.IsAgent = 'y'
                  and QFlags&131072 <> 0
           print 'END [OO_08] - '+convert(varchar , getdate() , 20)
/***********************************************
 OO_09 : The trade details looks like Agreement 
***********************************************/
           update #tmpTradeInsr
           set    ErrorCode = tti.ErrorCode+'OO_09,'
             from #tmpTradeInsr tti
             inner join QORT_DB_PROD.dbo.Trades t with (nolock , index = I_Trades_ID) on t.id = tti.Trade_ID
             inner join QORT_DB_PROD.dbo.TradeInstrs ti with (nolock) on ti.id = tti.Instr_ID
            where 1 = 1
                  and ti.IsAgent = 'n'
                  and QFlags&131072 <> 131072
           print 'END [OO_09] - '+convert(varchar , getdate() , 20)
/***********************************************
 OO_10 : The Canceled Order without Cancel Time 
***********************************************/
           update #tmpTradeInsr
           set    ErrorCode = tti.ErrorCode+'OO_10,'
             from #tmpTradeInsr tti
             inner join QORT_DB_PROD.dbo.TradeInstrs ti with (nolock) on ti.id = tti.Instr_ID
            where 1 = 1
                  and ti.IS_Const > 5
                  and isnull(ti.WithdrawTime , 0) = 0
           print 'END [OO_10] - '+convert(varchar , getdate() , 20)
/***********************************************
 OO_11 : The Order has different price with the Trade 
***********************************************/
			update #tmpTradeInsr
			set ErrorCode = tti.ErrorCode + 'OO_11,'
			  from #tmpTradeInsr tti
			  inner join QORT_DB_PROD.dbo.TradeInstrs ti with(nolock) on ti.id = tti.Instr_ID and ti.Price <> 0
			  inner join QORT_DB_PROD.dbo.Trades t with(nolock) on t.id = tti.Trade_ID
			 where 1 = 1
				   and iif(ti.Type = 7 and t.CurrPriceAsset_ID = ti.CurrencyAsset_ID and round(ti.Price,10) < round(t.Price,10), 1, 0)
				     + iif(ti.Type = 8 and t.CurrPriceAsset_ID = ti.CurrencyAsset_ID and round(ti.Price,10) > round(t.Price,10), 1, 0) > 0
			print 'END [OO_11] - ' + convert(varchar, getdate(), 20)
/************************************************
 MT_02 : look for MX Orders matched to MX trades 
************************************************/
           update #tmpTradeInsr
           set    Trade_ID = t.id
                , ErrorCode = tti.ErrorCode+'MT_02,'
             from #tmpTradeInsr tti
             inner join QORT_DB_PROD.dbo.TradeInstrs ti with (nolock) on ti.id = tti.Instr_ID
                                                                         and ti.Enabled = 0
                                                                         and ti.IsOrder = 'n'
                                                                         and len(ti.RegisterNum) > 5
																		 and ti.IS_Const < 6
             inner join QORT_DB_PROD.dbo.Trades t with (nolock , index = I_Trades_SubAccID_TradeDate_BONum) on t.TradeDate = ti.[Date]
                                                                                                               and t.SubAcc_ID = ti.AuthorSubAcc_ID
                                                                                                               and t.Enabled = 0
																											   and t.NullStatus = 'n'
                                                                                                               and convert(varchar(10) , ti.RegisterNum collate Cyrillic_General_CS_AS) in(convert(varchar(10) , t.AgreeNum collate Cyrillic_General_CS_AS) , convert(varchar(10) , t.Comment collate Cyrillic_General_CS_AS))
            where tti.Trade_ID is null option(force order)
           print 'END [MT_02] - '+convert(varchar , getdate() , 20)
           if @ErrDefine = 1
                 begin -- define error codes
                       declare @i0 int
                             , @i1 int
                       select @i0 = min(id)
                            , @i1 = max(id)
                         from #tmpErrorCodeTradeInsr
                       while @i0 <= @i1
                             begin
                                   update #tmpTradeInsr
                                   set    ErrorCode = replace(#tmpTradeInsr.ErrorCode , tect.ErrorCode , concat('(' , tect.ErrorCode , ' - ' , tect.DefineErrorCodeRus , ')'))
                                     from #tmpErrorCodeTradeInsr tect
                                    where 1 = 1
                                          and tect.id = @i0
                                   select @i0 = @i0 + 1
                             end
                 end
/********************
 create result table 
********************/
           select [Номер сделки] = ltrim(str(t.TradeNum , 32))
                , [Номер договора] = t.AgreeNum
                , [Дата сделки] = stuff(stuff(t.TradeDate , 7 , 0 , '-') , 5 , 0 , '-')
                , [Время сделки] = ltrim(stuff(stuff(stuff(str(t.TradeTime , 9) , 7 , 0 , '.') , 5 , 0 , ':') , 3 , 0 , ':'))
                , [Секция] = tss.Name
                , [Субсчет] = sub.SubAccCode
                , [Отменена] = case t.NullStatus
                                    when 'n' then 'нет'
                                    when 'y' then 'да'
                               end
                , [Номер поручения] = ti.RegisterNum
                , [Дата поручения] = stuff(stuff(ti.Date , 7 , 0 , '-') , 5 , 0 , '-')
                , [Время поручения] = ltrim(stuff(stuff(stuff(str(ti.Time , 9) , 7 , 0 , '.') , 5 , 0 , ':') , 3 , 0 , ':'))
                , [Статус поручения] = choose(ti.IS_Const,'Новое','В исполнении','undefined','Частично исполнено','Исполнено','Отказ','Отклонена','Отклонена','Снята')
                , [Ошибки] = tti.ErrorCode
             from #tmpTradeInsr tti
             left join QORT_DB_PROD.dbo.Trades t with (nolock , index = I_Trades_ID) on t.id = tti.Trade_ID
             left join QORT_DB_PROD.dbo.TradeInstrs ti with (nolock) on ti.id = tti.Instr_ID
             left join QORT_DB_PROD.dbo.TSSections tss with (nolock) on tss.id = t.TSSection_ID
             left join QORT_DB_PROD.dbo.Subaccs sub with (nolock) on sub.id = t.SubAcc_ID
            where 1 = 1
                  and ((@OnlyDiscr = 1
                        and tti.ErrorCode <> '')
                       or @OnlyDiscr = 0)
           order by isnull(sign(isnull(tti.Trade_ID , -1))*tti.Instr_ID/len(tti.ErrorCode+'.') , 99999)
/**********************
 destructor tmp tables 
**********************/
           if object_id('tempdb..#tmpErrorCodeTradeInsr') is not null drop table #tmpErrorCodeTradeInsr
           if object_id('tempdb..#tmpTradeInsr') is not null drop table #tmpTradeInsr
     end;
