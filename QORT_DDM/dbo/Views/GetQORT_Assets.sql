CREATE VIEW dbo.GetQORT_Assets
AS
SELECT        a.id AS QORT_ID, a.Marking AS GRDB_ID, a.ShortName AS SecCode, isnumeric(a.Marking) AS IsIntegrated, a.ISIN, a.ViewName, FaceCurrency.ShortName AS FaceCurrency, a.BaseValue, a.BaseValueOrigin, 
                         tc.[Description(eng.)] AS Basis, aac.[Description(eng.)] AS AssetClass, STUFF(STUFF(a.CancelDate, 7, 0, '-'), 5, 0, '-') AS CancelDate, a.IsTrading
FROM            QORT_DB_PROD.dbo.Assets AS a WITH (nolock) LEFT OUTER JOIN
                         QORT_DB_PROD.dbo.Assets AS FaceCurrency WITH (nolock) ON FaceCurrency.id = a.BaseCurrencyAsset_ID LEFT OUTER JOIN
                         QORT_DB_PROD.dbo.TBT_Const AS tc WITH (nolock) ON tc.Value = a.TBT_Const LEFT OUTER JOIN
                         QORT_DB_PROD.dbo.AssetClass_Const AS aac WITH (nolock) ON aac.Value = a.AssetClass_Const
WHERE        (a.Enabled = 0) AND (a.AssetType_Const = 1)
