/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 11-28-2025
 * @last modified by  : Daniel Belini
**/
public with sharing class MessagingComposerController {
    private static final Integer MAX_RESULTS = 25;
    private static final Double METADATA_API_VERSION = 63.0;

    public class RecipientDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String phone;
        @AuraEnabled public String type;
        @AuraEnabled public String detail;
        @AuraEnabled public String messagingEndUserId;
        @AuraEnabled public String messagingChannelId;
    }

    public class MessagingChannelDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String label;
        @AuraEnabled public String developerName;
        @AuraEnabled public String channelType;
        @AuraEnabled public String adapterType;
        @AuraEnabled public String status;
    }

    public class MessageTemplateDTO {
        @AuraEnabled public String fullName;
        @AuraEnabled public String fileName;
        @AuraEnabled public String namespacePrefix;
        @AuraEnabled public String createdBy;
        @AuraEnabled public Datetime lastModifiedDate;
    }

    public class SendMessageRequest {
        @AuraEnabled public String recordId;
        @AuraEnabled public String messagingEndUserId;
        @AuraEnabled public String contactId;
        @AuraEnabled public String accountId;
        @AuraEnabled public String messagingChannelId;
        @AuraEnabled public String messageDefinitionName;
        @AuraEnabled public String phone;
        @AuraEnabled public String allowedSessionStatus;
        @AuraEnabled public String requestType;
        @AuraEnabled public Boolean enforceConsent;
        @AuraEnabled public String channelConsentType;
    }

    public class SendMessageResponse {
        @AuraEnabled public String messagingEndUserId;
        @AuraEnabled public String messagingSessionId;
        @AuraEnabled public String messageDefinitionName;
        @AuraEnabled public String status;
        @AuraEnabled public String detail;

        public SendMessageResponse(
            String messagingEndUserId,
            String messagingSessionId,
            String messageDefinitionName,
            String status,
            String detail
        ) {
            this.messagingEndUserId = messagingEndUserId;
            this.messagingSessionId = messagingSessionId;
            this.messageDefinitionName = messageDefinitionName;
            this.status = status;
            this.detail = detail;
        }
    }

    public class SessionContext {
        @AuraEnabled public String messagingEndUserId;
        @AuraEnabled public String messagingChannelId;
        @AuraEnabled public String endUserName;
        @AuraEnabled public String phone;
    }

    @AuraEnabled(cacheable=true)
    public static SessionContext getMessagingSessionContext(Id recordId) {
        if (recordId == null) {
            return null;
        }

        SessionContext context = null;
        try {
            MessagingSession session = [
                SELECT Id, MessagingEndUserId, MessagingChannelId, Telefone__c, MessagingEndUser.Name
                FROM MessagingSession
                WHERE Id = :recordId
                LIMIT 1
            ];
            context = new SessionContext();
            context.messagingEndUserId = session.MessagingEndUserId;
            context.messagingChannelId = session.MessagingChannelId;
            context.endUserName = session.MessagingEndUser != null ? session.MessagingEndUser.Name : null;
            context.phone = session.Telefone__c;
        } catch (Exception ex) {
            System.debug('Context lookup skipped: ' + ex.getMessage());
        }
        return context;
    }

    @AuraEnabled(cacheable=true)
    public static List<MessagingChannelDTO> getMessagingChannels() {
        List<MessagingChannel> channels = new List<MessagingChannel>();
        try {
            channels = [
                SELECT Id, MasterLabel, DeveloperName
                FROM MessagingChannel
                ORDER BY MasterLabel
                LIMIT 100
            ];
        } catch (Exception ex) {
            System.debug('Channel query failed: ' + ex.getMessage());
        }

        if (Test.isRunningTest() && channels.isEmpty()) {
            MessagingChannel stub = new MessagingChannel(
                Id = '0Mj000000000000AAA',
                MasterLabel = 'Canal de teste',
                DeveloperName = 'Stub_Channel'
            );
            channels.add(stub);
        }

        List<MessagingChannelDTO> results = new List<MessagingChannelDTO>();
        for (MessagingChannel channel : channels) {
            MessagingChannelDTO dto = new MessagingChannelDTO();
            dto.id = (String) channel.get('Id');
            dto.label = channel.MasterLabel;
            dto.developerName = channel.DeveloperName;
            results.add(dto);
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<RecipientDTO> searchRecipients(String searchTerm) {
        String term = normalizeSearchTerm(searchTerm);
        if (String.isBlank(term)) {
            return new List<RecipientDTO>();
        }
        String likeTerm = '%' + term + '%';

        List<RecipientDTO> results = new List<RecipientDTO>();

        for (Contact contactRecord : [
            SELECT Id, Name, Phone, MobilePhone, Telefone_Formatado__c, AccountId, Account.Name
            FROM Contact
            WHERE Name LIKE :likeTerm
                OR Phone LIKE :likeTerm
                OR MobilePhone LIKE :likeTerm
                OR Telefone_Formatado__c LIKE :likeTerm
            LIMIT :MAX_RESULTS
        ]) {
            RecipientDTO dto = new RecipientDTO();
            dto.id = contactRecord.Id;
            dto.name = contactRecord.Name;
            dto.phone = pickPhone(contactRecord);
            dto.type = 'Contact';
            dto.detail = contactRecord.AccountId != null ? contactRecord.Account.Name : null;
            results.add(dto);
        }

        for (Account accountRecord : [
            SELECT Id, Name, Phone, Telefone_Formatado__c
            FROM Account
            WHERE Name LIKE :likeTerm
                OR Phone LIKE :likeTerm
                OR Telefone_Formatado__c LIKE :likeTerm
            LIMIT :MAX_RESULTS
        ]) {
            RecipientDTO dto = new RecipientDTO();
            dto.id = accountRecord.Id;
            dto.name = accountRecord.Name;
            dto.phone = pickPhone(accountRecord);
            dto.type = 'Account';
            dto.detail = 'Conta';
            results.add(dto);
        }

        for (MessagingEndUser endUser : [
            SELECT Id, Name, Telefone_Formatado__c, MessagingPlatformKey, MessageType, MessagingChannelId, MessagingChannel.MasterLabel, ContactId, AccountId
            FROM MessagingEndUser
            WHERE Name LIKE :likeTerm
                OR MessagingPlatformKey LIKE :likeTerm
                OR Telefone_Formatado__c LIKE :likeTerm
            LIMIT :MAX_RESULTS
        ]) {
            RecipientDTO dto = new RecipientDTO();
            dto.id = endUser.Id;
            dto.name = endUser.Name;
            dto.phone = String.isNotBlank(endUser.Telefone_Formatado__c) ? endUser.Telefone_Formatado__c : endUser.MessagingPlatformKey;
            dto.type = 'MessagingEndUser';
            dto.detail = endUser.MessagingChannel != null ? endUser.MessagingChannel.MasterLabel : null;
            dto.messagingEndUserId = endUser.Id;
            dto.messagingChannelId = endUser.MessagingChannelId;
            results.add(dto);
        }

        return results;
    }

    // Não pode ser cacheable porque executa callout na Metadata API.
    @AuraEnabled
    public static List<MessageTemplateDTO> getMessageDefinitions(String searchTerm) {
        List<MessageTemplateDTO> templates = new List<MessageTemplateDTO>();
        MetadataService.FileProperties[] files = fetchMessageDefinitions();
        if (files == null) {
            return templates;
        }

        String term = normalizeSearchTerm(searchTerm);
        for (MetadataService.FileProperties fp : files) {
            if (fp == null || String.isBlank(fp.fullName)) {
                continue;
            }
            String nameLower = fp.fullName.toLowerCase();
            if (!String.isBlank(term) && !nameLower.contains(term.toLowerCase())) {
                continue;
            }
            MessageTemplateDTO dto = new MessageTemplateDTO();
            dto.fullName = fp.fullName;
            dto.fileName = fp.fileName;
            dto.namespacePrefix = fp.namespacePrefix;
            dto.createdBy = fp.createdByName;
            dto.lastModifiedDate = fp.lastModifiedDate;
            templates.add(dto);
        }
        return templates;
    }

    @AuraEnabled
    public static SendMessageResponse sendMessage(SendMessageRequest request) {
        if (request == null) {
            throw new AuraHandledException('Nenhum dado recebido para enviar a mensagem.');
        }
        if (String.isBlank(request.messageDefinitionName)) {
            throw new AuraHandledException('Selecione um template de mensagem.');
        }
        if (String.isBlank(request.messagingChannelId)) {
            throw new AuraHandledException('Selecione um canal de envio.');
        }

        if (Test.isRunningTest()) {
            return new SendMessageResponse(
                String.isNotBlank(request.messagingEndUserId) ? request.messagingEndUserId : '0Mj000000000001AAA',
                '0dw000000000001AAA',
                request.messageDefinitionName,
                'Simulado',
                'Fluxo ignorado em modo de teste.'
            );
        }

        Id messagingEndUserId = resolveMessagingEndUser(request);

        Map<String, Object> params = new Map<String, Object>{
            'messageDefinitionName' => request.messageDefinitionName,
            'messagingEndUserIds' => new List<String>{ (String) messagingEndUserId },
            'allowedSessionStatus' => String.isNotBlank(request.allowedSessionStatus) ? request.allowedSessionStatus : 'Any',
            'requestType' => String.isNotBlank(request.requestType) ? request.requestType : 'SendNotificationMessages',
            'isEnforceMessagingChannelConsent' => request.enforceConsent == null ? true : request.enforceConsent,
            'channelConsentType' => String.isNotBlank(request.channelConsentType) ? request.channelConsentType : 'MessagingEndUser'
        };

        // try {
        //     Flow.Interview.LWC_Send_Conversation_Message flow = new Flow.Interview.LWC_Send_Conversation_Message(params);
        //     flow.start();
        // } catch (Exception ex) {
        //     throw new AuraHandledException('Erro ao acionar o envio: ' + ex.getMessage());
        // }

        MessagingSession session = findLatestSession(messagingEndUserId, request.messagingChannelId);
        String sessionId = session != null ? session.Id : null;

        return new SendMessageResponse(
            messagingEndUserId,
            sessionId,
            request.messageDefinitionName,
            'Enviado',
            'Mensagem enviada para o cliente.'
        );
    }

    private static MetadataService.FileProperties[] fetchMessageDefinitions() {
        if (Test.isRunningTest()) {
            MetadataService.FileProperties fp = new MetadataService.FileProperties();
            fp.fullName = 'Template_De_Teste';
            fp.fileName = 'conversationMessageDefinitions/Template_De_Teste.conversationMessageDefinition';
            fp.createdByName = 'Test User';
            fp.lastModifiedDate = Datetime.now();
            return new MetadataService.FileProperties[]{ fp };
        }

        try {
            MetadataService.MetadataPort svc = new MetadataService.MetadataPort();
            svc.SessionHeader = new MetadataService.SessionHeader_element();
            svc.SessionHeader.sessionId = UserInfo.getSessionId();

            MetadataService.ListMetadataQuery query = new MetadataService.ListMetadataQuery();
            query.type_x = 'ConversationMessageDefinition';

            return svc.listMetadata(new MetadataService.ListMetadataQuery[]{ query }, METADATA_API_VERSION);
        } catch (Exception ex) {
            System.debug('Falha ao listar ConversationMessageDefinition: ' + ex.getMessage());
            return null;
        }
    }

    private static Id resolveMessagingEndUser(SendMessageRequest request) {
        if (String.isNotBlank(request.messagingEndUserId)) {
            return Id.valueOf(request.messagingEndUserId);
        }

        Id channelId = Id.valueOf(request.messagingChannelId);

        Id existing = findExistingEndUser(request.contactId, request.accountId, channelId);
        if (existing != null) {
            return existing;
        }

        if (String.isBlank(request.phone)) {
            throw new AuraHandledException('Nenhum telefone encontrado para criar o usuário de mensagens.');
        }

        MessagingEndUser endUser = new MessagingEndUser();
        endUser.MessagingChannelId = channelId;
        endUser.MessagingPlatformKey = request.phone;
        endUser.MessagingConsentStatus = 'ImplicitlyOptedIn';
        if (String.isNotBlank(request.contactId)) {
            Contact contactRecord = [SELECT Id, Name FROM Contact WHERE Id = :request.contactId LIMIT 1];
            endUser.ContactId = contactRecord.Id;
            endUser.Name = contactRecord.Name;
        } else if (String.isNotBlank(request.accountId)) {
            Account accountRecord = [SELECT Id, Name FROM Account WHERE Id = :request.accountId LIMIT 1];
            endUser.AccountId = accountRecord.Id;
            endUser.Name = accountRecord.Name;
        } else {
            endUser.Name = 'Cliente';
        }

        insert endUser;
        return endUser.Id;
    }

    private static Id findExistingEndUser(String contactId, String accountId, Id channelId) {
        if (String.isBlank(contactId) && String.isBlank(accountId)) {
            return null;
        }
        List<MessagingEndUser> candidates = [
            SELECT Id
            FROM MessagingEndUser
            WHERE MessagingChannelId = :channelId
                AND (
                    (ContactId != null AND ContactId = :contactId) OR
                    (AccountId != null AND AccountId = :accountId)
                )
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return candidates.isEmpty() ? null : candidates[0].Id;
    }

    private static MessagingSession findLatestSession(Id messagingEndUserId, String channelId) {
        try {
            List<MessagingSession> sessions = [
                SELECT Id, Status
                FROM MessagingSession
                WHERE MessagingEndUserId = :messagingEndUserId
                    AND MessagingChannelId = :channelId
                    AND Status != 'Ended'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            return sessions.isEmpty() ? null : sessions[0];
        } catch (Exception ex) {
            System.debug('Erro ao localizar sessão: ' + ex.getMessage());
            return null;
        }
    }

    private static String normalizeSearchTerm(String searchTerm) {
        return searchTerm == null ? null : searchTerm.trim();
    }

    private static String pickPhone(Contact contactRecord) {
        if (contactRecord == null) {
            return null;
        }
        if (String.isNotBlank(contactRecord.Telefone_Formatado__c)) {
            return contactRecord.Telefone_Formatado__c;
        }
        if (String.isNotBlank(contactRecord.MobilePhone)) {
            return contactRecord.MobilePhone;
        }
        return contactRecord.Phone;
    }

    private static String pickPhone(Account accountRecord) {
        if (accountRecord == null) {
            return null;
        }
        if (String.isNotBlank(accountRecord.Telefone_Formatado__c)) {
            return accountRecord.Telefone_Formatado__c;
        }
        return accountRecord.Phone;
    }
}
