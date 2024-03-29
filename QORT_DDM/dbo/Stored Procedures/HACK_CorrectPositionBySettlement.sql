
CREATE PROCEDURE [dbo].[HACK_CorrectPositionBySettlement] 
	@TransferID varchar(255),
	@CT_Const	tinyint,
	@StlDateType varchar(50),
    @msg nvarchar(4000) OUTPUT
AS
BEGIN
	SELECT @msg = '000. Ok'

    DECLARE @BackID 			varchar(100),
			@SettlementDetailID bigint,
    		@Infosource 		varchar(100),
    		@DdmStatus 			varchar(100),
		    @ExternalID       	varchar(255),
            @SettlementID       bigint,
		    @TxnGID           	varchar(100),
		    @OperationType    	varchar(50),
		    @TradeDate        	datetime,
		    @SettlementDate    	datetime,
		    @TradeDateInt      	int,
		    @TradeTimeInt      	int,
		    @SettlementDateInt 	int,
		    @BackOfficeNotes  	varchar(255),
		    @IssueReference   	varchar(50),
		    @TradeReference   	varchar(50),
		    @MovType	       	varchar(8),
		    @LegalEntity      	varchar(5),
		    @LoroAccount		varchar(20),
		    @NostroAccount	 	varchar(50),
		    @Issue	         	varchar(25),
		    @Price	         	decimal(38,14),
		    @CPAmount	      	decimal(38,14),
		    @AccruedCoupon     	decimal(38,14),
		    @Direction	     	smallint,
		    @ChargeType	    	varchar(50),
		    @Currency	      	varchar(3),
		    @SystemID			bigint,
		    @Asset_ShortName 	varchar(48),
		    @StlExternalID		varchar(255),
		    @ReversedID			bigint,
		    @StlType			varchar(6),
		    @Comment2 			varchar(255),
		    @DefaultComment		varchar(255),
		    @IsInternal			char(1),
		    @IsProcessed		smallint,
		    @IgnoreMv1			tinyint,
		    @IgnoreMv2			tinyint,
		    @PDocType_Name		varchar(200),
		    @InternalNumber varchar(255),
			@InstrNum bigint,
			@InstrDateTime datetime,
		    @IT_Const smallint,
		    @INSTR_Const smallint
            

   	SELECT @TradeTimeInt = 0

	select top 1 @SettlementDetailID = sd.ID, @DdmStatus = DdmStatus, @SettlementID = s.ID
	  from 	QORT_DDM..ImportedTranSettlement s,
			QORT_DDM..ImportedTranSettlementDetails sd
	where s.ExternalID = @TransferID
		and s.ID = sd.SettlementID
	order by Version desc, EventDateTime desc
   	
   	IF @DdmStatus <> 'Active'
   	BEGIN
		INSERT INTO [QORT_TDB_PROD].[dbo].[CancelCorrectPositions] (id, BackID, isProcessed, IsExecByComm)
		        SELECT -1, BackID, 1, 'Y'
		          FROM QORT_TDB_PROD..CorrectPositions 
		         WHERE BackID like (@TransferID + '%')
				
				IF @@ROWCOUNT > 0
					INSERT INTO QORT_TDB_PROD.dbo.ImportExecutionCommands (id, TC_Const, Oper_ID, IsProcessed, ErrorLog)
					SELECT -1, 16, id, 1,null
					  FROM [QORT_TDB_PROD].[dbo].[CancelCorrectPositions]      
					 WHERE BackID like (@TransferID + '%')      

				
		SELECT @msg = '000. CorrectPosition Canceled'    
		RETURN	
   	END
   		
   	 SELECT @ExternalID = s.ExternalID,
   	 		@BackID = s.ExternalID + '/' + cast(@CT_Const as varchar(3)),
            @TxnGID = s.ExternalTransactionID,
		    @MovType = sd.MovType,
		    @LegalEntity = 'RENBR',
		    @Currency = case sd.Currency
                        when 'RUB' then 'RUR'
                        else sd.Currency
                        end,
		    @Direction = case sd.Type
		    				when 'Loro' then -1*sd.Direction
		    				when 'Nostro' then sd.Direction
		    			 end,
            @Issue = sd.Issue,
		    @Price = sd.Price,
		    @CPAmount = round(isnull(sd.Amount, 0) + isnull(sd.Qty, 0),2),
		    @AccruedCoupon = round(sd.AccruedCoupon,2),
		    @TradeDate = isnull(s.AvaliableDate, getDate()),
	    	@LoroAccount = sd.LoroAccount,
	    	@NostroAccount = sd.NostroAccount,
	    	@ChargeType = sd.ChargeType,
	    	@Infosource = 'DDM Importer. SDID = ' + cast(@SettlementDetailID as varchar(255))			    
    	  FROM QORT_DDM..ImportedTranSettlementDetails sd with (nolock),
		       QORT_DDM..ImportedTranSettlement s with (nolock) 
    	 WHERE sd.ID = @SettlementDetailID
    	   AND sd.SettlementID = s.ID
   		
		/* Определяем дату расчетов, согласно правилам */	
		SELECT @SettlementDate = case @StlDateType
					   				when 'FOAvaliableDate' then st.FOAvaliableDate
					   				when 'ActualSettlementDate' then st.ActualSettlementDate
					   				when 'AvaliableDate' then st.AvaliableDate
					   			  end
		  FROM QORT_DDM..ImportedTranSettlement st with (nolock)
		 WHERE ID = @SettlementID
		 
	   	SELECT @TradeTimeInt = 193000000
	
    SELECT top 1 
    	   @NostroAccount = isnull(isnull(nm.AccountCode, a.ExportCode), @NostroAccount),
    	   @IgnoreMv1 = nm.Ignore
      FROM QORT_DB_PROD..Accounts a
      LEFT JOIN QORT_DB_PROD..AccountTypes ca ON a.AccountType_ID = ca.ID
      LEFT JOIN QORT_DDM..NostroMapping nm ON (@NostroAccount like nm.Nostro and (isnull(ca.Name,'') = isnull(nm.Category,'') or nm.Category is null))
     WHERE a.AccountCode = @NostroAccount
     ORDER BY nm.Priority, a.id desc

	IF @LoroAccount is null 
		SELECT @LoroAccount = @LegalEntity

    SELECT @LoroAccount = isnull(SubAccount, @LoroAccount),
    	   @IgnoreMv1 = isnull(@IgnoreMv1,0) + isnull(Ignore, 0)
      FROM QORT_DDM..ClientLoroAccount 
     WHERE @LoroAccount like LoroAccount
       AND (isnull(NostroAccount,'') = '' OR @NostroAccount like NostroAccount)
	
	IF isnull(@IgnoreMv1, 0) > 0 
	BEGIN
		SELECT @msg = '022. Movements filtered out by LORO or Nostro '
		RETURN 
	END
		
	IF @MovType = 'CASH' 
	BEGIN
		SELECT @Asset_ShortName = @Currency

		IF isnull(@Asset_ShortName,'') = '' 
		BEGIN
 			SELECT @msg = '003. Currency is empty for CASH movement'
 			RETURN 
		END
	END
	ELSE 
	BEGIN
		SELECT @Asset_ShortName = ShortName
		  FROM QORT_DB_PROD..Assets
		 WHERE Marking = @Issue
		 	 
		IF isnull(@Asset_ShortName,'') = '' 
		BEGIN
 			SELECT @msg = '004. Asset not found for GRDB ID = ' + @Issue 
 			RETURN 
		END
	END
	
    SELECT @TradeDateInt = YEAR(@TradeDate) * 10000 + MONTH(@TradeDate) * 100 + DAY(@TradeDate),
           @SettlementDateInt = isnull(YEAR(@SettlementDate) * 10000 + MONTH(@SettlementDate) * 100 + DAY(@SettlementDate), 0),
           @CPAmount = round((@Direction * @CPAmount),2)
	
	set @InternalNumber = null

	SELECT @Comment2 = @TxnGID + '/' + @ChargeType

	IF abs(isnull(@CPAmount,0)) > 0
	BEGIN
		INSERT INTO [QORT_TDB_PROD].[dbo].[CorrectPositions] (
			[id],
			[BackID],
			[Date],
			[Time],
			[Subacc_Code],
			[Account_ExportCode],
			[Comment],
			[CT_Const],
			[Asset],
			[Size],
			[Price],
			[CurrencyAsset],
			[IsProcessed],
			[Accrued],
	--		[PDocType_Name],
	--		[PDocNum],
	--		[PDocDate],
			[ET_Const],
			[RegistrationDate],
			[GetSubacc_Code],
			[GetAccount_ExportCode],
			[Comment2],
			[Infosource],
			[IsInternal],
			[PDocType_Name],
			[ClientInstr_InternalNumber],
			[IsExecByComm]
		)
		VALUES (
			-1,
			@BackID,
			@SettlementDateInt,
			@TradeTimeInt,
			@LoroAccount,
			@NostroAccount,
			'',
			@CT_Const,
			@Asset_ShortName,
			cast(@CPAmount as float),
			@Price,
			@Currency,
			1,
			@AccruedCoupon,
	--		@PDocType_Name,
	--		@PDocNum,
	--		@PDocDate,
			4,
			@TradeDateInt,
			null,
			null,
			@Comment2,
			@Infosource,
			'N',
			null,
			null,
			'Y'
		)

		  INSERT INTO QORT_TDB_PROD.dbo.ImportExecutionCommands (id, TC_Const, Oper_ID, IsProcessed, ErrorLog)
		  SELECT -1, 5, max(id), 1, null
		  FROM [QORT_TDB_PROD].[dbo].[CorrectPositions]      
		  WHERE BackID = @BackID      

	    SELECT @msg = '000. CP @BackID = ' + @BackID + ' is inserted. @CPAmount: ' + cast(@CPAmount as varchar(50)) + ' @SettlementDateInt: ' + cast(@SettlementDateInt as varchar(50))
	END
	ELSE 
	    SELECT @msg = '000. CP @BackID = ' + @BackID + ' was not inserted because Size = 0. @CPAmount: ' + cast(@CPAmount as varchar(50)) + ' @SettlementDateInt: ' + cast(@SettlementDateInt as varchar(50))
		
	RETURN 

END
