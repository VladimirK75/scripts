
CREATE PROCEDURE [dbo].[DDM_ExportSettlementDetailProcess] 
	@SettlementDetailID bigint,
    @Action nvarchar(7), -- New and Cancel only
    @msg	nvarchar(4000) OUTPUT
AS
BEGIN
    DECLARE @Rez int,
    		@Infosource 		varchar(100),
    		@SettlementID		bigint,
		    @IsSynchronized 	bit,
    		@IsDual				bit,
    		@NeedClientInstr	bit,
    		@SettledOnly		bit,
    		@STLRuleID			bigint,
			@QRTObject			varchar(50),
			@QRTObjType			tinyint,
		    @Version          	tinyint,
		    @Direction	     	smallint,
		    @SettlementDate		datetime,
		    @SettlementDateInt	int,
		    @AccruedCoupon	 	decimal,
		    @SettledAccCoupon 	decimal,
		    @Amount	        	decimal,
		    @SettledAmount     	decimal,
		    @UnSettledAmount   	decimal,
            @Size               decimal,
		    @SystemID			bigint,
		    @StlExternalID		bigint,
		    @ReversedID			bigint,
		    @RuleID				bigint,
		    @StlType			varchar(6),
		    @StlDateType		varchar(50)
		    

	SELECT  @SettlementID = sd.SettlementID,
		    @SettledAccCoupon = sd.AccruedCoupon,
		    @SettledAmount = isnull(sd.Amount, sd.Qty),
		    @StlType = sd.Type,
		    @ReversedID = isnull(s.ReversedID, 0),
		    @StlExternalID = s.ExternalID,
		    @Direction = sd.Direction,
		    @AccruedCoupon = sd.AccruedCoupon,
		    @Amount = isnull(sd.Amount, sd.Qty)
	  FROM QORT_DDM..QRT2NTO_SettlementDetails sd with (nolock)
	 INNER JOIN  QORT_DDM..QRT2NTO_Settlement s with (nolock) ON sd.SettlementID = s.ID
	 WHERE sd.ID = @SettlementDetailID

/* BackID âñåãäà íà÷èíàåòñÿ ñ ExternalID òðàíçàêöèè è MovementID, ïîðîäèâøèìè êîððåêòèðîâêó. Äëÿ êàæäîãî Settlement, êîòîðûé ëèøü ÷àñòè÷íî çàêðûâàåò îáúåì âñåé êîððåêòèðîâêè ê BackID äîáàâëÿåòñÿ ID SettlementDetail. Åñëè êîððåêòèðîâêà èñïîëíèëàñü îäíèì Settlement îáúåêòîì ñðàçó íà âñþ ñóììó, ññûëêà íà Settlement ó íåå áóäåò òîëüêî â êîììåíòàðèè è Infosource */    

	SELECT  @RuleID = dr.RuleID,
			@QRTObject = dr.QRTObject,
			@QRTObjType = dr.QRTObjType,
			@SettledOnly = dr.SettledOnly,
			@STLRuleID = dr.STLRuleID,
		    @StlDateType = sr.SettlementDate
	  FROM QORT_DDM..DDM2QORT_Rules dr with (nolock),
	  	   QORT_DDM..ExportSettlementRules sr with (nolock)
	 WHERE dr.IsSynchronized = 1
	   AND (dr.StartDate <= getDate() AND isnull(dr.EndDate, '20501231') > getDate())
	   AND ((dr.Direction is null) or (dr.Direction = @Direction))
	   AND dr.STLRuleID = sr.STLRuleID
	   AND sr.Capacity = @StlType

	IF @QRTObject is null 
	BEGIN
		SELECT @msg = '001. No export settlement rules for export SettlementDetailID = '
				+convert(varchar(50), @SettlementDetailID),
				@Rez = 1
		RETURN @Rez
	END
	

	SELECT @msg = '000. OK', @Rez = 0
	RETURN @Rez

END
