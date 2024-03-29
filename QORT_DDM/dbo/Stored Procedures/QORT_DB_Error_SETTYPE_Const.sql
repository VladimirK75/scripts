CREATE procedure [dbo].[QORT_DB_Error_SETTYPE_Const] @FromDate Date
                                           , @ToDate   Date
as
    begin
	SET NOCOUNT OFF
     SELECT
 t.id as TradeID
,t.QUIKClassCode
,ts.Name as TSName
,CHOOSE(ISNULL(IIF(tss.IsMarket = 'y', IIF(f.FirmShortName= 'НКО НКЦ (АО)' COLLATE Latin1_General_100_CI_AS_KS_WS , 3, 4), CHOOSE(t.SS_Const, null, 4, 2, 2)), 1) 
,'None','OTC','CCP','CS')
as Script_SETTYPE
,CHOOSE(t.SETTYPE_Const,'None','OTC','CCP','CS') as Qort_SETTYPE
,f.FirmShortName as CP_Firm_ShortName
FROM QORT_DB_PROD.dbo.Trades t WITH (NOLOCK)
INNER JOIN QORT_DB_PROD.dbo.TSSections ts WITH(NOLOCK) ON ts.id = t.TSSection_ID
INNER JOIN QORT_DB_PROD.dbo.Tss tss WITH(NOLOCK) ON tss.id = ts.TS_ID
LEFT JOIN QORT_DB_PROD.dbo.Firms f WITH(NOLOCK) ON f.id = IIF(t.CpFirm_ID > 0, t.CpFirm_ID, ts.CPFirm_ID)
WHERE 1=1
AND t.TradeDate BETWEEN CONVERT(VARCHAR(8), @FromDate, 112) AND CONVERT(VARCHAR(8), @ToDate, 112)
AND t.Enabled = 0
AND t.NullStatus = 'n'
AND ISNULL(t.SETTYPE_Const, 0) <> ISNULL(IIF(tss.IsMarket = 'y', IIF(f.FirmShortName= 'НКО НКЦ (АО)' COLLATE Latin1_General_100_CI_AS_KS_WS  , 3, 4), CHOOSE(t.SS_Const, null, 4, 2, 2)), 1)
ORDER BY 1
    end
