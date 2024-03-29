
CREATE PROCEDURE [dbo].[DDM_InsertClearing] 
	@RuleID bigint,
	@MovementID bigint,
	@SettlementDetailID bigint = null,
	@SettlementDate datetime = null,
    @msg nvarchar(4000) OUTPUT
AS
BEGIN
	SELECT @msg = '000. Ok'

    DECLARE @BackID 			varchar(100),
    		@Infosource 		varchar(100),
		    @IsSynchronized 	bit,
    		@IsDual				bit,
    		@NeedClientInstr	bit,
    		@SettledOnly		bit,
    		@STLRuleID			bigint,
			@CT_Const			tinyint,
		    @ExternalID       	varchar(255),
            @SettlementID       bigint,
		    @TxnGID           	varchar(100),
		    @OperationType    	varchar(50),
		    @InstrLoroAccount	varchar(6),
		    @TradeDate        	datetime,
		    @TradeDateInt      	int,
		    @SettlementDateInt 	int,
		    @BackOfficeNotes  	varchar(255),
		    @IssueReference   	varchar(50),
		    @TradeReference   	varchar(50),
		    @MovType	       	varchar(8),
		    @LegalEntity      	varchar(5),
		    @GetLegalEntity    	varchar(5),
		    @LoroAccount		varchar(6),
		    @NostroAccount	 	varchar(50),
		    @GetLoroAccount		varchar(6),
		    @GetNostroAccount 	varchar(50),
		    @PlanSettlementDate	datetime,
		    @Issue	         	varchar(25),
		    @Price	         	decimal(38,14),
		    @SettledPrice      	decimal(38,14),
		    @ChargeType	    	varchar(50),
		    @Currency	      	varchar(3),
		    @SettlCurrency     	varchar(3),
		    @MovementID2 		bigint,
		    @SystemID			bigint,
		    @Asset_ShortName 	varchar(48),
		    @Size				decimal(38,14),
		    @StlExternalID		bigint,
		    @ReversedID			bigint,
		    @StlType			varchar(6),
		    @StlDateType		varchar(50),
		    @Comment2 			varchar(255),
		    @DefaultComment		varchar(255),
		    @IsInternal			bit
            

	
	RETURN 

END
