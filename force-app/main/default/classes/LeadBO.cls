/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 10-17-2025
 * @last modified by  : Daniel Belini
**/
public class LeadBO {
	public static Id QualificarClienteRT = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName().get('QualificacaodeClientes').getRecordTypeId();
    public static Id QualificarClienteQUEUE = getQueueIdByName('QualificacaodeClientes');

    public static Id QualificarConsultorRT = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName().get('QualificacaodeConsultores').getRecordTypeId();
    public static Id QualificarConsultorQUEUE = getQueueIdByName('Consultor');
    
    public static void checkTasksConclusionBeforeStatusChange(List<Lead> newRecordList, Map<Id, Lead> oldMap){
        
        Map<Id, List<Task>> LeadIdToTaskList = new Map<Id, List<Task>>();
        
        Id voUserId = [
            SELECT  Id
            FROM    User
            WHERE   Username like 'integracao@lab065.com'
            LIMIT   1
        ].Id;
        
        for(Task task : [
            SELECT  Id, Status, WhoId
            FROM    Task
            WHERE   WhoId IN :newRecordList
        ]){
            if(!LeadIdToTaskList.containsKey(task.WhoId)){
                LeadIdToTaskList.put(task.WhoId, new List<Task>());
            }
            LeadIdToTaskList.get(task.WhoId).add(task);
        }

        for(Lead lead : newRecordList){
            if(lead.RecordTypeId != QualificarConsultorRT && lead.RecordTypeId != QualificarClienteRT){
                continue;
            }
            
            //if(
                //lead.Status != 'Novo' &&
                //(lead.OwnerId == QualificarClienteQUEUE || lead.OwnerId == QualificarConsultorQUEUE)
            //){
            	//lead.addError('Um proprietário deve aceitar o lead antes de avançar de fase!');
                //break;
            //}
            	
            Lead oldLead = oldMap.get(lead.Id);
            if(
                lead.status != oldLead.status && 
                !LeadIdToTaskList.isEmpty() &&
                UserInfo.getUserId() != voUserId
            ){
                for(Task task : LeadIdToTaskList.get(lead.Id)){
                    if(!task.Status.equalsIgnoreCase(TaskUtils.STATUS_CONCLUIDO)){
                        // lead.addError('Todas as tarefas existentes para esse lead precisam estar concluídas antes de avançar de fase!');
                        // break;
                    }
                }
            }
        }
    }

    public static void LeadValidationHandler(List<Lead> newRecordList){
        for(Lead lead : newRecordList){
            if (lead.RecordTypeId == QualificarClienteRT && lead.Status == 'Qualified') {
                if (String.isBlank(lead.CPFCNPJ__c)) { 
                    lead.addError('O campo Documento é obrigatório! Insira ao menos um antes de converter o Lead.'); 
                }
                if (String.isBlank(lead.Email)) { 
                    lead.addError('O campo Email é obrigatório! Preencha antes de converter o Lead.'); 
                }
                if (String.isBlank(lead.Phone)) { 
                    lead.addError('O campo Telefone é obrigatório! Preencha antes de converter o Lead.'); 
                }
                /*if (String.isBlank(lead.PostalCode)) { 
                    lead.addError('O campo CEP é obrigatório! Preencha antes de converter o Lead.'); 
                }
                if (String.isBlank(lead.City)) { 
                    lead.addError('O campo Cidade é obrigatório! Preencha antes de converter o Lead.'); 
                }
                if (String.isBlank(lead.State)) { 
                    lead.addError('O campo Estado é obrigatório! Preencha antes de converter o Lead.'); 
                }*/
                if (String.isBlank(lead.ConsultorRegional__c)) { 
                    lead.addError('O campo Consultor Regional é obrigatório! Preencha antes de converter o Lead.'); 
                }
            } else if (lead.RecordTypeId == QualificarConsultorRT){
                if(lead.Status == 'Aguardando Pagamento' || lead.Status == 'Qualified') {
                    if (String.isBlank(lead.ConsultorRegional__c)) { 
                        lead.addError('O campo Consultor Regional é obrigatório! Preencha antes de alterar para Aguardando Pagamento.'); 
                    }
                    if (String.isBlank(lead.CPFCNPJ__c)) { 
                        lead.addError('O campo CPF/CNPJ é obrigatório! Preencha antes de alterar para Aguardando Pagamento.'); 
                    }
                    if (String.isBlank(lead.Email)) { 
                        lead.addError('O campo Email é obrigatório! Preencha antes de alterar para Aguardando Pagamento.'); 
                    }
                }
            }
       }
    }
    
    public static void sendClientRecordToProposalGenerator(List<Lead> newRecordList){
        Set<Id> clienteIds = new Set<Id>();
        
        for(Lead lead : newRecordList){
            if(lead.RecordTypeID == QualificarClienteRT && lead.IsConverted){
                clienteIds.add(lead.Id);
            }
        }
        
        if(!clienteIds.isEmpty()){
        	IntegracaoGeradorPropostas.sendCliente(clienteIds);
        }
        
    }
    
    public static Id getQueueIdByName(String queueDeveloperName) { 
        Group queue = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = :queueDeveloperName LIMIT 1]; 
        return queue.Id; 
    }
    
    public static void setRecordTypeAccount(List<Lead> newRecordList){
        for(Lead lead : newRecordList){
            if (
                lead.IsConverted && 
                lead.ConvertedAccountId != null && 
                lead.RecordTypeId == QualificarClienteRT &&
                lead.CPFCNPJ__c != null
            ) 
            {
                String Document = lead.CPFCNPJ__c.replaceAll('[^0-9]', '');
                String RecordTypeName = Document.length() > 11 ? 'ClientePessoaJuridica' : 'ClientePessoaFisica';
                Id recordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName =: RecordTypeName LIMIT 1].Id; 
                
                Account newAccount = [SELECT Id, RecordTypeId, Consultor__c, Email__c, CNPJ__c, CPF__c FROM Account WHERE Id = :lead.ConvertedAccountId LIMIT 1];
                
                newAccount.RecordTypeId = recordTypeId;
                newAccount.RazaoSocial__c = lead.Company;
                newAccount.Consultor__c = lead.ConsultorRegional__c;
                newAccount.Email__c = lead.Email;
                
                newAccount.ShippingStreet = lead.Street;
                newAccount.ShippingState = lead.State;
                newAccount.ShippingPostalCode = lead.PostalCode;
                newAccount.ShippingCity = lead.City;
                newAccount.NumeroRuaCobranca__c = lead.StreetNumber__c;
                newAccount.NumeroRuaEntrega__c = lead.StreetNumber__c;
                newAccount.BairroCobranca__c = lead.Bairro__c;
                newAccount.BairroEntrega__c = lead.Bairro__c;

                If(RecordTypeName == 'ClientePessoaJuridica'){
                    newAccount.CNPJ__c = Document.substring(0, 2) + '.' + Document.substring(2, 5) + '.' + Document.substring(5, 8) + '/' + Document.substring(8, 12) + '-' + Document.substring(12, 14);
                } else {
                    newAccount.CPF__c = Document.substring(0, 3) + '.' + Document.substring(3, 6) + '.' + Document.substring(6, 9) + '-' + Document.substring(9, 11);
                }

                update newAccount;
            }
        }
    }
    
    public static void createMessagingUser(List<Lead> newRecordList, Map<Id, Lead> oldMap){

        try{

            List<MessagingEndUser> messagingUsers = new List<MessagingEndUser>();
            Map<String, MessagingEndUser> endUserByKey = new Map<String, MessagingEndUser>();
            Map<String, Lead> leadByPhone = new Map<String, Lead>();

            List<MessagingChannel> channelsCustomer = [SELECT Id, masterlabel from MessagingChannel WHERE MasterLabel IN ('+55 11 4003-8344')];
            List<MessagingChannel> channelPartner = [SELECT Id, masterlabel from MessagingChannel WHERE MasterLabel = '+55 11 4003-8852'];

            for(Lead lead : newRecordList){

                if(String.isBlank(lead.Phone)){
                    continue;
                }

                Lead oldLead = oldMap.get(lead.Id);

                if(oldLead != null && (oldLead.Phone == lead.Phone)) continue;
                System.debug('leadByPhone: ' + lead);
                leadByPhone.put(lead.Telefone_Formatado__c, lead);
            }

            List<MessagingEndUser> endUsers = [
                SELECT Id, Name, MessagingPlatformKey, Telefone_Formatado__c, ContactId, LeadId, AccountId
                FROM MessagingEndUser
                WHERE LeadId = null
                AND Telefone_Formatado__c IN :leadByPhone.keySet()
            ];

            if(endUsers != null){
                for(MessagingEndUser endUser : endUsers){
                    endUserByKey.put(endUser.Telefone_Formatado__c, endUser);
                }
            }

            for(Lead lead : leadByPhone.values()){

                MessagingEndUser endUser = endUserByKey.get(lead.Telefone_Formatado__c);

                

                if(endUser == null){

                    if(lead.RecordTypeId == QualificarConsultorRT){
                        endUser = new MessagingEndUser(
                            MessageType = 'WhatsApp',
                            MessagingConsentStatus = 'ImplicitlyOptedIn',
                            MessagingPlatformKey = lead.Telefone_Formatado__c,
                            Name = lead.FirstName + ' ' + lead.LastName,
                            MessagingChannelId = Test.isRunningTest() ? '0MjU50000011EhtKAE' : channelPartner[0].Id,
                            LeadID = lead.Id
                        );
                    } else{
                        for(MessagingChannel channel : channelsCustomer){
                            endUser = new MessagingEndUser(
                                MessageType = 'WhatsApp',
                                MessagingConsentStatus = 'ImplicitlyOptedIn',
                                MessagingPlatformKey = lead.Telefone_Formatado__c,
                                Name = lead.FirstName + ' ' + lead.LastName,
                                MessagingChannelId = Test.isRunningTest() ? '0MjU50000011EhtKAE' : channelPartner[0].Id,
                                LeadID = lead.Id
                            );
                            messagingUsers.add(endUser);
                        }
                    }

                }else{
                    endUser.LeadID = lead.Id;
                }
                messagingUsers.add(endUser);
            }

            List<Database.UpsertResult> srList = Database.upsert(messagingUsers, false);

            for (Database.UpsertResult sr : srList) {
                if (sr.isSuccess()) {
                    System.debug('Successfully inserted account. MessagingUser ID: ' + sr.getId());
                }
                else {
                    for(Database.Error err : sr.getErrors()) {
                        System.debug('The following error has occurred.');                    
                        System.debug(err.getStatusCode() + ': ' + err.getMessage());
                        System.debug('MessagingUser fields that affected this error: ' + err.getFields());
                    }
                }
            }

        }catch(Exception ex){
            System.debug('##Erro ao criar Messaging user: ' + ex.getMessage());
            System.debug('##Stack: ' + ex.getStackTraceString());
            System.debug('##Line: ' + ex.getLineNumber());
        }
        
    }
    
    public static void sendConsultorRecordToVirtualOffice(List<Lead> newRecordList, Map<Id, Lead> oldRecordsMap) {
    	Set<Id> consultorIds = new Set<Id>();

    	for (Lead lead : newRecordList) {
        	Lead oldLead = oldRecordsMap.get(lead.Id);

        	if (
            	lead.RecordTypeID == QualificarConsultorRT &&
            	lead.Status != oldLead.Status &&
            	oldLead.Status == 'Trabalhando' &&
            	lead.Status == 'Aguardando Pagamento'
        	) {
            	consultorIds.add(lead.Id);
        	}
    	}

    	if (!consultorIds.isEmpty()) {
        	IntegracaoVOConsultorPreCadastro.sendConsultor(consultorIds);
    	}
        
	}

}