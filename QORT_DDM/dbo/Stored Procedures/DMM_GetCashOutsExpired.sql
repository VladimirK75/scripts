CREATE     procedure [dbo].[DMM_GetCashOutsExpired]
                                   @Date datetime,
								   @Depth int = 14 /* Глубина отчета по времени, в календарных днях */
as
    begin

		DECLARE @DateReport as int;
		DECLARE @Date14 as int;
		DECLARE @tmp as int;

		IF OBJECT_ID('tempdb..#tmpCashOutsExpired') IS NOT NULL
			drop table #tmpCashOutsExpired;

			create table #tmpCashOutsExpired (
            /*A*/    tmpRank  float, /* Для нумерации*/
			/*B*/	 RegistrationDate [VARCHAR] (10), /* Дата регистрации */
			/*C*/    ExecutionDate [VARCHAR] (10), /* Дата исполнения */
			/*D*/	 Id float, /* Correct Position Id */
			/*E*/	 SubAccCode [VARCHAR] (32), /* Код субсчёта */
			/*F*/	 OwnerName [VARCHAR] (150), /* Наименование/ ФИО владельца субсчета*/
			/*G*/	 Account [VARCHAR] (100),  /* Счёт */
			/*H*/	 DVCode [VARCHAR] (150),  /* Фактический номер раздела счета депо */
			/*I*/    Status [VARCHAR] (20), /* Статус CashOuts */
			/*J*/    Amount float, /* Сумма CashOuts */
			/*K*/    Currency [VARCHAR] (3), /* Валюта Суммы */
			/*L*/    ClientInstrId float, /* ID поручения клиента */
			/*M*/    ClientInstrDate [VARCHAR] (10), /* Дата поручения клиента */
			         CashOutsNum int /* Количество CashOuts */
        )

		set @DateReport = convert(int, format(@Date, 'yyyyMMdd'));
		set @tmp = QORT_DDM.dbo.DDM_fn_AddBusinessDay (@DateReport, -2,'');
		set @Date14 = convert(int, format(dateadd(day,-@Depth, @Date), 'yyyyMMdd'));

		insert into #tmpCashOutsExpired
			select 
			/*A*/ tmpRank = ROW_NUMBER () over (order by RegistrationDate, CP.Date, CP.id, SubaccCode, Accounts.Name, Assets.ShortName, CP.Size),
			/*B*/ RegistrationDate,
			/*C*/ CP.Date as ExecutionDate,
			/*D*/ CP.id as Id,
			/*E*/ SubAccCode,
			/*F*/ FirmShortName as OwnerName,
			/*G*/ Accounts.Name as Account,
			/*H*/ SubaccName as DVCode,
			/*I*/ 'Не исполнена' as Status,
			/*J*/ CP.Size as Amount,
			/*K*/ Assets.ShortName as Currency,
			/*L*/ InstrNum as ClientInstrId,
			/*M*/ ClientInstr.Date as ClientInstrDate, 
				  0 as CashOutsNum
		from QORT_DB_PROD..Assets with (nolock)
		inner join 
		(select * from QORT_DB_PROD..CorrectPositions with (nolock)
		 where Enabled = 0 AND 
		       RegistrationDate <= @DateReport AND
		       RegistrationDate >  @Date14 AND
			   IsCanceled = 'n' AND
			   CT_Const = 7 AND
			   (Date = 0 AND RegistrationDate < @tmp OR
			    QORT_DDM.dbo.DDM_fn_AddBusinessDay (RegistrationDate, 2,'') < Date)
				) as CP
 		 ON Assets.id = Asset_ID
		 inner join QORT_DB_PROD..Accounts 
		 ON Accounts.id = Account_ID
		 inner join QORT_DB_PROD..Subaccs
		 ON Subaccs.id = Subacc_ID
		 inner join QORT_DB_PROD..Firms
		 ON Firms.id = Subaccs.OwnerFirm_ID
		 left join QORT_DB_PROD..ClientInstr
		 ON ClientInstr_ID = ClientInstr.id
		 where FirmShortName not like '%Ренессанс Брокер%' /* Исключаем субсчета, владельцем которых является ООО "Ренессанс Брокер" */
		 order by RegistrationDate, CP.Date, CP.id, SubaccCode, Accounts.Name, Assets.ShortName, CP.Size;

		 set @tmp = (select count (*) from #tmpCashOutsExpired);

		 if (@tmp > 0)
			begin
				update #tmpCashOutsExpired set CashOutsNum      = @tmp, 
											   RegistrationDate = SUBSTRING (RegistrationDate, 1, 4) + '-' + 
																  SUBSTRING (RegistrationDate, 5, 2) + '-' +
																  SUBSTRING (RegistrationDate, 7, 2);

				update #tmpCashOutsExpired set Status        = 'Исполнена',
											   ExecutionDate = SUBSTRING (ExecutionDate, 1, 4) + '-' + 
											                   SUBSTRING (ExecutionDate, 5, 2) + '-' +
															   SUBSTRING (ExecutionDate, 7, 2)
				where ExecutionDate > 0;

				update #tmpCashOutsExpired set ClientInstrDate = SUBSTRING (ClientInstrDate, 1, 4) + '-' + 
											                     SUBSTRING (ClientInstrDate, 5, 2) + '-' +
															     SUBSTRING (ClientInstrDate, 7, 2)
				where ClientInstrId is not null and ClientInstrId > 0
			end

		 select * from #tmpCashOutsExpired order by RegistrationDate, ExecutionDate, Id, SubAccCode, Account, Currency, Amount;

	end
