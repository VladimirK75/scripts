/***********************
Author: Kirill
Date:   2019-11-01
***********************/
CREATE    procedure [dbo].[QORT_TradeInstr_in_Trades] 	@Date date,
														@Num nvarchar(20),
														@Subacc nvarchar(10),
														@Trade_id int
														--@Comment nVarchar(400) output
as 
BEGIN 	

declare @Instr_id int
		

select @Instr_id=ti.id
from QORT_DB_PROD..TradeInstrs ti with(nolock)
	join QORT_DB_PROD..Subaccs s with(nolock)
	on s.OwnerFirm_ID=ti.OwnerFirm_ID
where ti.date=Convert(varchar(10),@Date,112)
and ti.RegisterNum=@Num
and s.SubAccCode=@Subacc
and ti.Enabled=0
and ti.date <= (select TradeDate 
				from QORT_DB_PROD..Trades with(nolock)
				where id=@Trade_id)

update QORT_DB_PROD..Trades 
set TradeInstr_ID=@Instr_id
where Id=@Trade_id

select Comment = concat('TradeInstr ' , isnull(@Instr_id,-1) , ' joined with Trades ' , @Trade_id)

end

--exec [QORT_DDM].dbo.[QORT_TradeInstr_in_Trades] '2019-10-10','01','RB0084',147860490
