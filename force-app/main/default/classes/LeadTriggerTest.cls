/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 10-07-2025
 * @last modified by  : Daniel Belini
**/
@isTest
public class LeadTriggerTest {
    public static Id QualificarClienteRT = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName().get('QualificacaodeClientes').getRecordTypeId();
    public static Id QualificarConsultorRT = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName().get('QualificacaodeConsultores').getRecordTypeId();
    
	@isTest
    static void QualificarConsultorRTTest(){
        Map<Id, List<Task>> LeadIdToTaskList = new Map<Id, List<Task>>();
        
        Lead leadCriar = new Lead(FirstName='Lionel',LastName='Messi',Company='Teste',RecordTypeId=QualificarConsultorRT, Email='teste@teste.com');
        insert leadCriar;
        
        ID IdLead = leadCriar.Id;
        
        List<Task> tasks = [
            SELECT  Id, Status, WhoId
            FROM    Task
            WHERE   WhoId = :IdLead
        ];
        
        for (Task taskCheck : tasks){
          taskCheck.Status = TaskUtils.STATUS_CONCLUIDO;
        }
        update tasks;
        
        Lead LeadAtualizar = [SELECT Status FROM Lead WHERE Id =: IdLead LIMIT 1];
		LeadAtualizar.Status = 'Unqualified';
		Update LeadAtualizar;
        
    }
    
    @isTest
    static void QualificarClienteRTTest(){
        Consultor__c consultorCriar = new Consultor__c( 
            Name = 'Consultor Exemplo', 
            Ativo__c = true 
        ); 
        insert consultorCriar;

        Lead leadCriar = new Lead(FirstName='Lionel',LastName='Messi',Company='Teste',RecordTypeId=QualificarClienteRT);
        leadCriar.consultorRegional__c = consultorCriar.Id;
        leadCriar.FalarComAgente__c = true;
        insert leadCriar;
        
        ID IdLead = leadCriar.Id;
        Lead LeadAtualizar = [SELECT Status FROM Lead WHERE Id =: IdLead LIMIT 1];
        
        try {
			LeadAtualizar.Status = 'Qualified';
            leadCriar.FalarComAgente__c = true;
			Update LeadAtualizar;
        } catch(Exception e){
            System.debug('Erro capturado: ' + e.getMessage());
        }
        
        List<Task> tasks = [
            SELECT  Id, Status, WhoId
            FROM    Task
            WHERE   WhoId = :IdLead
        ];
        
        for (Task taskCheck : tasks){
          taskCheck.Status = TaskUtils.STATUS_CONCLUIDO;
        }
        update tasks;
        

        
        LeadAtualizar = [SELECT Id, Status, Phone, Email, CPFCNPJ__c, PostalCode, City, State, ConsultorRegional__c FROM Lead WHERE Id = :IdLead LIMIT 1];
        LeadAtualizar.Email = 'teste@teste.com';
        LeadAtualizar.Phone = '66999999999';
        LeadAtualizar.CPFCNPJ__c = '99999999999';
        LeadAtualizar.PostalCode = '22450050';
        LeadAtualizar.City = 'Rio de Janeiro';
        LeadAtualizar.State = 'Rio de Janeiro';
        LeadAtualizar.ConsultorRegional__c = consultorCriar.Id;
        LeadAtualizar.Status = 'Qualified';
		Update LeadAtualizar;
        
    }
}