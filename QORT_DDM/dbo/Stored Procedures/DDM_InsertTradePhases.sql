CREATE procedure [dbo].[DDM_InsertTradePhases] 
                @PC_Const         int
              , @Trade_SID        bigint
              , @BackID           varchar(64)
              , @Infosource       varchar(64)
              , @SettlementDate   datetime
              , @LegalEntity      varchar(6)
              , @GetLegalEntity   varchar(6)      = null
              , @CommissionID     bigint          = null
              , @LoroAccount      varchar(6)      = null
              , @NostroAccount    varchar(50)     = null
              , @GetLoroAccount   varchar(6)      = null
              , @GetNostroAccount varchar(50)     = null
              , @Issue            varchar(25)
              , @Amount           decimal(38, 14)
              , @Direction        smallint
              , @msg              nvarchar(4000) output
              , @ChargeType       varchar(50)     = null
              , @NetSettlementID  varchar(32)     = null
as
    begin
        select @msg = '500. Internal Server Error'
        if nullif(@Trade_SID, 0) is null
            begin
                select @msg = '400. Bad Request. Field Trade_SystemID=@Trade_SID must be specified but set as EMPTY'
                return
        end
        declare 
               @SettlementDateInt  int
             , @IssueReference     varchar(50)
             , @SystemID           float       = null
             , @Asset_ShortName    varchar(48)
             , @Currency_ShortName varchar(48)
             , @RowID              float       = null
             , @IEC_ID             float
             , @PhaseCheck         int
             , @PhaseCheckMinor    int
             , @IsCanceled         varchar(1)
             , @IsProcessed        smallint
             , @ET_Const           smallint = 2
        select @SettlementDateInt = isnull(year(@SettlementDate) * 10000 + month(@SettlementDate) * 100 + day(@SettlementDate), 0)
             , @Issue = replace(@Issue, 'RUB', 'RUR')
             , @LoroAccount = isnull(@LoroAccount, @LegalEntity)
        select @Asset_ShortName = ShortName
             , @Currency_ShortName = iif(AssetType_Const = 3, ShortName, null) /* Для этапов по деньгам*/
          from QORT_DB_PROD..Assets with(nolock)
         where Marking = @Issue
        select @RowID = p.ID
             , @SystemID = p.SystemID
             , @IsCanceled = isnull(p.IsCanceled, 'n')
             , @IsProcessed = p.IsProcessed
             , @Currency_ShortName = isnull(@Currency_ShortName, CurrencyAsset_ShortName)
             , @CommissionID = isnull(@CommissionID, Commission_SID)
             , @PhaseCheck = binary_checksum(p.BackID, p.[Date], p.InfoSource, p.QtyBefore, p.QtyAfter, p.PhaseAccount_ExportCode, isnull(p.GetAccount_ExportCode,''), p.SubAcc_Code, isnull(p.GetSubAcc_Code,''), isnull(p.PhaseAsset_ShortName,''), p.CurrencyAsset_ShortName, p.Commission_SID, p.Comment, isnull(p.PDocNum,''))
          from QORT_TDB_PROD.dbo.Phases p with(nolock)
         where p.Trade_SID = @Trade_SID
               and p.BackID = @BackID
               and not exists (select 1
                                 from QORT_TDB_PROD.dbo.Phases p2 with(nolock)
                                where p2.Trade_SID = p.Trade_SID
                                      and p2.BackID = p.BackID
                                      and p2.id > p.id) 
        if @RowID > 0 /* Если уже есть безошибочная запись с такими характеристиками - пропустить её */
           and @IsCanceled = 'n'
           and @IsProcessed < 4
           and @PhaseCheck = binary_checksum(@BackID, @SettlementDateInt, @InfoSource, cast(@Amount as float), cast(@Direction as float), @NostroAccount, isnull(@GetNostroAccount,''), @LoroAccount, isnull(@GetLoroAccount,''), @Asset_ShortName, @Currency_ShortName, cast(isnull(@CommissionID, -1) as float), @ChargeType, isnull(@NetSettlementID,''))
            begin
                select @msg = concat('304. Phase is already exists for the BackID = ', @BackID)
                return
        end
        if @SystemID < 0 /* если фаза ранее загрузилась с ошибкой - update и переобработать */
           and @IsProcessed > 3

           begin
            update QORT_TDB_PROD.dbo.Phases with(rowlock)
            set PC_Const = @PC_Const
              , SystemID = iif(@SystemID > 0, @SystemID, -1 * @RowID)
              , InfoSource = @Infosource
              , BackID = @BackID
              , [Date] = @SettlementDateInt
              , [Time] = 0
              , Trade_SID = @Trade_SID
              , QtyBefore = @Amount
              , QtyAfter = @Direction
              , GetAccount_ExportCode = @GetNostroAccount
              , SubAcc_Code = @LoroAccount
              , GetSubAcc_Code = @GetLoroAccount
              , IsProcessed = 1
              , PhaseAsset_ShortName = @Asset_ShortName
              , PhaseAccount_ExportCode = @NostroAccount
              , CurrencyAsset_ShortName = @Currency_ShortName
              , Comment = @ChargeType
              , Commission_SID = cast(isnull(@CommissionID, -1) as float)
              , PDocType_Name = iif(@NetSettlementID is null, '', 'Неттинг')
              , PDocNum = @NetSettlementID
              , ET_Const = @ET_Const
              , IsExecByComm = 'Y'
              , BlockCommissionOnTrade_BackID = iif(@PC_Const not in (3,4,5,7), nullif(@BackID,''), null)
             where id = @RowID
           end
           else
            begin /* во всех остальных случаях ставить новую */
            print concat('insert QORT_TDB_PROD.dbo.Phases, @ET_Const=',@ET_Const)
                set @RowID = null
             
                while @RowID is null
                    exec QORT_TDB_PROD..P_GenFloatValue @RowID output
                                                      , 'phases_table'
                insert into QORT_TDB_PROD.dbo.Phases ( id
                                                     , SystemID
                                                     , PC_Const
                                                     , InfoSource
                                                     , BackID
                                                     , [Date]
                                                     , [Time]
                                                     , Trade_SID
                                                     , QtyBefore
                                                     , QtyAfter
                                                     , GetAccount_ExportCode
                                                     , SubAcc_Code
                                                     , GetSubAcc_Code
                                                     , IsProcessed
                                                     , PhaseAsset_ShortName
                                                     , PhaseAccount_ExportCode
                                                     , CurrencyAsset_ShortName
                                                     , Comment
                                                     , Commission_SID
                                                     , BlockCommissionOnTrade_BackID
                                                     , PDocType_Name
                                                     , PDocNum
                                                     , ET_Const
                                                     , IsExecByComm ) 
                values(
                       @RowID,  -1 * @RowID, @PC_Const, @InfoSource, @BackID, @SettlementDateInt, 0, @Trade_SID, @Amount, @Direction, @GetNostroAccount, @LoroAccount, @GetLoroAccount, 1, @Asset_ShortName, @NostroAccount, @Currency_ShortName, @ChargeType, cast(isnull(@CommissionID, -1) as float), iif(@PC_Const not in (3,4,5,7), nullif(@BackID,''), null), iif(@NetSettlementID is null, '', 'Неттинг'), @NetSettlementID,  @ET_Const,'Y');
                /* START - generate the new IEC_ID for this action */
        end
        exec QORT_DDM..DDM_ImportExecutionCommands @TC_Const = 7
                                                 , @Oper_ID = @RowID
                                                 , @Comment = @BackID
                                                 , @SystemName = 'DDM_InsertTradePhases'
        select @msg = '000. Phase @BackID = ' + @BackID + ' was inserted for Trade_SID = ' + cast(@Trade_SID as varchar(50))
        return
    end
