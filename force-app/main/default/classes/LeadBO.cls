/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 01-28-2026
 * @last modified by  : Daniel Belini
**/
public class LeadBO {
	public static Id QualificarClienteRT = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName().get('QualificacaodeClientes').getRecordTypeId();
    public static Id QualificarClienteQUEUE = getQueueIdByName('QualificacaodeClientes');

    public static Id QualificarConsultorRT = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName().get('QualificacaodeConsultores').getRecordTypeId();
    public static Id QualificarConsultorQUEUE = getQueueIdByName('Consultor');

    @TestVisible
    private static Set<Id> pendingImmediateIntegrationLeadIds = new Set<Id>();

    private static Boolean isAutoDistributionRunning = false;
    private static final Set<String> B2B_KEYWORDS = new Set<String>{'B2B', 'BESS'};
    
    public static void checkTasksConclusionBeforeStatusChange(List<Lead> newRecordList, Map<Id, Lead> oldMap){
        
        Map<Id, List<Task>> LeadIdToTaskList = new Map<Id, List<Task>>();
        
        Id voUserId = [
            SELECT  Id
            FROM    User
            WHERE   Username like '%integracao@lab065.com%'
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
                    // lead.addError('O campo Documento é obrigatório! Insira ao menos um antes de converter o Lead.'); 
                }
                if (String.isBlank(lead.Email)) { 
                    lead.addError('O campo Email é obrigatório! Preencha antes de converter o Lead.'); 
                }
                // if (String.isBlank(lead.MobilePhone)) { 
                //     lead.addError('O campo Celular é obrigatório! Preencha antes de converter o Lead.'); 
                // }
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

    public static void applySdrLeadRules(List<Lead> newRecordList, Map<Id, Lead> oldMap) {
        if (newRecordList == null || newRecordList.isEmpty()) {
            return;
        }

        for (Lead lead : newRecordList) {
            if (lead == null || lead.SDRAgent__c != true) {
                continue;
            }

            Lead oldLead = oldMap != null ? oldMap.get(lead.Id) : null;
            if (oldLead != null && !hasSdrRelevantChange(lead, oldLead)) {
                continue;
            }

            if (shouldMarkLeadAsIncomplete(lead)) {
                lead.StatusJustification__c = appendLeadIncompleteTag(lead.StatusJustification__c);
            }

            if (shouldSetNeutralProduct(lead)) {
                lead.Lb065_ProdutoInteresse__c = 'Não indicou ou não soube informar';
            }
        }
    }

    public static void normalizeDistributionAndIntegrationBeforeUpdate(List<Lead> newRecordList, Map<Id, Lead> oldMap) {
        if (newRecordList == null || newRecordList.isEmpty() || oldMap == null) {
            return;
        }

        for (Lead lead : newRecordList) {
            if (lead == null) {
                continue;
            }

            Lead oldLead = oldMap.get(lead.Id);
            if (oldLead == null) {
                continue;
            }

            Boolean consultantChanged = lead.ConsultorRegional__c != oldLead.ConsultorRegional__c;
            Boolean payloadChanged = hasIntegrationPayloadChange(lead, oldLead);

            if (consultantChanged || payloadChanged) {
                lead.Lab065_IntegracaoDistribuicaoLead__c = false;
            }

            if (consultantChanged && lead.ConsultorRegional__c != null) {
                syncRequiredDistributionFields(oldLead, lead);
                syncDistributionLocationFields(lead, lead);

                if (lead.Status == 'Trabalhando' && canMoveToDistributedStatus(lead)) {
                    lead.Status = 'Distribuído';
                }

                if (isClientLeadRecordType(lead)) {
                    pendingImmediateIntegrationLeadIds.add(lead.Id);
                }
            }
        }
    }

    public static void autoDistributeLeadsAfterSave(List<Lead> newRecordList, Map<Id, Lead> oldMap) {
        if (newRecordList == null || newRecordList.isEmpty() || isAutoDistributionRunning) {
            return;
        }

        List<LeadDistributionSelector.Request> requests = new List<LeadDistributionSelector.Request>();
        Map<Id, Lead> leadsToDistribute = new Map<Id, Lead>();

        for (Lead lead : newRecordList) {
            Lead oldLead = oldMap != null ? oldMap.get(lead.Id) : null;
            if (!shouldAutoDistributeByApex(lead, oldLead)) {
                continue;
            }

            LeadDistributionSelector.Request request = new LeadDistributionSelector.Request();
            request.leadId = lead.Id;
            requests.add(request);
            leadsToDistribute.put(lead.Id, lead);
        }

        if (requests.isEmpty()) {
            return;
        }

        List<LeadDistributionSelector.Response> responses = LeadDistributionSelector.selectConsultant(requests);
        List<Lead> leadsToUpdate = new List<Lead>();

        for (Integer i = 0; i < requests.size(); i++) {
            LeadDistributionSelector.Response response = responses.size() > i ? responses[i] : null;
            if (response == null || response.consultantId == null) {
                continue;
            }

            Id leadId = requests[i].leadId;
            Lead currentLead = leadsToDistribute.get(leadId);
            if (currentLead == null) {
                continue;
            }

            Lead leadToUpdate = new Lead(
                Id = leadId,
                ConsultorRegional__c = response.consultantId,
                Lab065_IntegracaoDistribuicaoLead__c = false
            );

            syncRequiredDistributionFields(currentLead, leadToUpdate);
            syncDistributionLocationFields(currentLead, leadToUpdate);
            if (canMoveToDistributedStatus(leadToUpdate)) {
                leadToUpdate.Status = 'Distribuído';
            }

            if (currentLead.Lb065_LeadVencido__c == true) {
                leadToUpdate.Lb065_LeadVencido__c = false;
            }

            leadsToUpdate.add(leadToUpdate);
        }

        if (leadsToUpdate.isEmpty()) {
            return;
        }

        isAutoDistributionRunning = true;
        try {
            update leadsToUpdate;
        } finally {
            isAutoDistributionRunning = false;
        }
    }

    public static void triggerImmediateIntegrationAfterUpdate(List<Lead> newRecordList) {
        if (newRecordList == null || newRecordList.isEmpty() || pendingImmediateIntegrationLeadIds.isEmpty()) {
            return;
        }

        Set<Id> readyForIntegration = new Set<Id>();
        for (Lead lead : newRecordList) {
            if (lead == null || !pendingImmediateIntegrationLeadIds.contains(lead.Id)) {
                continue;
            }

            if (lead.ConsultorRegional__c != null && lead.Status == 'Distribuído' && isClientLeadRecordType(lead)) {
                readyForIntegration.add(lead.Id);
            }
        }

        pendingImmediateIntegrationLeadIds.clear();

        if (!readyForIntegration.isEmpty()) {
            LeadIntegrationService.integrateLeadAsync(readyForIntegration);
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

    private static Boolean shouldAutoDistributeByApex(Lead lead, Lead oldLead) {
        if (lead == null || lead.Id == null || lead.IsConverted || lead.ConsultorRegional__c != null) {
            return false;
        }

        if (lead.Status != 'Novo' && lead.Status != 'Trabalhando') {
            return false;
        }

        Boolean specialLead = isConsultorLeadByContext(lead) || isB2BLead(lead) || !String.isBlank(lead.EmailConsultor__c);

        // Fluxo cobre o caminho padrao de novos leads com rating.
        // Apex cobre os casos que fogem desse caminho (status Trabalhando, SDR/Consultor/B2B, rating nulo).
        Boolean shouldDistribute = (lead.Status == 'Trabalhando' && (!String.isBlank(lead.Rating) || specialLead)) ||
            (lead.Status == 'Novo' && specialLead && String.isBlank(lead.Rating));

        if (!shouldDistribute) {
            return false;
        }

        if (oldLead == null) {
            return true;
        }

        return hasDistributionRelevantChange(lead, oldLead);
    }

    private static Boolean hasDistributionRelevantChange(Lead lead, Lead oldLead) {
        return lead.Status != oldLead.Status ||
            lead.Rating != oldLead.Rating ||
            lead.RecordTypeId != oldLead.RecordTypeId ||
            lead.LeadSource != oldLead.LeadSource ||
            lead.EmailConsultor__c != oldLead.EmailConsultor__c ||
            lead.Nome_da_Campanha_Meta__c != oldLead.Nome_da_Campanha_Meta__c ||
            lead.ConsultorRegional__c != oldLead.ConsultorRegional__c;
    }

    private static Boolean hasIntegrationPayloadChange(Lead lead, Lead oldLead) {
        return lead.ConsultorRegional__c != oldLead.ConsultorRegional__c ||
            lead.Lb065_ProdutoInteresse__c != oldLead.Lb065_ProdutoInteresse__c ||
            lead.Lb065_HistoricoLead__c != oldLead.Lb065_HistoricoLead__c ||
            lead.ResumoInteracao__c != oldLead.ResumoInteracao__c ||
            lead.CPFCNPJ__c != oldLead.CPFCNPJ__c ||
            lead.Email != oldLead.Email ||
            lead.MobilePhone != oldLead.MobilePhone ||
            lead.Phone != oldLead.Phone ||
            lead.City != oldLead.City ||
            lead.State != oldLead.State ||
            lead.Cidade__c != oldLead.Cidade__c ||
            lead.Estado__c != oldLead.Estado__c ||
            lead.CustoEnergiaMes__c != oldLead.CustoEnergiaMes__c ||
            lead.ValorContaEnergia__c != oldLead.ValorContaEnergia__c;
    }

    private static Boolean hasSdrRelevantChange(Lead lead, Lead oldLead) {
        Boolean notFinishMessagingChanged = false;
        if (hasLeadField('NotFinishMessaging__c')) {
            notFinishMessagingChanged = getBooleanField(lead, 'NotFinishMessaging__c') !=
                getBooleanField(oldLead, 'NotFinishMessaging__c');
        }

        return lead.Lb065_ProdutoInteresse__c != oldLead.Lb065_ProdutoInteresse__c ||
            notFinishMessagingChanged ||
            lead.ResumoInteracao__c != oldLead.ResumoInteracao__c ||
            lead.Description != oldLead.Description ||
            lead.Email != oldLead.Email ||
            lead.MobilePhone != oldLead.MobilePhone ||
            lead.Phone != oldLead.Phone ||
            lead.City != oldLead.City ||
            lead.State != oldLead.State ||
            lead.Cidade__c != oldLead.Cidade__c ||
            lead.Estado__c != oldLead.Estado__c ||
            lead.CPFCNPJ__c != oldLead.CPFCNPJ__c;
    }

    private static Boolean shouldMarkLeadAsIncomplete(Lead lead) {
        if (lead == null) {
            return false;
        }

        Boolean conversationIncomplete = getBooleanField(lead, 'NotFinishMessaging__c') == true || hasUnclearProductSignal(lead);
        if (!conversationIncomplete) {
            return false;
        }

        Boolean hasInitialInterest = !String.isBlank(lead.Lb065_ProdutoInteresse__c) ||
            !String.isBlank(lead.ResumoInteracao__c) ||
            !String.isBlank(lead.Description);
        if (!hasInitialInterest) {
            return false;
        }

        Boolean hasPhone = !String.isBlank(lead.MobilePhone) || !String.isBlank(lead.Phone);
        Boolean hasCityState = (!String.isBlank(lead.City) && !String.isBlank(lead.State)) ||
            (!String.isBlank(lead.Cidade__c) && !String.isBlank(lead.Estado__c));

        return String.isBlank(lead.Email) || String.isBlank(lead.CPFCNPJ__c) || !hasPhone || !hasCityState;
    }

    private static Boolean shouldSetNeutralProduct(Lead lead) {
        if (lead == null || lead.SDRAgent__c != true) {
            return false;
        }

        if (String.isBlank(lead.Lb065_ProdutoInteresse__c)) {
            return true;
        }

        if (lead.Lb065_ProdutoInteresse__c == 'Não indicou ou não soube informar') {
            return false;
        }

        if (getBooleanField(lead, 'NotFinishMessaging__c') == true) {
            return lead.Lb065_ProdutoInteresse__c == 'Ezee Solar' || hasUnclearProductSignal(lead);
        }

        return lead.Lb065_ProdutoInteresse__c == 'Ezee Solar' && hasUnclearProductSignal(lead);
    }

    private static Boolean hasUnclearProductSignal(Lead lead) {
        String context = ((lead.ResumoInteracao__c == null ? '' : lead.ResumoInteracao__c) + ' ' +
            (lead.Description == null ? '' : lead.Description)).toLowerCase();

        if (String.isBlank(context)) {
            return false;
        }

        List<String> indicators = new List<String>{
            'nao soube',
            'não soube',
            'nao indicou',
            'não indicou',
            'nao informou',
            'não informou',
            'sem dados',
            'sem informacao',
            'sem informação',
            'incompleto'
        };

        for (String indicator : indicators) {
            if (context.contains(indicator)) {
                return true;
            }
        }

        return false;
    }

    private static String appendLeadIncompleteTag(String currentJustification) {
        if (String.isBlank(currentJustification)) {
            return 'Lead incompleto - conversa com interesse inicial sem dados suficientes para qualificacao.';
        }

        if (currentJustification.contains('Lead incompleto')) {
            return currentJustification;
        }

        return currentJustification + '\nLead incompleto - conversa com interesse inicial sem dados suficientes para qualificacao.';
    }

    private static Boolean canMoveToDistributedStatus(Lead lead) {
        if (lead == null) {
            return false;
        }

        String customState = hasLeadField('Estado__c') ? (String) lead.get('Estado__c') : null;
        Boolean hasState = !String.isBlank(lead.State) || !String.isBlank(customState);
        if (!hasState) {
            return false;
        }

        if (lead.RecordTypeId == QualificarConsultorRT) {
            return true;
        }

        return !String.isBlank(lead.Rating);
    }

    private static void syncRequiredDistributionFields(Lead sourceLead, Lead targetLead) {
        if (sourceLead == null || targetLead == null) {
            return;
        }

        if (String.isBlank(targetLead.State) && !String.isBlank(sourceLead.State)) {
            targetLead.State = sourceLead.State;
        }

        if (String.isBlank(targetLead.Rating) && !String.isBlank(sourceLead.Rating)) {
            targetLead.Rating = sourceLead.Rating;
        }
    }

    private static void syncDistributionLocationFields(Lead sourceLead, Lead targetLead) {
        if (sourceLead == null || targetLead == null) {
            return;
        }

        if (hasLeadField('Estado__c') && String.isBlank((String) targetLead.get('Estado__c'))) {
            String stateValue = (String) sourceLead.get('Estado__c');
            if (String.isBlank(stateValue)) {
                stateValue = sourceLead.State;
            }
            if (!String.isBlank(stateValue)) {
                targetLead.put('Estado__c', stateValue);
            }
        }

        if (hasLeadField('Cidade__c') && String.isBlank((String) targetLead.get('Cidade__c'))) {
            String cityValue = (String) sourceLead.get('Cidade__c');
            if (String.isBlank(cityValue)) {
                cityValue = sourceLead.City;
            }
            if (!String.isBlank(cityValue)) {
                targetLead.put('Cidade__c', cityValue);
            }
        }
    }

    private static Boolean hasLeadField(String fieldApiName) {
        if (String.isBlank(fieldApiName)) {
            return false;
        }
        return Schema.SObjectType.Lead.fields.getMap().containsKey(fieldApiName);
    }

    private static Boolean getBooleanField(Lead lead, String fieldApiName) {
        if (lead == null || !hasLeadField(fieldApiName)) {
            return false;
        }
        Object value = lead.get(fieldApiName);
        return value == null ? false : (Boolean) value;
    }

    private static Boolean isConsultorLeadByContext(Lead lead) {
        if (lead == null) {
            return false;
        }

        if (lead.RecordTypeId == QualificarConsultorRT) {
            return true;
        }

        String source = normalizeText(lead.LeadSource);
        return source.contains('CONSULTOR') ||
            source == 'WEB-TO-LEAD INTEGRADOR' ||
            source == 'WEB-TO-LEAD CONSULTOR';
    }

    private static Boolean isB2BLead(Lead lead) {
        if (lead == null) {
            return false;
        }

        String source = normalizeText(lead.LeadSource);
        if (source.contains('B2B')) {
            return true;
        }

        String campaignMetaName = normalizeText(lead.Nome_da_Campanha_Meta__c);
        for (String keyword : B2B_KEYWORDS) {
            if (campaignMetaName.contains(keyword) || source.contains(keyword)) {
                return true;
            }
        }

        return false;
    }

    private static String normalizeText(String value) {
        if (String.isBlank(value)) {
            return '';
        }

        String normalized = value.trim().toUpperCase();
        normalized = normalized.replace('Á', 'A').replace('À', 'A').replace('Â', 'A').replace('Ã', 'A').replace('Ä', 'A');
        normalized = normalized.replace('É', 'E').replace('È', 'E').replace('Ê', 'E').replace('Ë', 'E');
        normalized = normalized.replace('Í', 'I').replace('Ì', 'I').replace('Î', 'I').replace('Ï', 'I');
        normalized = normalized.replace('Ó', 'O').replace('Ò', 'O').replace('Ô', 'O').replace('Õ', 'O').replace('Ö', 'O');
        normalized = normalized.replace('Ú', 'U').replace('Ù', 'U').replace('Û', 'U').replace('Ü', 'U');
        normalized = normalized.replace('Ç', 'C');
        normalized = normalized.replaceAll('[^A-Z0-9 ]', ' ');
        normalized = normalized.replaceAll(' +', ' ');

        return normalized.trim();
    }

    private static Boolean isClientLeadRecordType(Lead lead) {
        if (lead == null) {
            return false;
        }

        if (lead.RecordTypeId == QualificarClienteRT) {
            return true;
        }

        Map<Id, Schema.RecordTypeInfo> infosById = Schema.SObjectType.Lead.getRecordTypeInfosById();
        Schema.RecordTypeInfo info = infosById != null ? infosById.get(lead.RecordTypeId) : null;
        return info != null && info.getDeveloperName() == 'Cliente';
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
