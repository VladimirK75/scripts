
CREATE PROCEDURE [dbo].[DDM_InsertContractInstr] 
	@OrderID bigint,
	@Status varchar (50), /* as in DDM (New, Executing, Executed, Rejected, Cancelled)*/
	@SecCode varchar(255),
	@FinishDate bigint = null,
	@FinishTime bigint = null,
    @msg nvarchar(4000) OUTPUT
AS
BEGIN
	SELECT @msg = '000. Ok'
	
	DECLARE @OrderGID varchar(255),
			@Status_Const int,
			@StatusDate datetime,
			@WithdrawTime int,
			@IT_Const smallint,
			@TSSection_Name varchar(100),
			@DateInt int,
			@TimeInt int,
			@Direction int,
			@Infosource varchar(200),
			@OrderType varchar(50),
			@IsAgent char(1)
			
	SELECT @OrderGID = ExternalID,
		   @StatusDate = StatusDateTime,
		   @OrderType = OrderType,
		   @DateInt = YEAR(RaisedDateTime) * 10000 + MONTH(RaisedDateTime) * 100 + DAY(RaisedDateTime),
		   @TimeInt = datepart(hh, RaisedDateTime)*10000000+datepart(minute, RaisedDateTime)*100000+datepart(ss, RaisedDateTime)*1000,	   
		   @Infosource = SourceSystem,
		   @Direction = Direction,
		   @IsAgent = case BrokerRole when 'Agent' then 'Y' else 'N' end
	  FROM QORT_DDM..ContractsOrders with (nolock)
	 WHERE ID = @OrderID
	 
	 
	select @Infosource = case @Infosource
			when 'FIDESSA' then 'FIX FD'
			when 'MUREX' then 'FIX MX'
			else null
			end

	SELECT @IT_Const = 17
	IF @Direction = 1 SELECT @IT_Const = 7 	ELSE SELECT @IT_Const = 8
				 
	SELECT @Status_Const = 
			case @Status
				when 'New' then 1
				when 'Executing' then 4
				when 'Executed' then 5
				when 'Rejected' then 6
				when 'Cancelled' then 9
				else null
			end,
			@WithdrawTime = datepart(hh, @StatusDate)*10000000+datepart(mm, @StatusDate)*100000+datepart(ss, @StatusDate)*1000

	SELECT @TSSection_Name = TSSection
	  FROM QORT_DDM..ImportTrade_Rules
	 WHERE OrderType = @OrderType

	IF isnull(@TSSection_Name, '') = ''
	BEGIN
	  SELECT @msg = '001. TSSection not found for OrderType ' + @OrderType	  
	  RETURN 
	END

			
	IF isnull(@FinishDate,0) = 0 and @Status_Const not in (1,4) 
	BEGIN
		SELECT	@FinishTime = datepart(hh, @StatusDate)*10000000+datepart(mm, @StatusDate)*100000+datepart(ss, @StatusDate)*1000,
				@FinishDate = YEAR(@StatusDate) * 10000 + MONTH(@StatusDate) * 100 + DAY(@StatusDate)
	END
   UPDATE 
      QORT_TDB_PROD..ImportTradeInstrs with(rowlock)
   SET
		Firm_ShortName = f.FirmShortName,
		Time = @TimeInt,
		OwnerFirm_ShortName = o.FirmShortName,
		Section_Name = @TSSection_Name,
		Type = @IT_Const, -- ??? ????????
		Security_Code = @SecCode,
		Qty = t.Qty,
		PutPlannedDate = null,
		PayPlannedDate = null,
		AuthorSubAcc_Code = t.LoroAccount,
		IS_Const = @Status_Const, -- ???????
		OptPrice1 = t.Strike,
		OptPrice2 = case when t.OrderType like '%Option%' then t.Price else null end,
		Price = t.Price,
		PriceType = 2, -- Absolute
		Volume = null,
		OwnerFirm_BOCode = o.BOCode,
		Firm_BOCode = f.BOCode,
		CurrencyAsset_ShortName = case t.PriceCurrency when 'RUB' then 'RUR' else t.PriceCurrency end,
		WithdrawTime = @WithdrawTime,
		CpFirm_BOCode = t.Counterparty,
		DM_Const = 2, -- Electronno
		FinishDate = @FinishDate,
		FinishTime = @FinishTime,
		InstrSort_Const = 2, 
		InfoSource_Name = @Infosource,
		TYPE_Const = 2, -- Torgovoe
        IsAgent = @IsAgent,
		ET_Const = 4,
		IsProcessed = 1
	FROM
	QORT_TDB_PROD..ImportTradeInstrs iti with(rowlock) 
	   INNER JOIN QORT_DDM..ContractsOrders t with (nolock) on iti.RegisterNum = t.ExternalID
	   INNER JOIN QORT_DB_PROD..Firms f with(nolock)  on f.BOCode = t.LegalEntity collate Cyrillic_General_CI_AS and f.Enabled = 0
	   INNER JOIN QORT_DB_PROD..Subaccs s with(nolock)  on s.SubAccCode = t.LoroAccount collate Cyrillic_General_CI_AS
	   INNER JOIN QORT_DB_PROD..Firms o with(nolock)  on o.ID = s.OwnerFirm_ID
	   WHERE t.ID = @OrderID and IsProcessed = 3
	
	IF @@ROWCOUNT = 0
	INSERT QORT_TDB_PROD..ImportTradeInstrs with(rowlock)
		(id,	--?? ?????????
		Firm_ShortName,
		Date, --?? ?????????
		Time, 
		RegisterNum, --?? ?????????
		OwnerFirm_ShortName,
		Section_Name,
		Type, -- ??? ????????
		Security_Code,
		Qty,
		PutPlannedDate,
		PayPlannedDate,
		AuthorSubAcc_Code,
		IS_Const, -- ???????
		OptPrice1,
		OptPrice2,
		Price,
		PriceType,
		OwnerFirm_BOCode,
		Firm_BOCode,
		BackID, --?? ?????????
		CurrencyAsset_ShortName,
		WithdrawTime,
		CpFirm_BOCode,
		DM_Const, -- Electronno
		FinishDate,
		FinishTime,
		InstrSort_Const, 
		InfoSource_Name,
		TYPE_Const,
        IsAgent,
		ET_Const,
		IsProcessed)	
	SELECT
		-1,
		f.FirmShortName,
		@DateInt,
		@TimeInt,
		t.ExternalID,
		o.FirmShortName,
		@TSSection_Name,
		@IT_Const,
		@SecCode,
		t.Qty,
		null,
		null,
		t.LoroAccount,
		@Status_Const,
		t.Strike,
		case when t.OrderType like '%Option%' then t.Price else null end,
		t.Price,
		2, -- Absolute
		o.BOCode,
		f.BOCode,
		t.ExternalID + '/' + convert(varchar(20), t.ID),
		case t.PriceCurrency when 'RUB' then 'RUR' else t.PriceCurrency end,
		null,
		t.Counterparty,
		2, -- Electronno
		@FinishDate,
		@FinishTime,
		2, 
		@Infosource,
		2, -- TYPE CONST Torgovoe
        @IsAgent,
		2, --ET Const
		1
		FROM QORT_DDM..ContractsOrders t with (nolock)
	   INNER JOIN QORT_DB_PROD..Firms f with(nolock) on f.BOCode = t.LegalEntity collate Cyrillic_General_CI_AS and f.Enabled = 0
	   INNER JOIN QORT_DB_PROD..Subaccs s with(nolock) on s.SubAccCode = t.LoroAccount collate Cyrillic_General_CI_AS
	   INNER JOIN QORT_DB_PROD..Firms o with(nolock) on o.ID = s.OwnerFirm_ID
	   WHERE t.ID = @OrderID
	             
	RETURN 

END
