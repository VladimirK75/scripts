CREATE procedure [dbo].[QORT_GetOrders4Confirmations] @OperDate datetime
as
    begin
        set nocount on;
        select o.id
             , o.OrderDate
             , BuySell = choose(o.BuySell, 'Покупка', 'Продажа')
             , o.Security_ID
             , o.Qty
             , putCur.ShortName
			 , PayCurrency = payCur.ShortName
             , o.Volume
             , o.Price
          from QORT_DB_PROD.dbo.Orders o with (nolock, index = PK_Orders)
          inner join QORT_DDM.dbo.QORT_GetLoroList( 'RESEC' ) sub on sub.Subacc_ID = o.Subacc_ID
          inner join QORT_DB_PROD.dbo.Assets payCur with(nolock) on payCur.id = o.PayAsset_ID
          inner join QORT_DB_PROD.dbo.Securities s with(nolock) on s.id = o.Security_ID
          inner join QORT_DB_PROD.dbo.Assets putCur with(nolock) on s.Asset_ID = putCur.id
         where o.OrderDate = convert(int,format(@OperDate,'yyyyMMdd'))
               and o.DM_Const = 3
    end
