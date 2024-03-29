create procedure dbo.DDM_TradeAddCorrPos 
                 @ExternalID       varchar(255)
               , @Trade_GID        varchar(255)
               , @ExternalTradeID  varchar(255)
               , @CT_Const         int
               , @SettlementDate   datetime
               , @ExternalID2      varchar(255)    = null
               , @Amount           decimal(38, 14)
               , @Currency         varchar(3)
               , @Direction        smallint
               , @LoroAccount      varchar(6)
               , @NostroAccount    varchar(50)
               , @GetLoroAccount   varchar(6)      = null
               , @GetNostroAccount varchar(50)     = null
               , @LegalEntity      varchar(6)
               , @GetLegalEntity   varchar(6)
               , @Infosource       varchar(64)
               , @msg              nvarchar(4000) output
as
    begin
        declare 
               @BackID            varchar(64)
             , @SettlementDateInt bigint
             , @IgnoreMv1         tinyint
             , @IgnoreMv2         tinyint
             , @TradeTimeInt      bigint      = 193000000
             , @Size              float
             , @IsProcessed       smallint    = 1
             , @ET_Const          smallint    = 4
             , @Price             float       = 0
             , @Accrued           float       = 0
        select @msg = '000. Ok'
        select @BackID = @ExternalTradeID+'/'+@ExternalID
             , @SettlementDateInt = isnull(convert(int, format(@SettlementDate, 'yyyyMMdd')), 0)
             , @Size = round(@Direction * @Amount, 2)
             , @IgnoreMv1 = iif(nullif(@NostroAccount, '') is null, 1, 0)
             , @IgnoreMv2 = iif(nullif(@GetNostroAccount, '') is null, 1, 0)
        if isnull(@IgnoreMv1, 0) > 0
           and (isnull(@IgnoreMv2, 0) > 0
                or isnull(@ExternalID2, '') = '')
            begin
                select @msg = '022. Settlement filtered out by LORO or Nostro '
                return
            end
        if isnull(@ExternalID2, '') <> ''
            begin
                if exists (select 1
                             from QORT_TDB_PROD..CorrectPositions cp with(nolock)
                            where cp.BackID like @ExternalTradeID+'/'+@ExternalID2
                                  and cp.IsProcessed < 4) 
                    begin
                        select @msg = '000. CorrectPosition already exists. BackID = '+@ExternalTradeID+'/'+@ExternalID2
                        return
                    end
            end
        if @LoroAccount is null
            select @LoroAccount = @LegalEntity
        select @LoroAccount = isnull(SubAccount, @LoroAccount)
             , @IgnoreMv1 = isnull(@IgnoreMv1, 0) + isnull(Ignore, 0)
          from QORT_DDM..ClientLoroAccount with(nolock)
         where @LoroAccount like LoroAccount
               and (isnull(NostroAccount, '') = ''
                    or @NostroAccount like NostroAccount)
        /* Проверяем переводы и транзакции на импорт некорректных лоро */
        if isnull(@IgnoreMv2, 0) > 0
           and isnull(@IgnoreMv1, 0) = 0
            select @GetLoroAccount = null
                 , @GetNostroAccount = null
        if isnull(@IgnoreMv1, 0) > 0
           and isnull(@IgnoreMv2, 0) = 0
            begin
                select @LoroAccount = @GetLoroAccount
                     , @NostroAccount = @GetNostroAccount
                     , @Size = -1 * @Size
                     , @GetLoroAccount = null
                     , @GetNostroAccount = null
            end
        if abs(isnull(@Size, 0)) > 0
            begin
                insert into QORT_TDB_PROD.dbo.CorrectPositions ( id
                                                               , BackID
                                                               , [Date]
                                                               , [Time]
                                                               , Subacc_Code
                                                               , Account_ExportCode
                                                               , Comment
                                                               , CT_Const
                                                               , Asset
                                                               , Size
                                                               , Price
                                                               , CurrencyAsset
                                                               , IsProcessed
                                                               , Accrued
                                                               , ET_Const
                                                               , RegistrationDate
                                                               , GetSubacc_Code
                                                               , GetAccount_ExportCode
                                                               , Comment2
                                                               , Infosource
                                                               , IsInternal ) 
                values ( -1
                       , @BackID
                       , @SettlementDateInt
                       , @TradeTimeInt
                       , @LoroAccount
                       , @NostroAccount
                       , @Trade_GID
                       , @CT_Const
                       , @Currency
                       , @Size
                       , @Price
                       , @Currency
                       , @IsProcessed
                       , @Accrued
                       , @ET_Const
                       , @SettlementDateInt
                       , @GetLoroAccount
                       , @GetNostroAccount
                       , @Trade_GID
                       , @Infosource
                       , 'N' ) 
                select @msg = '000. CP @BackID = '+@BackID+' is inserted. @Size: '+cast(@Size as varchar(50))+' @SettlementDateInt: '+cast(@SettlementDateInt as varchar(50))
            end
           else
            select @msg = '000. CP @BackID = '+@BackID+' was not inserted because Size = 0. @Size: '+cast(@Size as varchar(50))+' @SettlementDateInt: '+cast(@SettlementDateInt as varchar(50))
        return
    end
