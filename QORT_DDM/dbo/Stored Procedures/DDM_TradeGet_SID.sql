create   procedure dbo.DDM_TradeGet_SID 
                 @SettlementDetailID bigint
               , @TradeSource        varchar(25)
               , @Infosource         varchar(100) output
               , @Trade_SID          numeric(18, 0) output
               , @msg                nvarchar(4000) output
as
    begin
        declare 
               @ExternalReference varchar(255)
             , @TradeNumID        float
             , @StlExternalID     varchar(255)
             , @LoroAccount       varchar(10)
        if @TradeSource = 'QORT'
            begin
                select @StlExternalID = s.ExternalID
                     , @ExternalReference = s.TradeGID
                     , @Trade_SID = convert(float, rtrim(substring(s.TradeGID, patindex('%[0-9]%', s.TradeGID), 255)))
                     , @Infosource = 'BackOffice'
                  from QORT_DDM..ExportedTradeSettlementDetails sd with(nolock)
                  inner join QORT_DDM..ExportedTradeSettlement s with(nolock) on sd.SettlementID = s.ID
                 where sd.ID = @SettlementDetailID
            end
           else
            begin
                select @StlExternalID = s.ExternalID
                     , @ExternalReference = s.TradeGID
                     , @TradeNumID = convert(float, s.ExternalTradeID)
                     , @LoroAccount = isnull(sd.LoroAccount, s.LegalEntity)
                     , @Infosource = 'BackOffice'
                  from QORT_DDM..ImportedTradeSettlementDetails sd with(nolock)
                  inner join QORT_DDM..ImportedTradeSettlement s with(nolock) on sd.SettlementID = s.ID
                 where sd.ID = @SettlementDetailID
                select @Trade_SID = t.SystemID
                  from QORT_TDB_PROD..Trades t with(nolock) /* Если сделка не обработана в QORT, нет смысла грузить ее Settlement */
                 where IsRepo2 = 'n'
                       and t.NullStatus = 'n'
                       and @LoroAccount = t.SubAcc_Code /* Клиентские проповые сделки */
                       and AgreeNum = @ExternalReference
                       and TT_Const <> 9 /* MBK. Kostyl filtracii!!!!!*/
                if isnull(@Trade_SID, 0) = 0
                    select @Trade_SID = t.SystemID
                      from QORT_TDB_PROD..Trades t with(nolock) /* Если сделка не обработана в QORT, нет смысла грузить ее Settlement */
                     where IsRepo2 = 'n'
                           and t.NullStatus = 'n'
                           and t.SubAcc_Code = @LoroAccount
                           and t.TradeNum = @TradeNumID
                           and TT_Const <> 9 /* MBK. Kostyl filtracii!!!!!*/
            end
        select @msg = case
                           when isnull(@Trade_SID, 0) = 0 then '404. Trade_SID not found for '+@TradeSource+' Trade. @ExternalReference = '+@ExternalReference+' and TradeNum = '+ltrim(str(@TradeNumID, 16))
                         else '000. Ok'
                      end
    end
