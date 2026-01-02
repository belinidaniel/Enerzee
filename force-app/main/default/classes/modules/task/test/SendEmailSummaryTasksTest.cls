@isTest
public class SendEmailSummaryTasksTest {
    @isTest
    static void sendEmail(){
		List<User> Usuario = [SELECT Id, Name, Email, UserName FROM USER WHERE IsActive = TRUE LIMIT 1];
        
        If(!Usuario.IsEmpty()){
        	For(User usr : Usuario){
        		Task Tarefa = new Task(
        			Subject = 'Ligação de follow-up - Teste',
            		OwnerId = usr.Id,
            		Priority = 'Normal',
            		ActivityDate = Date.Today()
        		);
            
            	insert Tarefa;
        	}
        
        	SendEmailSummaryTasks.sendEmail(Usuario);    
        }
        
    }

}