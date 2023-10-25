CREATE Proc [dbo].[sp_SWIFT_ACK_Input_NiFi] (@TradeReference nvarchar(256))
as 
begin

declare @Subj varchar(255)

set @Subj ='TEST' + @TradeReference;

EXEC msdb.dbo.sp_send_dbmail
		@profile_name		= 'QORTMonitoring',
		@recipients		= 'aleonov@rencap.com',
		@subject			= @Subj


end
