create   procedure dbo.DDM_InsertClientInstrByOrder 
                 @OrderID bigint
               , @Status  varchar(50) /* as in DDM (Draft, Executing, Executed, RequestForCancel, Cancelled)*/
               , @msg     nvarchar(4000) output
as
    begin
        set nocount on
        select @msg = '000. Ok'
        if exists (select 1
                     from QORT_DDM..NonTradingOrders with(nolock)
                    where ID = @OrderID) 
            begin
                if not exists (select 1
                                 from QORT_DDM..NonTradingOrders nto with(nolock)
                                 inner join QORT_DDM..NonTradingOrders nto2 with(nolock) on nto.ExternalID = nto2.ExternalID
                                                                                            and nto.SourceLoro = nto2.SourceLoro
                                                                                            and nto.Amount = nto2.Amount
                                                                                            and nto.Currency = nto2.Currency
                                                                                            and nto2.ID < nto.ID
                                where nto.ID = @OrderID) 
                    exec dbo.DDM_InsertClientInstr @OrderID = @OrderID
                                                 , @Status = @Status
                                                 , @msg = @msg output
                   else
                    select @msg = '416. OrderID '+@OrderID+' was processed early. Processing was stopped.'
            end
           else
            begin
                select @msg = '404. OrderID '+@OrderID+' is not exists. Processing was stopped.'
            end
        return
    end
