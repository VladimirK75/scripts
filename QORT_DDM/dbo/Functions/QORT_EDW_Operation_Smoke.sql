create   function dbo.QORT_EDW_Operation_Smoke(@DateFrom int
                                          , @DateTo   int)
returns table
as
     return
     select TransactionID = E.SystemID
          , EventTime = dateadd(hour, -3, ( select QORT_DDM.dbo.DDM_GetDateTimeFromInt( E.ModifiedDate, E.ModifiedTime ) ))
          , EventStatus = iif(isnull(isCanceled, 'n') <> 'y', 'Active', 'Canceled')
          , TransactionCapacity = iif(E.SubaccOwnerFirm_BOCode = 'RENBR', 'Principal', 'Agency')
          , [ChargeType] = iif(cc.Name like '%SEC%', 'SECURITY',
                                             case
                                                 when E.CT_Const in(51, 52) then 'VARIATION_MARGIN'
                                                  else coalesce(nullif(QORT_DDM.dbo.QORT_GetListNumber( e.Comment2, '/', 3 ), ''), nullif(QORT_DDM.dbo.QORT_GetListNumber( e.Comment, '/', 3 ), ''), 'CHARGE_FEE')
                                             end)
          , TradeDate = convert(date, ( select QORT_DDM.dbo.DDM_GetDateTimeFromInt( E.RegistrationDate, 0 ) ))
          , [Settlement.ActualSettlementDate] = convert(date, ( select QORT_DDM.dbo.DDM_GetDateTimeFromInt( nullif(E.Date, 0), 0 ) ))
          , [Settlement.EventStatus] = iif(isnull(isCanceled, 'n') <> 'y', 'Active', 'Canceled')
          , [Settlement.Type] = isnull(nullif(QORT_DDM.dbo.QORT_GetListNumber( e.Comment2, '/', 2 ), ''), iif(cc.Name like '%SEC%', 'SECURITY', 'CASH'))
          , [Issue.ShortName] = isnull(nullif(nullif(E.Asset_ShortName, ''), e.CurrencyAsset_ShortName), e.SideAsset_ShortName)
          , Currency = replace(e.CurrencyAsset_ShortName, 'RUR', 'RUB')
          , E.Comment
          , E.Comment2
          , E.BackID
          , Is_CA = case
                        when e.InfoSource != 'BackOffice'
                             and e.CT_Const in(4, 5, 25, 59)
                             or patindex('%/CA/%', e.Comment) + patindex('%/DIVIDEND/%', e.Comment) + patindex('%/CORPORATE_ACTIONS/%', e.Comment) = 0 then 0
                         else 1
                    end
       from QORT_TDB_PROD..ExportCorrectPositions E with(nolock)
       inner join QORT_DB_PROD..CT_Const cc with(nolock) on E.CT_Const = cc.[Value]
      where 1 = 1
            and E.ModifiedDate between @DateFrom and @DateTo
