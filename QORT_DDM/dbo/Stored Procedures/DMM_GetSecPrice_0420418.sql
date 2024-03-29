CREATE procedure [dbo].[DMM_GetSecPrice_0420418]
                                   @Date datetime,
	                               @ZeroLevel float = 0.001 /* Значение позиции, которое можно считать нулём */
as
begin
	select @ZeroLevel = isnull(@ZeroLevel , 0.001)
		DECLARE @DateReport as int;
		DECLARE @CurrentOperDate as int;
		DECLARE @RUB_ID as int;
		DECLARE @AID as int;
		DECLARE @ZeroLevelCASH as float;
		
IF OBJECT_ID(N'tempdb..#BrokerageAgreeTypesId', N'U') IS NOT NULL   
DROP TABLE #BrokerageAgreeTypesId
create table #BrokerageAgreeTypesId (typeId float);

IF OBJECT_ID(N'tempdb..#RL', N'U') IS NOT NULL   
DROP TABLE #RL
create table #RL (/* Расшифровка уровней риска */
						   RiskLevel float, 
	                       RiskDescription [varchar](20));

IF OBJECT_ID(N'tempdb..#CBRates', N'U') IS NOT NULL   
DROP TABLE #CBRates
create table #CBRates (/* Курсы ЦБ РФ на дату отчета для пересчета цен в рубли */
							    RateCurrency_ID float, 
	                            Rate float,
							    Qty int,
							    Currency [varchar](48));
								
IF OBJECT_ID(N'tempdb..#ClientAgrees', N'U') IS NOT NULL   
DROP TABLE #ClientAgrees
create table #ClientAgrees (AgreeId float,
				                     AgreeNum [varchar] (64),
									 SubAccID float,
									 DateCreate int,
									 addByAnalyticFather char(1),
									 isActive int);

IF OBJECT_ID(N'tempdb..#Position', N'U') IS NOT NULL   
DROP TABLE #Position
create table #Position (/* Позиция на дату отчета */
								 id float,
								 Asset_ID float,
								 SubAccCode [VARCHAR] (32),
								 SubaccName [VARCHAR] (150),
								 BOCode [VARCHAR] (32),
								 AgreeNum [VARCHAR] (64),
								 AgreeDate [VARCHAR] (10),
								 AgreeId float,
								 AgreeIndex [varchar] (250),
								 RiskLevel [VARCHAR] (20),
								 Account [VARCHAR] (100),
								 VolFreeStart float,
								 VolFree float,
								 VolBlocked float,
								 VolRest float,
								 VolForward float,
								 VolItogo float,
								 OwnerShortName [VARCHAR] (150),
								 isResident [CHAR] (1),
								 CountryISO [VARCHAR] (32),
								 OKATO [VARCHAR] (32),
								 FirmId float,
								 isOwnerActive [CHAR] (1),
								 isFirm [CHAR] (1),
								 IsQualInvest [CHAR] (1),
								 Subacc_ID float);

IF OBJECT_ID(N'tempdb..#AssetsActual', N'U') IS NOT NULL   
DROP TABLE #AssetsActual
create table #AssetsActual (/* Бумаги, засветившиеся на позиции, на дату отчета */
								     id float,
								     ShortName [varchar](48),
									 MoexTicker [VARCHAR] (64),
								     Name [varchar](128),
								     ISIN [varchar](16),
									 RegistrationCode [varchar](32),
								     BaseValue float,
								     BaseCurrencyAsset_ID float,
								     BaseAssetSize float,
								     EmitDate int,
								     AssetCurrency [varchar](3),
									 AssetType [varchar](10),
									 Enabled float);

		IF OBJECT_ID('tempdb..#tmpSecPrice0420418') IS NOT NULL
		   drop table #tmpSecPrice0420418;

			create table #tmpSecPrice0420418 (
            /*A*/    tmpRank  float, /* Для нумерации*/
			/*B*/	 Account [VARCHAR] (100),  /* Счёт */
			/*C*/	 SubaccCode [VARCHAR] (32), /* Код субсчёта */
			/*D*/	 BOCode [VARCHAR] (32), /* Код Да Винчи */
			/*E*/	 AgreeNum [VARCHAR] (64), /* Договор */
			/*F*/	 AssetType [VARCHAR] (10), /* Tип актива (деньги/бумаги) */
			/*G*/	 AssetName [VARCHAR] (128), /* Наименование актива */
			/*H*/	 ISIN [varchar](16), /* ISIN бумаги */
			/*I*/	 ShortName [varchar](48), /* Код бумаги */
			/*J*/    MoexTicker [VARCHAR] (64), /* Тикер бумаги на ММВБ */
			/*K*/	 BaseValue float, /* Непогаш. номинал */
			/*L*/	 AssetCurrency [VARCHAR] (3), /* Валюта номинала */
			/*M*/	 VolFreeStart float, /* Вход. */
			/*N*/	 VolFree float, /* Свободно */
			/*O*/	 VolBlocked float, /* Блокировано */
			/*P*/	 VolRest float, /* Остаток */
			/*Q*/	 VolForward float, /* Форвард */
			/*R*/	 VolItogo float, /* Итого */
			/*S*/	 OwnerShortName [VARCHAR] (150), /* Наименование/ ФИО */
			/*T*/	 IsFirm [CHAR] (1), /* Юридическое лицо? */
			/*U*/	 isResident [CHAR] (1), /* Резидент РФ? */
			/*V*/	 OKATO [VARCHAR] (10), /* OKATO/ ISO-код страны */
			/*W*/	 IsQualInvest [CHAR] (1), /*Квалифицированный инвестор? */
			/*X*/	 IsOwnerActive [CHAR] (1), /* Активный клиент? */
			/*Y*/	 RiskLevel [VARCHAR] (20), /* Категория риска */
			/*Z*/	 tmpStrNum  [VARCHAR] (250), /* Временная переменная для макроса Excel */
			/*AA*/	 tmpPrice3Type [VARCHAR] (250), /* Временная переменная для макроса Excel */ /* Тип Цены 3*/
			/*AB*/	 tmpPrice3 [VARCHAR] (250), /* Временная переменная для макроса Excel */ /* Цена 3 */
			/*AC*/	 tmpPrice3Curr [VARCHAR] (250), /* Временная переменная для макроса Excel */ /* Валюта Цены 3 */	
			/*AD*/	 tmpPrice3InRub [VARCHAR] (250), /* Временная переменная для макроса Excel */ /* Цена 3 */
			/*AE*/	 PriceDeal float, /* Цена из сделки */
			/*AF*/	 PriceDealCurrency [VARCHAR] (3), /* Валюта Цены из сделки */
			/*AG*/	 Rate float, /* Курс */
			/*AH*/	 PriceDealInRUB float, /* Цена из сделки, в руб. */
			/*AI*/	 TradeNum float, /* Номер сделки */
			/*AJ*/   TradeId float, /* Id сделки в QORT */
			/*AK*/	 TradeDate [VARCHAR] (10), /* Дата сделки */ 
			/*AL*/	 TradeTime [VARCHAR] (15), /*Время сделки */
			/*AM*/	 TradeTimeMCS smallint, /* мксек сделки*/
			/*AN*/	 tmpPriceInRub [VARCHAR] (250), /* Временная переменная для макроса Excel */ /* Цена в руб.*/
			/*AO*/   tmpFreeInRub [VARCHAR] (250), /* Временная переменная для макроса Excel */ /* Свободно в руб.*/
			/*AP*/	 tmpForwardSummaryInRub [VARCHAR] (250), /* Временная переменная для макроса Excel */ /* Форвард + Блокировано в руб.*/
			/*AQ*/	 tmpSummaryInRub [VARCHAR] (250), /* Временная переменная для макроса Excel */ /* Свободно + Форвард + Блокировано в руб.*/
			/*AR*/	 AgreeId [VARCHAR] (250), /* Номер и Дата договора */
			/*AS*/	 AgrBalance [VARCHAR] (250), /* Временная переменная для макроса Excel */ /* Cумма (Свободно + Форвард + Блокировано в руб.) в разрезе договора */
			/*AT*/   Sign [VARCHAR] (250), /* Временная переменная для макроса Excel */ /* Знак суммы (Свободно + Форвард + Блокировано в руб.) в разрезе договора */
			/*AU*/	 AgrFreeBalanceSec [VARCHAR] (250), /* Временная переменная для макроса Excel */ /* Cумма по бумагам Свободно в руб. в разрезе договора */
			/*AV*/	 AgrFreeBalanceCASH [VARCHAR] (250), /* Временная переменная для макроса Excel */ /* Cумма по деньгам Свободно в руб. в разрезе договора */
			/*AW*/	 AgrForwardBalanceSec [VARCHAR] (250), /* Временная переменная для макроса Excel */ /* Cумма по бумагам (Форвард + Блокировано в руб.) в разрезе договора */
			/*AX*/	 AgrForwardBalanceCASH [VARCHAR] (250), /* Временная переменная для макроса Excel */ /* Cумма по деньгам (Форвард + Блокировано в руб.) в разрезе договора */
			/*AY*/   Frequency [VARCHAR] (250), /* Частота OwnerShortName */
			/*AZ*/   Counts [VARCHAR] (250), /* Временная переменная для макроса Excel */ /* Количество OwnerShortName в разрезе свойств */
			         SecNum int, /* Количество бумаг */
					 Asset_ID float, /* Связь с активом */
					 RegistrationCode [VARCHAR](32) /* Код гос.регистрации актива */
        )

		IF OBJECT_ID('tempdb..#DealPrice') IS NOT NULL
			drop table #DealPrice;

		IF OBJECT_ID('tempdb..#TMPDealPrice') IS NOT NULL
			drop table #TMPDealPrice;

		IF OBJECT_ID('tempdb..#TMP_MAXDATETIMEMCS') IS NOT NULL
			drop table #TMP_MAXDATETIMEMCS;

		set @DateReport = convert(int, format(@Date, 'yyyyMMdd'));
		set @ZeroLevelCASH = 5e-4;

		select @CurrentOperDate = max(od.Day)
				 from QORT_DB_PROD..OperationDays od with(nolock);

        set @RUB_ID = (select min(id) from QORT_DB_PROD..Assets with (nolock) where ShortName = 'RUR' and Enabled = 0);

		insert into #CBRates values (@RUB_ID, 1.0, 1, 'RUR');

		insert into #CBRates values 
		((select min (id) from QORT_DB_PROD..Assets with (nolock) where ShortName = 'RUB' and Enabled = 0), 1.0, 1, 'RUB') ;

		insert into #RL Values (1, 'Не задан'), (2, 'Стандартный'), 
							   (3, 'Особый'), (4, 'Повышенный');

		insert into #BrokerageAgreeTypesId
			select id from QORT_DB_PROD..ClientAgreeTypes with (nolock) where ShortName in ('DBJR', 'DBFR', 'DBFRD');

		/*CALCULATE RATES AND POSITION */
		begin

IF OBJECT_ID(N'tempdb..#Key', N'U') IS NOT NULL   
DROP TABLE #Key 
create table #Key (Asset_ID   float, 
		                    Account    [VARCHAR] (100),
							BOCode [VARCHAR] (32),
							AgreeId float);

		if (@DateReport < @CurrentOperDate)
			begin		   
				insert into  #ClientAgrees
					select Founder_ID,
						   Num as AgreeNum,
						   SubAcc_ID as SubAccID,
						   DateCreate,
						   '',
						   iif (Enabled = 0 and
						   (DateEnd is null or DateEnd = 0 or DateEnd > @DateReport) and
						   (DateCreate is null or DateCreate <= @DateReport), 1, 0)
					from QORT_DB_PROD..ClientAgreesHist	Hist with (nolock, index = I_ClientAgreesHist_FounderDate)
					where  Founder_Date <= @DateReport and
						   (DateEnd is null or DateEnd = 0 or DateEnd > @DateReport) and
						   (DateCreate is null or DateCreate <= @DateReport) and					   
					       exists (select top 1 * from #BrokerageAgreeTypesId where typeid = ClientAgreeType_ID) and 					       
						   not exists (select top 1 * from QORT_DB_PROD..ClientAgreesHist with (nolock, index = I_ClientAgreesHist_FounderID)
						               where Founder_ID = Hist.Founder_ID AND
									         Founder_Date <= @DateReport AND
									         (Founder_Date > Hist.Founder_Date OR
											  Founder_Date = Hist.Founder_Date AND Founder_Time > Hist.Founder_Time OR
											  Founder_Date = Hist.Founder_Date AND Founder_Time = Hist.Founder_Time AND ID > Hist.ID
											 )
									    );

                delete from #ClientAgrees where isActive = 0; 

				delete from #ClientAgrees where exists (select top 1 * from QORT_DB_PROD..ClientAgrees C  with (nolock, index = PK_ClientAgrees_NOINDEX)
				                                                       where id = AgreeId and (Enabled <> 0 OR DateEnd <= @DateReport or DateCreate > @DateReport));

				insert into #ClientAgrees 
					select id as AgreeId,
						   Num as AgreeNum,
						   SubAcc_ID as SubAccID,
						   DateCreate,
						   '',
						   1
					from QORT_DB_PROD..ClientAgrees with (nolock, index = PK_ClientAgrees_NOINDEX)
					where Enabled = 0 and 
						  (DateEnd is null or DateEnd = 0 or DateEnd > @DateReport) and
						  (DateCreate is null or DateCreate <= @DateReport) and
					      exists (select top 1 * from #BrokerageAgreeTypesId where typeid = ClientAgreeType_ID) and
						  not exists (select top 1 * from #ClientAgrees where AgreeId = ClientAgrees.id);	

				insert into #ClientAgrees 
					select AgreeId,
						   AgreeNum,
						   Child_ID as SubAccID,
						   DateCreate,
						   IsAnalytic,
						   1
					from #ClientAgrees C
					inner join QORT_DB_PROD..SubaccStructure with (nolock, index = PK_SubaccStructure)
					ON C.SubAccID = Father_ID and 
					   Child_ID <> Father_ID and
					   Enabled = 0 and
					   not exists (select top 1 * from #ClientAgrees where SubAccID = Child_ID)
					inner join QORT_DB_PROD..Subaccs with (nolock, index = I_Subaccs_ID)
					ON Father_ID = Subaccs.id and Subaccs.Enabled = 0;
						  							
				insert into #CBRates
					select TradeAsset_ID as RateCurrency_ID, 
						   Ask as Rate,
						   Qty,
						   ShortName as Currency
					from QORT_DB_PROD..Assets with (nolock, index = I_Assets_ID)
					inner join QORT_DB_PROD..CrossRatesHist with (nolock, index = PK_CrossRatesHist)
					ON InfoSource = 'MainCurBank' and 
	  				   OldDate = @DateReport and
 	                   TradeAsset_ID = Assets.id and
					   Enabled = 0;

			insert into #Position
				select PositionHist.id,
					   Asset_ID,
					   SubAccCode,
					   SubaccName,
					   Firms.BOCode,
					   AgreeNum,
					   cast (DateCreate as varchar) as AgreeDate,
					   AgreeId,
					   NULL,
					   RiskDescription as RiskLevel,
					   Accounts.Name as Account,
					   VolFreeStart,
					   VolFree,
					   VolBlocked,
					   VolForward+VolFree as VolRest,
					   VolForward,
					   VolForward+VolBlocked as VolItogo,
					   Firms.FirmShortName as OwnerShortName,
					   isResident,
					   Countries.CodeISO as CountryISO,
					   OKATO,
					   Firms.Id as FirmId,
					   'n',
					   isFirm,
					   Firms.IsQualified as IsQualInvest,
					   Subacc_ID				
				from QORT_DB_PROD..PositionHist with (nolock,index = PK_PositionHist)
				inner join QORT_DB_PROD..Accounts with (nolock,index = I_Accounts_ID)
				ON Accounts.id = Account_ID and Accounts.Enabled = 0
				inner join QORT_DB_PROD..Subaccs with (nolock,index = I_Subaccs_ID)
				ON Subacc_ID = Subaccs.id and Subaccs.Enabled = 0
				inner join QORT_DB_PROD..Firms with (nolock, index = I_Firms_ID)
				ON Firms.id = Subaccs.OwnerFirm_ID and Firms.Enabled = 0
				left join QORT_DB_PROD..Countries with (nolock, index = I_Countries_ID)
				ON Country_ID = Countries.Id
				inner join  #ClientAgrees
				ON Subaccs.id = SubAccID
				left join #RL Levels			
				ON 	Levels.RiskLevel = Firms.RiskLevel
				where OldDate = @DateReport and			   
				      (abs (VolFree) >= @ZeroLevel OR abs (VolForward) >= @ZeroLevel OR abs(VolBlocked) >= @ZeroLevel) and
					  Accounts.Name not like '%_WSH_%' and /* Исключаем тех.счета */
					  Accounts.Name not like '%_NON_%' and /* Исключаем тех.счета */
					  Accounts.Name not like 'RENBR_CCA_%' and /* Исключаем тех.счета */
					  Accounts.Name not like 'NonBroker%' and 
					  Accounts.Name not like 'NonDefined%' and
					  Accounts.Name not like 'RENBR_%_RENBR%' and
					  not (Firms.IsOurs = 'y' and Firms.STAT_Const = 5 and Firms.IsHeadBrok = 'y'); /* Исключаем субсчета, владельцем которых является ООО "Ренессанс Брокер" */
			end
		else
			begin 
				insert into  #ClientAgrees 
					select id as AgreeId,
						   Num as AgreeNum,
						   SubAcc_ID as SubAccID,
						   DateCreate,
						   '',
						   1
					from QORT_DB_PROD..ClientAgrees with (nolock)
					where ClientAgreeType_ID in (select typeid from #BrokerageAgreeTypesId) and 
					      Enabled = 0 and 
						  (DateEnd is null or DateEnd = 0 or DateEnd > @DateReport) and
						  (DateCreate is null or DateCreate <= @DateReport) and
						  id not in (select AgreeId from #ClientAgrees);	

				insert into #ClientAgrees 
					select AgreeId,
						   AgreeNum,
						   Child_ID as SubAccID,
						   DateCreate,
						   IsAnalytic,
						   1
					from #ClientAgrees C
					inner join QORT_DB_PROD..SubaccStructure with (nolock, index = PK_SubaccStructure)
					ON C.SubAccID = Father_ID and 
					   Child_ID <> Father_ID and
					   Enabled = 0 and
					   not exists (select top 1 * from #ClientAgrees where SubAccID = Child_ID)
					inner join QORT_DB_PROD..Subaccs with (nolock, index = I_Subaccs_ID)
					ON Father_ID = Subaccs.id and Subaccs.Enabled = 0;

				insert into #CBRates
					select TradeAsset_ID as RateCurrency_ID,
		 				   Ask as Rate,
						   Qty,
						   ShortName as Currency
					from QORT_DB_PROD..Assets with (nolock, index=I_Assets_ID)
					inner join QORT_DB_PROD..CrossRates with (nolock, index=PK_CrossRates)
					ON InfoSource = 'MainCurBank' and Enabled = 0 and
					   TradeAsset_ID = Assets.id;

			insert into #Position
				select Position.id,
					   Asset_ID,
					   SubAccCode,
					   SubaccName,
					   Firms.BOCode,
					   AgreeNum,
					   cast (DateCreate as varchar) as AgreeDate,
					   AgreeId,
					   NULL,
					   RiskDescription as RiskLevel,
					   Accounts.Name as Account,
					   VolFreeStart,
					   VolFree,
					   VolBlocked,
					   VolForward+VolFree as VolRest,
					   VolForward,
					   VolForward+VolBlocked as VolItogo,
					   Firms.FirmShortName as OwnerShortName,
					   isResident,
					   Countries.CodeISO as CountryISO,
					   OKATO,
					   Firms.Id as FirmId,
					   'n',
					   isFirm,
					   Firms.IsQualified as IsQualInvest,
					   Subacc_ID								
				from QORT_DB_PROD..Position with (nolock)
				inner join QORT_DB_PROD..Accounts with (nolock)
				ON Accounts.id = Account_ID and Accounts.Enabled = 0
				inner join QORT_DB_PROD..Subaccs with (nolock)
				ON Subacc_ID = Subaccs.id and Subaccs.Enabled = 0
				inner join QORT_DB_PROD..Firms with (nolock)
				ON Firms.id = Subaccs.OwnerFirm_ID and Firms.Enabled = 0
				left join QORT_DB_PROD..Countries with (nolock)
				ON Country_ID = Countries.Id
				inner join  #ClientAgrees
				ON Subaccs.id = SubAccID
				left join #RL Levels			 
				ON 	Levels.RiskLevel = Firms.RiskLevel
				where (abs (VolFree) >= @ZeroLevel OR abs (VolForward) >= @ZeroLevel OR abs(VolBlocked) >= @ZeroLevel) and
					  Accounts.Name not like '%_WSH_%' and /* Исключаем тех.счета */
					  Accounts.Name not like '%_NON_%' and /* Исключаем тех.счета */
					  Accounts.Name not like 'RENBR_CCA_%' and /* Исключаем тех.счета */
					  Accounts.Name not like 'NonBroker%' and 
					  Accounts.Name not like 'NonDefined%' and
					  Accounts.Name not like 'RENBR_%_RENBR%' and
					  not (Firms.IsOurs = 'y' and Firms.STAT_Const = 5 and Firms.IsHeadBrok = 'y'); /* Исключаем субсчета, владельцем которых является ООО "Ренессанс Брокер" */
			end

		delete from #Position where id in 
		(select Position.id from #Position as Position
		 inner join QORT_DB_PROD..Assets as A with (nolock, index = I_Assets_ID)
		 ON A.ID = Position.Asset_ID AND
			AssetType_Const <> 1
			AND (AssetType_Const <> 3 OR
			     AssetSort_Const not in (15,16) OR
				 SubAccCode in ('RENBR','SPBFUT00TES','SPBFUT00FRB') OR
				 SubAccCode like 'POS%' OR
				 Account like '_NDCEM%' OR
				 Account like '_NKCKB%' OR
				 Account like 'CHSMN%' OR
				 Account like 'DCCRU%' OR
				 Account like 'MB%' OR
				 Account like '%_DEP_%' OR
				 Account like 'RENBR_BRO%' OR
				 Account like 'SPBFUT%'
			    )
		);

		insert into #Position
			select max (id) as id,
				   Asset_ID,
				   'UMG873',
				   'UMG873',
				   'RESEC',
				   AgreeNum,
				   AgreeDate,
				   -1,
				   AgreeIndex,
				   RiskLevel,
				   Account,
				   sum (VolFreeStart) as VolFreeStart,
				   sum (VolFree) as VolFree,
				   sum (VolBlocked) as VolBlocked,
				   sum (VolRest) as VolRest,
				   sum (VolForward) as VolForward,
				   sum (VolItogo) as VolItogo,
				   OwnerShortName,
				   isResident,
				   CountryISO,
				   OKATO,
				   FirmId,
				   isOwnerActive,
				   isFirm,
				   IsQualInvest,
				   -1
		from #Position P
		where P.BOCode = 'RESEC'
		group by Asset_ID,       AgreeNum,      AgreeDate,  
			     AgreeIndex,     RiskLevel,     Account,
 			     OwnerShortName, isResident,    CountryISO, OKATO,
				 FirmId,   	     isOwnerActive, isFirm,	    IsQualInvest;
		
		delete from #Position where BOCode = 'RESEC' and Subacc_ID > 0;

		insert into #Key 
			select Asset_ID, Account, BOCode, AgreeID
			from #Position
			group by Asset_ID, Account, BOCode, AgreeID 
			having (abs (sum(VolFree))    < @ZeroLevel AND 
					abs (sum(VolBlocked)) < @ZeroLevel AND
					abs (sum(VolForward)) < @ZeroLevel);

		delete from #Position where id in 
		(select id from #Position as Position
		 inner join #Key as T
		 ON T.Asset_ID   = Position.Asset_ID AND
			T.Account    = Position.Account AND
			T.BOCode     = Position.BOCode AND
			T.AgreeID    = Position.AgreeID);
		end
		
IF OBJECT_ID(N'tempdb..#SecCodes', N'U') IS NOT NULL   
DROP TABLE #SecCodes
create table #SecCodes (Asset_ID float,
                         SecCode  [VARCHAR](64),
						 priority int,
						 Enabled float);
				   
/*LOOK FOR ASSETS INFO */
		begin

IF OBJECT_ID(N'tempdb..#AssetIds', N'U') IS NOT NULL   
DROP TABLE #AssetIds
create table #AssetIds (id float);
		insert into #AssetIds select distinct (Asset_ID) from #Position;

		if (@DateReport < @CurrentOperDate)
			begin
				insert into #AssetsActual
					select Founder_ID as id,
					       AssetsHist.ShortName,
						   NULL as MoexTicker,
						   AssetsHist.ViewName as Name,
						   AssetsHist.ISIN,
						   AssetsHist.RegistrationCode,
						   AssetsHist.BaseValue,
						   AssetsHist.BaseCurrencyAsset_ID,
						   AssetsHist.BaseAssetSize,
						   AssetsHist.EmitDate,
						   Assets.ShortName as AssetCurrency,
						   iif (AssetsHist.AssetType_Const = 1, 'SECURITY', 'CASH') as AssetType,
		   				   AssetsHist.Enabled
                    from QORT_DB_PROD..Assets with (nolock, index = I_Assets_ID)
					right join 
				    (select Hist.* from QORT_DB_PROD..AssetsHist Hist with (nolock, index = I_AssetsHist_FounderID)
					 inner join #AssetIds A
					 ON A.Id = Hist.Founder_ID
					 where (AssetType_Const = 1  OR AssetType_Const = 3 AND AssetSort_Const in (15,16)) AND
							Founder_Date <= @DateReport AND
					        not exists (select top 1 * from QORT_DB_PROD..AssetsHist with (nolock, index = I_AssetsHist_FounderID) where 
							            Founder_ID = Hist.Founder_ID and 
										Founder_Date <= @DateReport and
										(Founder_Date > Hist.Founder_Date OR
										 Founder_Date = Hist.Founder_Date AND Founder_Time > Hist.Founder_Time OR
										 Founder_Date = Hist.Founder_Date AND Founder_Time = Hist.Founder_Time AND ID > Hist.id)
                                       )
				    ) as AssetsHist
					ON AssetsHist.BaseCurrencyAsset_ID = Assets.id;

         delete from #AssetsActual where Enabled <> 0;

		 insert into #SecCodes
			select Asset_ID,
			       ltrim(rtrim(SecCode)),
				   case when TSSection_ID = 33 then 1 
				        when TSSection_ID = 45 then 2 
						when TSSection_ID = 14 then 3 
						else 4 end,
				   Enabled
			from QORT_DB_PROD..SecuritiesHist Hist with (nolock, index = I_SecuritiesHist_FounderDate)
			where Founder_Date <= @DateReport AND
				  TSSection_ID in (33,45,14,76) AND
			      exists (select top 1 * from #AssetIds where id = Asset_ID) AND
				  not exists (select top 1 * from QORT_DB_PROD..SecuritiesHist with (nolock, index = I_SecuritiesHist_FounderID) where 
				                        Founder_ID = Hist.Founder_ID and
							            Asset_ID = Hist.Asset_ID and
										TSSection_ID = Hist.TSSection_ID and
										Founder_Date <= @DateReport and 
										(Founder_Date > Hist.Founder_Date OR
										 Founder_Date = Hist.Founder_Date AND Founder_Time > Hist.Founder_Time OR
										 Founder_Date = Hist.Founder_Date AND Founder_Time = Hist.Founder_Time AND ID > Hist.id)
                             )
			order by Asset_ID, SecCode;
			
			delete from #SecCodes where Enabled <> 0;

			update #AssetsActual set MoexTicker = 
			(select top 1 SecCode from #SecCodes where Asset_ID = id order by priority)
			 where AssetType = 'SECURITY';

 			delete from #AssetIds where id in (select id from #AssetsActual);
			delete from #SecCodes;

			end

			insert into #AssetsActual 
				select T1.id,
				       T1.ShortName,
					   NULL as MoexTicker,
					   T1.ViewName as Name,
					   T1.ISIN,
					   T1.RegistrationCode,
					   T1.BaseValue,
					   T1.BaseCurrencyAsset_ID,
					   T1.BaseAssetSize,
					   T1.EmitDate,
					   T2.ShortName as AssetCurrency,
					   iif (T1.AssetType_Const = 1, 'SECURITY', 'CASH') as AssetType,
					   0
				from QORT_DB_PROD..Assets T1 with (nolock, index = I_Assets_ID)
				inner join #AssetIds as AssetIds
				ON T1.id  = AssetIds.id
				left join QORT_DB_PROD..Assets T2 with (nolock, index = I_Assets_ID) ON T2.id = T1.BaseCurrencyAsset_ID
				where 
				   (T1.AssetType_Const = 1  OR T1.AssetType_Const = 3 AND T1.AssetSort_Const in (15,16)) AND
				    T1.Enabled = 0
		end

		delete from #Position where not exists (select top 1 * from #AssetsActual where id = Asset_ID);
		delete from #ClientAgrees where exists (select top 1 * from #Position where Subacc_ID = SubAccID);
		delete from #ClientAgrees where exists (select top 1 * from #Position P where P.BOCode = 'RESEC' and P.AgreeNum = AgreeNum and P.AgreeDate = DateCreate);

		 insert into #SecCodes
			select Asset_ID,
			       ltrim(rtrim(SecCode)),
				   case when TSSection_ID = 33 then 1 
				        when TSSection_ID = 45 then 2 
						when TSSection_ID = 14 then 3 
						else 4 end,
				   0
			from QORT_DB_PROD..Securities with (nolock, index = PK_Securities)
			where TSSection_ID in (33,45,14,76) and
		          Enabled = 0 and 
			      exists (select top 1 * from #AssetsActual where id = Asset_ID and AssetType = 'SECURITY' and
			                   MoexTicker is null)
			order by Asset_ID, SecCode;

        update #AssetsActual set MoexTicker = 
		(select top 1 SecCode from #SecCodes where Asset_ID = id order by priority)
		 where AssetType = 'SECURITY' and MoexTicker is null;

        update #AssetsActual set MoexTicker = '' where AssetType = 'SECURITY' and MoexTicker is null;

		set @AID = (select top 1 ID from #AssetsActual where AssetType = 'SECURITY');

		DECLARE @SecNum as int;
		set @SecNum = (select count (*) from #AssetsActual where AssetType = 'SECURITY');

		update #Position set VolFree = 0 where abs (VolFree) < @ZeroLevel;
		update #Position set VolBlocked = 0 where abs (VolBlocked) < @ZeroLevel;
		update #Position set VolForward = 0 where abs (VolForward) < @ZeroLevel;
		update #Position set VolRest = 0 where abs (VolRest) < @ZeroLevel;
		update #Position set VolItogo = 0 where abs (VolItogo) < @ZeroLevel;
		update #Position set VolFreeStart = 0 where abs (VolFreeStart) < @ZeroLevel;
		update #AssetsActual set AssetCurrency = '-', BaseCurrencyAsset_ID = id where AssetType = 'CASH';

/* CALCULATE DEAL PRICE FOR SECURITIES */
		begin 

IF OBJECT_ID(N'tempdb..#TMPDates', N'U') IS NOT NULL   
DROP TABLE #TMPDates
create table #TMPDates (ID float PRIMARY key,
						TDate [varchar] (20));

		DECLARE @Date90 as int;

		set @Date90 = convert(int, format(dateadd(day,-90, @Date), 'yyyyMMdd'));
		
		delete from #AssetIds;

		insert into #AssetIds select id from #AssetsActual where AssetType = 'SECURITY';

		insert into #TMPDates
		select ID = Asset_ID
			 , TDate = max(concat(TradeDate, right(concat('00000000', TradeTime), 9), right(concat('000', isnull(TradeTimeMCS, 0)), 3)))
		  from QORT_DB_PROD..Trades with(nolock)/*, index=I_Trades_TradeDate_PutPlannedDate)*/
		  inner join QORT_DB_PROD..Securities with(nolock) /*, index = PK_Securities) */
		  on Trades.Security_ID = Securities.ID
			 and Securities.Enabled = 0
			 and Securities.TSSection_ID not in(68, 69)
		  inner join #AssetIds as Assets on Assets.id = Securities.Asset_ID
		  left join QORT_DB_PROD..Phases with(nolock) on Phases.Trade_ID = Trades.id
														 and Phases.Enabled = 0
														 and Phases.IsCanceled = 'n'
														 and Phases.PC_Const = 17
		 where 1 = 1
			   and Trades.Enabled = 0
			   and Trades.TSSection_ID not in (68, 69)
			   and Trades.TradeDate between @Date90 and @DateReport
			   and iif(Trades.NullStatus = 'n', 1, 0) + iif(Phases.id is null, 1, 0) > 0
		 group by Asset_ID;

IF OBJECT_ID(N'tempdb..#TMP_TRADES', N'U') IS NOT NULL   
DROP TABLE #TMP_TRADES
create table #TMP_TRADES (Asset_ID float,
								   SecCode [VARCHAR] (64),
								   Price float,
								   TradeNum float,
								   TradeId float,
								   TradeDate int,
								   TradeTime [VARCHAR] (32),
								   TradeTimeMCS smallint,
								   PT_Const smallint,
								   CurrPriceAsset_ID float);

		insert into #TMP_TRADES 
			select Asset_ID,
				   SecCode,
				   Price,
				   TradeNum,
				   Trades.id as TradeId,
				   TradeDate,
				   TradeTime,
				   TradeTimeMCS,
				   PT_Const,
				   Trades.CurrPriceAsset_ID
			from #TMPDates as T
			inner join QORT_DB_PROD..Securities with(nolock, index = PK_Securities) 
			ON T.id = Securities.Asset_ID and Enabled = 0 and TSSection_ID not in (68, 69)
			inner join QORT_DB_PROD..Trades with (nolock, index = PK_Trades)
			ON Trades.Security_ID = Securities.ID AND
			   Trades.Enabled = 0 AND
			   Trades.TSSection_ID not in (68, 69) AND
			   TradeDate = left (T.TDate, 8) AND
			   right (T.TDate, 12) = concat (right(concat('00000000',TradeTime),9),
									              right (concat('000',isnull(TradeTimeMCS,0)),3)) AND
			   (Trades.NullStatus = 'n' OR
				not exists (select top 1 * from QORT_DB_PROD..Phases with (nolock, index = I_Phases_TradeID_PCConst) 
							where Trade_ID = Trades.id and Enabled = 0 and IsCanceled = 'n' and PC_Const = 17)
				);
	   
		update #TMP_TRADES set TradeTimeMCS = 0 where TradeTimeMCS is null;
		update #TMP_TRADES set TradeTime = 0 where TradeTime is null;

		select T.*,
			   BaseValue,
			   BaseCurrencyAsset_ID
		into #TMP_MAXDATETIMEMCS
		from #AssetsActual as Assets
		inner join #TMP_TRADES T
		ON T.Asset_ID = Assets.ID;

		update #TMP_MAXDATETIMEMCS set Price     = Price * BaseValue/100.0,
                                       CurrPriceAsset_ID = BaseCurrencyAsset_ID
		where PT_Const = 1;
		end

		select Asset_ID,
			   Price,
			   Currency as PriceCurrency,
			   Rate/Qty as Rate,
			   Price*Rate/Qty as PriceInRUB,
			   TradeNum,
			   TradeId,
			   cast (TradeDate as varchar) as TradeDate,
			   cast (TradeTime as varchar) as TradeTime,
			   TradeTimeMCS 
		into #TMPDealPrice
		from #CBRates 
		inner join #TMP_MAXDATETIMEMCS
		ON #TMP_MAXDATETIMEMCS.CurrPriceAsset_ID = RateCurrency_ID;

		select #TMPDealPrice.* 
		into #DealPrice 
		from #TMPDealPrice
		inner join
		(select Asset_ID, PriceInRUB, max (TradeId) as LastTradeId
		 from #TMPDealPrice
		 inner join 
		 (select Asset_ID as ID, max(PriceInRUB) as MaxPrice 
		  from #TMPDealPrice group by Asset_ID) as T1
		 ON T1.ID = #TMPDealPrice.Asset_ID AND
            T1.MaxPrice = #TMPDealPrice.PriceInRUB
		 group by Asset_ID, PriceInRUB) as T2
		ON T2.Asset_ID    = #TMPDealPrice.Asset_ID AND
           T2.LastTradeId = #TMPDealPrice.TradeId;

        insert into #Position 
				select 0,
					   Asset_ID,
					   SubAccCode,
					   SubaccName,
					   BOCode,
					   AgreeNum,
					   cast (DateCreate as varchar) as AgreeDate,
					   AgreeId,
					   NULL,
					   RiskDescription as RiskLevel,
					   '',
					   0,
					   0,
					   0,
					   0,
					   0,
					   0,
					   FirmShortName,
					   isResident,
					   Countries.CodeISO as CountryISO,
					   OKATO,
					   Firms.Id as FirmId,
					   'n',
					   isFirm,
					   Firms.IsQualified as IsQualInvest,
					   SubAccID 
		        from QORT_DB_PROD..Subaccs S
				inner join QORT_DB_PROD..Firms
				ON Firms.id = OwnerFirm_ID and
				   S.Enabled = 0 and
				   IsAnalytic not in ('y','Y')
				left join QORT_DB_PROD..Countries
				ON Country_ID = Countries.Id
				inner join  #ClientAgrees
				ON S.id = SubAccID
				left join #RL Levels			 
				ON 	Levels.RiskLevel = Firms.RiskLevel
				CROSS JOIN (select Asset_ID = @RUB_ID union all
			                select Asset_ID = @AID) AID      
				where not (Firms.IsOurs = 'y' and Firms.STAT_Const = 5 and Firms.IsHeadBrok = 'y') and /* Исключаем субсчета, владельцем которых является ООО "Ренессанс Брокер" */    
					  addByAnalyticFather <> 'y'; 

		update  #Position set AgreeIndex = concat(ltrim(rtrim (AgreeNum)), ' ', SUBSTRING (AgreeDate, 1, 4) + '-' + SUBSTRING (AgreeDate, 5, 2) + '-' +
		                                   SUBSTRING (AgreeDate, 7, 2)) where AgreeNum is not null;
		
		update  #Position set AgreeIndex = SubaccName where AgreeNum is null;

		update #Position set OKATO = substring (OKATO, 1,2) + '000' where isResident = 'y' or  isResident = 'Y';
		update #Position set OKATO = CountryISO where isResident = 'n' or  isResident = 'N';

/* FIND ACTIVE OWNERS */
		begin
			DECLARE @Date30 as int;
			set @Date30 = convert(int, format(dateadd(month,-1, @Date), 'yyyyMMdd'));

IF OBJECT_ID(N'tempdb..#FirmsId', N'U') IS NOT NULL   
DROP TABLE #FirmsId
create table #FirmsId (FirmId float);

			insert into #FirmsId
				select distinct OwnerFirm_ID from QORT_DB_PROD..Subaccs with(nolock)
				inner join QORT_DB_PROD..Trades with (nolock, index = PK_Trades)
				ON SubAcc_ID = Subaccs.id
				where Trades.Enabled = 0 and 
					  Subaccs.Enabled = 0 and
					  NullStatus = 'n' and
					  TradeDate <= @DateReport and
					  TradeDate > @Date30 and
					  TSSection_ID not in (68, 69);

			update #Position set isOwnerActive = 'y' where FirmId in (select FirmId from #FirmsId);
		end

		insert into #tmpSecPrice0420418
		select 
		      /* A */ tmpRank = ROW_NUMBER () over (order by SubaccCode, BOCode, AgreeId, AssetType, Account, ShortName),
			  /* B */ Account,
			  /* C */ SubAccCode,
			  /* D */ BOCode,
			  /* E */ AgreeNum,
			  /* F */ Assets.AssetType, 
			  /* G */ Assets.Name, 
			  /* H */ rtrim(ltrim(isnull(Assets.ISIN, ''))) as ISIN,
			  /* I */ ShortName,
			  /* J */ rtrim(ltrim(isnull(Assets.MoexTicker, ''))) as MoexTicker,
			  /* K */ BaseValue,
			  /* L */ AssetCurrency,
			  /* M */ VolFreeStart, 
			  /* N */ VolFree, 
			  /* O */ VolBlocked, 
			  /* P */ VolRest, 
			  /* Q */ VolForward, 
			  /* R */ VolItogo,
			  /* S */ OwnerShortName,
			  /* T */ isFirm,
			  /* U */ isResident,
			  /* V */ OKATO,
			  /* W */ IsQualInvest,
			  /* X */ isOwnerActive,
			  /* Y */ RiskLevel,
			  /* Z */ '0' as tmpStrNum,
			  /* AA */ '' as tmpPrice3Type,
			  /* AB */ '0' as tmpPrice3,
			  /* AC */ '' as tmpPrice3Curr,
			  /* AD */ '0' as tmpPrice3InRub,
			  /* AE */ Price as PriceDeal,
			  /* AF */ PriceCurrency as PriceDealCurrency,
			  /* AG */ Rate,
			  /* AH */ PriceInRUB as PriceDealInRUB,
			  /* AI */ TradeNum,
			  /* AJ */ TradeId,
			  /* AK */ SUBSTRING (TradeDate, 1, 4) + '-' + SUBSTRING (TradeDate, 5, 2) + '-' + SUBSTRING (TradeDate, 7, 2) as TradeDate,
			  /* AL */ stuff(stuff(stuff(right(concat('00000000',TradeTime),9),7,0,'.'),5,0,':'),3,0,':') as TradeTime,
			  /* AM */ TradeTimeMCS,
			  /* AN */ '0' as tmpPriceInRub,
			  /* AO */ '0' as tmpFreeInRub,
			  /* AP */ '0' as tmpForwardSummaryInRub,
			  /* AQ */ '=INDEX(AO:AO,ROW())+INDEX(AP:AP,ROW())' as tmpSummaryInRub,
			  /* AR */ AgreeIndex as AgreeId,
			  /* AS */ '=SUMIFS(AQ:AQ,S:S,INDEX(S:S,ROW()))' as AgrBalance,
			  /* AT */ '=IF(INDEX(AS:AS,ROW())>=0,"Y","N")' as Sign,
			  /* AU */ '=SUMIFS(AO:AO,AT:AT,INDEX(AT:AT,ROW()),F:F,"SECURITY",T:T,INDEX(T:T,ROW()),U:U,INDEX(U:U,ROW()),W:W,INDEX(W:W,ROW()),V:V,INDEX(V:V,ROW()),X:X,INDEX(X:X,ROW()),Y:Y,INDEX(Y:Y,ROW()))'
			           as AgrFreeBalanceSec,
			  /* AV */ '=SUMIFS(AO:AO,AT:AT,INDEX(AT:AT,ROW()),F:F,"CASH",T:T,INDEX(T:T,ROW()),U:U,INDEX(U:U,ROW()),W:W,INDEX(W:W,ROW()),V:V,INDEX(V:V,ROW()),X:X,INDEX(X:X,ROW()),Y:Y, INDEX(Y:Y,ROW()))'
			           as AgrFreeBalanceFreeCASH,
			  /* AW */ '=SUMIFS(AP:AP,AT:AT,INDEX(AT:AT,ROW()),F:F,"SECURITY",T:T,INDEX(T:T,ROW()),U:U,INDEX(U:U,ROW()),W:W,INDEX(W:W,ROW()),V:V,INDEX(V:V,ROW()),X:X,INDEX(X:X,ROW()),Y:Y,INDEX(Y:Y,ROW()))'
			           as AgrForwardBalanceSec,
			  /* AX */ '=SUMIFS(AP:AP,AT:AT,INDEX(AT:AT,ROW()),F:F,"CASH",T:T,INDEX(T:T,ROW()),U:U,INDEX(U:U,ROW()),W:W,INDEX(W:W,ROW()),V:V,INDEX(V:V,ROW()),X:X,INDEX(X:X,ROW()),Y:Y,INDEX(Y:Y,ROW()))'
			           as AgrForwardBalanceFreeCASH,
			  /* AY */ '=1/COUNTIF(D:D,INDEX(D:D,ROW()))' as Frequency,
			  /* AZ */ '=ROUND(SUMIFS(AY:AY,AT:AT,INDEX(AT:AT,ROW()),T:T,INDEX(T:T,ROW()),U:U,INDEX(U:U,ROW()),W:W,INDEX(W:W,ROW()),V:V,INDEX(V:V,ROW()),X:X,INDEX(X:X,ROW()),Y:Y,INDEX(Y:Y,ROW())),0)'
			           as Counts,
			           @SecNum as SecNum,
			           Assets.id as Asset_ID,
					   rtrim(ltrim(isnull(Assets.RegistrationCode, ''))) as RegistrationCode
		from #Position as Position 
		left join #DealPrice
		ON #DealPrice.Asset_ID = Position.Asset_ID
		left join #AssetsActual as Assets
		ON Position.Asset_ID = Assets.id
		order by SubaccCode, BOCode, AgreeId, AssetType, Account, ShortName;

		update #tmpSecPrice0420418 
		set TradeNum = 0, TradeId = 0, PriceDeal = 0, PriceDealInRUB = 0, PriceDealCurrency = '', Rate = 0, TradeTimeMCS = 0
		where TradeId is null;

		update #tmpSecPrice0420418 set
				tmpStrNum = iif (RegistrationCode <> '',
				                 iif (MoexTicker <> '',
				   	                  '=IFNA(MATCH("' + RegistrationCode + '",SEM21A!R:R,0),IFNA(MATCH("'+ MoexTicker + '",SEM21A!L:L,0),0))',
									  '=IFNA(MATCH("' + RegistrationCode + '",SEM21A!R:R,0),0)'
									  ),
								 iif (MoexTicker  <> '',
								      '=IFNA(MATCH("' + MoexTicker + '",SEM21A!L:L,0),IFNA(MATCH("'+ ISIN + '",SEM21A!L:L,0),0))',
									  iif (ISIN  <> '','=IFNA(MATCH("' + ISIN + '",SEM21A!L:L,0),0)'
									  ,'=0')
									  )
								),
  				tmpPrice3Type = '=IF(INDEX(Z:Z,ROW()) > 0, INDEX(SEM21A!O:O, INDEX(Z:Z,ROW())),"NONE")',
				tmpPrice3 = '=IF(INDEX(Z:Z,ROW()) > 0, INDEX(SEM21A!AP:AP,INDEX(Z:Z,ROW()))*IF(INDEX(AA:AA,ROW())="PERC",INDEX(SEM21A!T:T,INDEX(Z:Z,ROW()))/100,1),0)',
				tmpPrice3Curr = '=IF(INDEX(Z:Z,ROW()) > 0, IF(INDEX(AA:AA,ROW())="PERC",INDEX(SEM21A!U:U,INDEX(Z:Z,ROW())),INDEX(SEM21A!X:X,INDEX(Z:Z,ROW()))),"RUB")',
				tmpPrice3InRub = '=INDEX(AB:AB,ROW())*IF(INDEX(AC:AC,ROW())="RUB",1,IF(INDEX(AC:AC,ROW())=INDEX(AF:AF,ROW()), INDEX(AG:AG,ROW()),IF(IFNA(MATCH(INDEX(AC:AC,ROW()),AF:AF,0),0)>0,INDEX(AG:AG,MATCH(INDEX(AC:AC,ROW()),AF:AF,0)),1)))',			
 			    tmpPriceInRub = '=IF(OR(INDEX(AB:AB,ROW())>0,INDEX(AE:AE,ROW())=0),INDEX(AD:AD,ROW()), INDEX(AH:AH,ROW()))',
 				tmpFreeInRub = '=INDEX(N:N,ROW())*INDEX(AN:AN,ROW())',
 			    tmpForwardSummaryInRub = '=INDEX(R:R,ROW())*INDEX(AN:AN,ROW())'
				where AssetType = 'SECURITY';

		update #tmpSecPrice0420418 set
				ISIN = '',
			    MoexTicker = '',
				BaseValue = 0,
				Rate = (select Rate/Qty from #CBRates where RateCurrency_ID = Asset_ID),
 				tmpFreeInRub = '=INDEX(N:N,ROW())*INDEX(AG:AG,ROW())',
 			    tmpForwardSummaryInRub = '=INDEX(R:R,ROW())*INDEX(AG:AG,ROW())'		    
				where AssetType = 'CASH';

		select * from #tmpSecPrice0420418 order by SubaccCode, BOCode, AgreeId, AssetType, Account, ShortName;
	end
