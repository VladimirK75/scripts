create   procedure dbo.DDM_ExportedTranSettlementProcess 
                 @SettlementDetailID bigint
               , @Action             nvarchar(7) /* New and Cancel only*/
               , @msg                nvarchar(4000) output
as
    begin
        declare 
               @Rez               int
             , @BackID            varchar(100)
             , @Infosource        varchar(100)
             , @MovementID        bigint
             , @SettlementID      bigint
             , @STLRuleID         bigint
             , @ExternalID        varchar(255)
             , @ExternalReference varchar(255)
             , @Capacity          varchar(6)
             , @Direction         smallint
             , @SettlementDate    datetime
             , @SettlementDateInt int
             , @CPDateInt         int
             , @CPRegDateInt      int
             , @CT_Const          int
             , @SystemID          varchar(255)
             , @SubAccCode        varchar(255)
             , @AccountCode       varchar(255)
             , @CommissionName    varchar(255)
             , @Asset             varchar(255)
             , @StlExternalID     bigint
             , @ReversedID        bigint
             , @RuleID            bigint
             , @StlType           varchar(6)
             , @StlDateType       varchar(50)
             , @CharPos           int
        select @msg = '000. Ok'
        select @SettlementID = sd.SettlementID
             , @StlType = sd.Type
             , @ReversedID = isnull(s.ReversedID, 0)
             , @StlExternalID = s.ExternalID
             , @ExternalReference = s.TxnGID
             , @Capacity = sd.Type
          from QORT_DDM..ExportedTranSettlementDetails sd with(nolock)
          inner join QORT_DDM..ExportedTranSettlement s with(nolock) on sd.SettlementID = s.ID
         where sd.ID = @SettlementDetailID
        if @ReversedID > 0
           or @Action = 'Cancel'
            begin
                select @msg = '001. Unsettle and Reversal are prohibited for QORT Objects'
                return
            end
        select @CharPos = patindex('%[0-9]%', @ExternalReference)
        select @SystemID = substring(@ExternalReference, @CharPos, len(@ExternalReference)-@CharPos+1)
        select @BackID = c.BackID
             , @CT_Const = c.CT_Const
             , @CPDateInt = c.Date
             , @CPRegDateInt = c.RegistrationDate
             , @SubAccCode = c.Subacc_Code
             , @AccountCode = c.Account_ExportCode
             , @Asset = c.Asset_ShortName
             , @CommissionName = c.Commission_Name
          from QORT_TDB_PROD..ExportCorrectPositions c with(nolock)
         where c.SystemID = cast(@SystemID as float)
        if isnull(@BackID, '') = ''
            begin
                select @msg = '002. CorrectPosition not found for SystemID = '+@SystemID
                return
            end
        if isnull(@CPDateInt, 0) > 0
            begin
                select @msg = '003. CorrectPosition already settled. SystemID = '+@SystemID
                return
            end
        select top 1 @StlDateType = sr.SettlementDate
          from QORT_DDM..ExportCP_SettlementRules es with(nolock)
             , QORT_DDM..SettlementRules sr with(nolock)
         where(es.CT_Const = @CT_Const
               or es.CT_Const = 0)
              and es.STLRuleID = sr.STLRuleID
              and sr.Capacity = @Capacity
              and (es.StartDate < getdate()
                   or es.StartDate is null)
              and (es.EndDate >= getdate()
                   or es.EndDate is null)
              and (@SubAccCode like es.Subacc
                   or es.Subacc is null)
              and (@AccountCode like es.Account
                   or es.Account is null)
              and (@Asset like es.Asset
                   or es.Asset is null)
              and (@CommissionName like es.Commission_Name
                   or es.Commission_Name is null)
              and (@Direction = es.Direction
                   or es.Direction is null) order by es.Priority
        if isnull(@StlDateType, '') = ''
            begin
                select @msg = '004. No settlement Rule '
                return
            end
        select @SettlementDate = case @StlDateType
                                      when 'FOAvaliableDate' then st.FOAvaliableDate
                                      when 'ActualSettlementDate' then st.ActualSettlementDate
                                      when 'AvaliableDate' then st.AvaliableDate
                                 end
          from QORT_DDM..ExportedTranSettlement st with(nolock)
         where ID = @SettlementID
        select @SettlementDateInt = isnull(year(@SettlementDate) * 10000 + month(@SettlementDate) * 100 + day(@SettlementDate), 0)
        if isnull(@SettlementDateInt, 0) > 0
            insert into QORT_TDB_PROD..CorrectPositions ( id
                                                        , BackID
                                                        , [Date]
                                                        , [Time]
                                                        , RegistrationDate
                                                        , Subacc_Code
                                                        , Account_ExportCode
                                                        , GetSubacc_Code
                                                        , GetAccount_ExportCode
                                                        , CT_Const
                                                        , Asset
                                                        , Size
                                                        , Comment
                                                        , Comment2
                                                        , IsProcessed
                                                        , ET_Const ) 
            select-1
                , c.BackID
                , @SettlementDateInt
                , c.Time
                , c.RegistrationDate
                , c.Subacc_Code
                , c.Account_ExportCode
                , c.GetSubaccCode
                , c.GetAccountCode
                , c.CT_Const
                , c.Asset_ShortName
                , c.Size
                , c.Comment
                , c.Comment2
                , 1
                , 4
              from QORT_TDB_PROD..ExportCorrectPositions c with(nolock)
             where c.SystemID = cast(@SystemID as float)
        return
    end
