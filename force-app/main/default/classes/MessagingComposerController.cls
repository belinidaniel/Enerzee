/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 12-29-2025
 * @last modified by  : Daniel Belini
**/
public without sharing class MessagingComposerController {
    private static final Integer MAX_RESULTS = 25;
    private static final Double METADATA_API_VERSION = 63.0;
    private static final String API_VERSION_STRING = String.valueOf(METADATA_API_VERSION);
    // Mapeamento fixo por canal (ajuste os DeveloperNames conforme a org)
    private static final Map<String, String> CHANNEL_DEVELOPER_NAMES = new Map<String, String>{
        'SALES' => 'SALES',
        'AFTERSALES' => 'AFTERSALES'
    };
    private static final Map<String, String> CHANNEL_MESSAGE_PREFIX = new Map<String, String>{
        'SALES' => 'SALES - ',
        'AFTERSALES' => 'AFTER - '
    };
    private static final Map<String, String> CHANNEL_FLOW_API_NAMES = new Map<String, String>{
        'SALES' => 'FLOW_SEND_MESSAGE_SALES',
        'AFTERSALES' => 'FLOW_SEND_MESSAGE_AFTERSALES'
    };

    public class RecipientDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String phone;
        @AuraEnabled public String type;
        @AuraEnabled public String detail;
        @AuraEnabled public String messagingEndUserId;
        @AuraEnabled public String messagingChannelId;
        @AuraEnabled public String messagingChannelDeveloperName;
        @AuraEnabled public String leadId;
        @AuraEnabled public String recordTypeDeveloperName;
    }

    public class MessageTemplateDTO {
        @AuraEnabled public String fullName;
        @AuraEnabled public String fileName;
        @AuraEnabled public String namespacePrefix;
        @AuraEnabled public String createdBy;
        @AuraEnabled public Datetime lastModifiedDate;
        @AuraEnabled public String label;
        @AuraEnabled public String channelKey;
    }

    public class SendMessageRequest {
        @AuraEnabled public String recordId;
        @AuraEnabled public String messagingEndUserId;
        @AuraEnabled public String contactId;
        @AuraEnabled public String accountId;
        @AuraEnabled public String leadId;
        @AuraEnabled public String opportunityId;
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
        @AuraEnabled public String messagingEndUserRecordTypeDeveloperName;
        @AuraEnabled public String channelDeveloperName;
    }

    public class SessionLaunchResponse {
        @AuraEnabled public String messagingSessionId;
        @AuraEnabled public String messagingEndUserId;
        @AuraEnabled public String messagingChannelId;
        @AuraEnabled public String messagingEndUserRecordTypeDeveloperName;
    }

    @AuraEnabled(cacheable=true)
    public static SessionContext getMessagingSessionContext(Id recordId) {
        if (recordId == null) {
            return null;
        }

        SessionContext context = null;
        try {
            MessagingSession session = [
                SELECT Id, MessagingEndUserId, MessagingChannelId, Telefone__c, MessagingEndUser.Name,
                    MessagingChannel.DeveloperName
                FROM MessagingSession
                WHERE Id = :recordId
                LIMIT 1
            ];
            context = new SessionContext();
            context.messagingEndUserId = session.MessagingEndUserId;
            context.messagingChannelId = session.MessagingChannelId;
            context.endUserName = session.MessagingEndUser != null ? session.MessagingEndUser.Name : null;
            context.phone = session.Telefone__c;
            context.messagingEndUserRecordTypeDeveloperName = null;
            context.channelDeveloperName = session.MessagingChannel != null ? session.MessagingChannel.DeveloperName : null;
        } catch (Exception ex) {
            System.debug('Context lookup skipped: ' + ex.getMessage());
        }
        return context;
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
            SELECT Id, Name, Telefone_Formatado__c, MessagingPlatformKey, MessageType, MessagingChannelId,
                MessagingChannel.MasterLabel, MessagingChannel.DeveloperName, ContactId, AccountId
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
            dto.messagingChannelDeveloperName = endUser.MessagingChannel != null ? endUser.MessagingChannel.DeveloperName : null;
            dto.recordTypeDeveloperName = null;
            results.add(dto);
        }

        for (Lead leadRecord : [
            SELECT Id, Name, Phone, MobilePhone, Telefone_Formatado__c, Company
            FROM Lead
            WHERE Name LIKE :likeTerm
                OR Phone LIKE :likeTerm
                OR MobilePhone LIKE :likeTerm
                OR Telefone_Formatado__c LIKE :likeTerm
            LIMIT :MAX_RESULTS
        ]) {
            RecipientDTO dto = new RecipientDTO();
            dto.id = leadRecord.Id;
            dto.name = leadRecord.Name;
            dto.phone = String.isNotBlank(leadRecord.Telefone_Formatado__c)
                ? leadRecord.Telefone_Formatado__c
                : (String.isNotBlank(leadRecord.MobilePhone) ? leadRecord.MobilePhone : leadRecord.Phone);
            dto.type = 'Lead';
            dto.detail = leadRecord.Company;
            dto.leadId = leadRecord.Id;
            results.add(dto);
        }

        return results;
    }

    // Não pode ser cacheable porque executa callout na Metadata API.
    @AuraEnabled
    public static List<MessageTemplateDTO> getMessageDefinitions(String searchTerm) {
        List<MessageTemplateDTO> templates = new List<MessageTemplateDTO>();
        MetadataService.FileProperties[] files = fetchMessageDefinitions();

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
    public static List<MessageTemplateDTO> getMessageDefinitionsByChannelKey(String channelKey) {
        if (String.isBlank(channelKey)) {
            return new List<MessageTemplateDTO>();
        }
        List<MessageTemplateDTO> all = getMessageDefinitions(null);
        String prefix = CHANNEL_MESSAGE_PREFIX.get(channelKey);

        List<MessageTemplateDTO> filtered = new List<MessageTemplateDTO>();
        for (MessageTemplateDTO dto : all) {
            if (dto == null || String.isBlank(dto.fullName)) {
                continue;
            }
            if (String.isNotBlank(prefix) && !dto.fullName.startsWith(prefix)) {
                continue;
            }
            MessageTemplateDTO item = new MessageTemplateDTO();
            item.fullName = dto.fullName;
            item.fileName = dto.fileName;
            item.namespacePrefix = dto.namespacePrefix;
            item.createdBy = dto.createdBy;
            item.lastModifiedDate = dto.lastModifiedDate;
            item.channelKey = channelKey;
            item.label = stripPrefix(dto.fullName, prefix);
            filtered.add(item);
        }
        return filtered;
    }

    @AuraEnabled
    public static SessionLaunchResponse prepareSessionAndLaunchFlow(
        String recipientJson,
        String channelKey,
        String channelPhone,
        String selectedMessageComponentName
    ) {
        RecipientDTO recipient = parseRecipient(recipientJson);
        if (recipient == null || String.isBlank(recipient.id)) {
            throw new AuraHandledException('Selecione um destinatário.');
        }
        if (String.isBlank(selectedMessageComponentName)) {
            throw new AuraHandledException('Selecione uma mensagem.');
        }

        Id channelId = resolveChannelId(channelKey, recipient.messagingChannelId, recipient.messagingChannelDeveloperName, channelPhone);

        SendMessageRequest request = buildSessionRequest(recipient, channelId);
        if (String.isBlank(request.phone)) {
            request.phone = normalizePhone(recipient.phone);
        }

        Id messagingEndUserId = resolveMessagingEndUser(request);
        MessagingSession existingSession = findLatestSession(messagingEndUserId, channelId);
        String sessionId = existingSession != null ? existingSession.Id : null;

        SessionLaunchResponse response = new SessionLaunchResponse();
        response.messagingEndUserId = messagingEndUserId;
        response.messagingChannelId = (String) channelId;
        response.messagingEndUserRecordTypeDeveloperName = recipient.recordTypeDeveloperName;

        Map<String, Object> flowInputs = new Map<String, Object>{
            'messagingSessionId' => sessionId,
            'messagingEndUserId' => messagingEndUserId,
            'recipientId' => recipient.id,
            'selectedMessageComponentName' => selectedMessageComponentName,
            'channelKey' => channelKey,
            'channelPhone' => channelPhone,
            'messagingChannelId' => (String) channelId,
            'recipientType' => recipient.type,
            'recordTypeDeveloperName' => recipient.recordTypeDeveloperName,
            'messagingEndUserRecordTypeDeveloperName' => recipient.recordTypeDeveloperName
        };

        String flowApiName = CHANNEL_FLOW_API_NAMES.get(channelKey);
        if (String.isBlank(flowApiName)) {
            throw new AuraHandledException('Nenhum Flow configurado para o canal selecionado.');
        }

        try {
            Flow.Interview interview = Flow.Interview.createInterview(flowApiName, flowInputs);
            interview.start();
            Object flowSessionId = interview.getVariableValue('messagingSessionId');
            if (flowSessionId != null) {
                response.messagingSessionId = (String) flowSessionId;
                return response;
            }
        } catch (Exception ex) {
            throw new AuraHandledException('Falha ao executar o Flow de envio: ' + ex.getMessage());
        }

        MessagingSession latest = findLatestSession(messagingEndUserId, channelId);
        response.messagingSessionId = latest != null ? latest.Id : sessionId;
        return response;
    }

    @AuraEnabled
    public static SendMessageResponse sendMessage(SendMessageRequest request) {
        return doSendMessage(request);
    }

    @AuraEnabled
    public static SendMessageResponse sendMessageJson(String requestJson) {
        if (String.isBlank(requestJson)) {
            throw new AuraHandledException('Nenhum dado recebido para enviar a mensagem.');
        }
        SendMessageRequest request;
        try {
            request = (SendMessageRequest) JSON.deserialize(requestJson, SendMessageRequest.class);
        } catch (Exception ex) {
            throw new AuraHandledException('Payload de mensagem inválido: ' + ex.getMessage());
        }
        return doSendMessage(request);
    }

    // Mantém a lógica central em um único lugar para evitar duplicação.
    private static SendMessageResponse doSendMessage(SendMessageRequest request) {
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
            'messagingEndUserId' => (String) messagingEndUserId,
            'allowedSessionStatus' => String.isNotBlank(request.allowedSessionStatus) ? request.allowedSessionStatus : 'Any',
            'requestType' => String.isNotBlank(request.requestType) ? request.requestType : 'SendNotificationMessages',
            'isEnforceMessagingChannelConsent' => request.enforceConsent == null ? true : request.enforceConsent,
            'channelConsentType' => String.isNotBlank(request.channelConsentType) ? request.channelConsentType : 'MessagingEndUser',
            'messagingChannelId' => request.messagingChannelId
        };

        try {
            Flow.Interview.LWC_Send_Conversation_Message flow = new Flow.Interview.LWC_Send_Conversation_Message(params);
            flow.start();
            Object flowSessionId = flow.getVariableValue('messagingSessionId');
            if (flowSessionId != null) {
                return new SendMessageResponse(
                    messagingEndUserId,
                    (String) flowSessionId,
                    request.messageDefinitionName,
                    'Enviado',
                    'Mensagem enviada para o cliente.'
                );
            }
        } catch (Exception ex) {
            // Propaga o erro real para o LWC em vez de mascarar sucesso.
            throw new AuraHandledException('Falha ao executar o fluxo LWC_Send_Conversation_Message: ' + ex.getMessage());
        }

        MessagingSession session = findLatestSession(messagingEndUserId, request.messagingChannelId);
        String sessionId = session != null ? session.Id : null;

        // Se não recuperamos a sessão imediatamente, ainda retornamos sucesso
        // indicando que a mensagem foi acionada, mas a sessão pode ser criada assíncronamente.
        return new SendMessageResponse(
            messagingEndUserId,
            sessionId,
            request.messageDefinitionName,
            sessionId == null ? 'Processando' : 'Enviado',
            sessionId == null
                ? 'Mensagem acionada. A sessão pode aparecer em instantes; se não aparecer, verifique status/aprovação do template e permissões do canal.'
                : 'Mensagem enviada para o cliente.'
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

        // 1) Tenta via Tooling REST com Named Credential (usa token do NC, não o sessionId do usuário)
        List<MetadataService.FileProperties> viaRest = fetchMessageDefinitionsViaNamedCredentialRest();
        if (!viaRest.isEmpty()) {
            return viaRest;
        }

        // 2) Tenta via SOAP Metadata com Named Credential (sem usar sessionId do usuário)
        List<MetadataService.FileProperties> viaNC = fetchMessageDefinitionsViaNamedCredential();
        if (!viaNC.isEmpty()) {
            return viaNC;
        }

        // 3) Última tentativa: sessão do usuário (pode falhar se o usuário não tiver API)
        try {
            MetadataService.MetadataPort svc = createMetadataPort();

            MetadataService.ListMetadataQuery query = new MetadataService.ListMetadataQuery();
            query.type_x = 'ConversationMessageDefinition';

            MetadataService.FileProperties[] files =
                svc.listMetadata(new MetadataService.ListMetadataQuery[]{ query }, METADATA_API_VERSION);

            if (files == null) {
                throw new AuraHandledException('Nenhum ConversationMessageDefinition encontrado.');
            }
            return files;
        } catch (Exception ex) {
            throw new AuraHandledException(
                'Falha ao listar ConversationMessageDefinition (Named Credential não retornou dados e a sessão do usuário é inválida para API): ' +
                ex.getMessage()
            );
        }
    }

    private static MetadataService.MetadataPort createMetadataPort() {
        MetadataService.MetadataPort svc = new MetadataService.MetadataPort();
        svc.SessionHeader = new MetadataService.SessionHeader_element();
        String sessionId = UserInfo.getSessionId();
        if (String.isBlank(sessionId)) {
            throw new AuraHandledException('Sessão indisponível para chamada de metadata (UserInfo.getSessionId() vazio). Verifique permissões de API.');
        }
        svc.SessionHeader.sessionId = sessionId;
        svc.endpoint_x = resolveMetadataEndpoint();
        return svc;
    }

    private static String resolveMetadataEndpoint() {
        // Prioriza o domínio da requisição atual (Lightning) para evitar INVALID_SESSION_ID
        try {
            String current = URL.getCurrentRequestUrl().toExternalForm();
            // extrai protocolo + host
            Integer idx = current.indexOf('/', 8);
            String host = idx > 0 ? current.substring(0, idx) : current;
            return host + '/services/Soap/m/' + METADATA_API_VERSION;
        } catch (Exception ex) {
            // fallback para domínio da org
            return URL.getOrgDomainUrl().toExternalForm() + '/services/Soap/m/' + METADATA_API_VERSION;
        }
    }

    // Fallback usando Named Credential "Salesforce_PRD" (conforme exemplo em RemarketingRouter)
    private static List<MetadataService.FileProperties> fetchMessageDefinitionsViaNamedCredential() {
        List<MetadataService.FileProperties> results = new List<MetadataService.FileProperties>();
        try {
            HttpRequest req = new HttpRequest();
            req.setMethod('POST');
            req.setEndpoint('callout:Salesforce_PRD/services/Soap/m/' + METADATA_API_VERSION);
            req.setHeader('Content-Type', 'text/xml; charset=UTF-8');
            req.setHeader('SOAPAction', 'listMetadata');

            String body =
                '<?xml version="1.0" encoding="UTF-8"?>' +
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:met="http://soap.sforce.com/2006/04/metadata">' +
                '<soapenv:Header/>' +
                '<soapenv:Body>' +
                '<met:listMetadata>' +
                '<met:queries>' +
                '<met:type>ConversationMessageDefinition</met:type>' +
                '</met:queries>' +
                '<met:asOfVersion>' + METADATA_API_VERSION + '</met:asOfVersion>' +
                '</met:listMetadata>' +
                '</soapenv:Body>' +
                '</soapenv:Envelope>';
            req.setBody(body);

            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 200) {
                System.debug('Named Credential listMetadata falhou: ' + res.getStatusCode() + ' - ' + res.getBody());
                return results;
            }

            Dom.Document doc = new Dom.Document();
            doc.load(res.getBody());
            Dom.XMLNode root = doc.getRootElement();
            collectFileProperties(root, results);
        } catch (Exception ex) {
            System.debug('Erro no fallback via Named Credential: ' + ex.getMessage());
        }
        return results;
    }

    // Fallback via Tooling API usando Named Credential (evita usar o sessionId do usuário)
    private static List<MetadataService.FileProperties> fetchMessageDefinitionsViaNamedCredentialRest() {
        List<MetadataService.FileProperties> results = new List<MetadataService.FileProperties>();
        try {
            String soql = 'SELECT FullName, DeveloperName, NamespacePrefix, LastModifiedDate, CreatedBy.Name FROM ConversationMessageDefinition';
            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint(
                'callout:Salesforce_PRD/services/data/v' +
                API_VERSION_STRING +
                '/tooling/query?q=' +
                EncodingUtil.urlEncode(soql, 'UTF-8')
            );
            req.setHeader('Accept', 'application/json');

            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 200) {
                System.debug('Named Credential Tooling query falhou: ' + res.getStatusCode() + ' - ' + res.getBody());
                return results;
            }

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> records = (List<Object>) payload.get('records');
            for (Object recObj : records) {
                Map<String, Object> rec = (Map<String, Object>) recObj;
                MetadataService.FileProperties fp = new MetadataService.FileProperties();
                fp.fullName = (String) rec.get('FullName');
                String developerName = (String) rec.get('DeveloperName');
                fp.fileName = developerName != null
                    ? 'conversationMessageDefinitions/' + developerName + '.conversationMessageDefinition'
                    : null;
                fp.namespacePrefix = (String) rec.get('NamespacePrefix');
                Object createdBy = rec.get('CreatedBy');
                if (createdBy instanceof Map<String, Object>) {
                    fp.createdByName = (String) ((Map<String, Object>) createdBy).get('Name');
                }
                Object lmd = rec.get('LastModifiedDate');
                if (lmd != null) {
                    try {
                        fp.lastModifiedDate = (Datetime) JSON.deserialize('"' + (String) lmd + '"', Datetime.class);
                    } catch (Exception ignore) {}
                }
                if (String.isNotBlank(fp.fullName)) {
                    results.add(fp);
                }
            }
        } catch (Exception ex) {
            System.debug('Erro no fallback via Tooling API: ' + ex.getMessage());
        }
        return results;
    }

    // Percorre árvore XML para encontrar nós <result>
    private static void collectFileProperties(Dom.XMLNode node, List<MetadataService.FileProperties> acc) {
        if (node == null) {
            return;
        }
        if ('result'.equalsIgnoreCase(node.getName())) {
            MetadataService.FileProperties fp = new MetadataService.FileProperties();
            for (Dom.XMLNode child : node.getChildElements()) {
                if ('fullName'.equalsIgnoreCase(child.getName())) {
                    fp.fullName = child.getText();
                } else if ('fileName'.equalsIgnoreCase(child.getName())) {
                    fp.fileName = child.getText();
                } else if ('namespacePrefix'.equalsIgnoreCase(child.getName())) {
                    fp.namespacePrefix = child.getText();
                } else if ('createdByName'.equalsIgnoreCase(child.getName())) {
                    fp.createdByName = child.getText();
                } else if ('lastModifiedDate'.equalsIgnoreCase(child.getName())) {
                    try {
                        fp.lastModifiedDate = (Datetime) JSON.deserialize('"' + child.getText() + '"', Datetime.class);
                    } catch (Exception ignore) {}
                }
            }
            if (String.isNotBlank(fp.fullName)) {
                acc.add(fp);
            }
        }
        for (Dom.XMLNode child : node.getChildElements()) {
            collectFileProperties(child, acc);
        }
    }

    private static String stripPrefix(String value, String prefix) {
        if (String.isBlank(value) || String.isBlank(prefix)) {
            return value;
        }
        return value.startsWith(prefix) ? value.substring(prefix.length()).trim() : value;
    }

    private static RecipientDTO parseRecipient(String recipientJson) {
        if (String.isBlank(recipientJson)) {
            return null;
        }
        try {
            Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(recipientJson);
            RecipientDTO dto = new RecipientDTO();
            dto.id = (String) raw.get('id');
            dto.messagingEndUserId = (String) raw.get('messagingEndUserId');
            dto.messagingChannelId = (String) raw.get('messagingChannelId');
            dto.messagingChannelDeveloperName = (String) raw.get('messagingChannelDeveloperName');
            dto.name = (String) raw.get('name');
            dto.phone = (String) raw.get('phone');
            dto.type = (String) raw.get('type');
            dto.detail = (String) raw.get('detail');
            dto.recordTypeDeveloperName = (String) raw.get('recordTypeDeveloperName');
            return dto;
        } catch (Exception ex) {
            throw new AuraHandledException('Destinatário inválido: ' + ex.getMessage());
        }
    }

    private static SendMessageRequest buildSessionRequest(RecipientDTO recipient, Id channelId) {
        SendMessageRequest request = new SendMessageRequest();
        request.messagingChannelId = (String) channelId;
        request.messagingEndUserId = recipient.messagingEndUserId;
        request.phone = normalizePhone(recipient.phone);

        if (recipient.type == 'Contact') {
            request.contactId = recipient.id;
        } else if (recipient.type == 'Account') {
            request.accountId = recipient.id;
        } else if (recipient.type == 'Lead') {
            request.leadId = recipient.id;
        } else if (recipient.type == 'Opportunity') {
            Opportunity opp = [
                SELECT Id, Name, AccountId, Account.Name, Account.Phone, Account.Telefone_Formatado__c
                FROM Opportunity
                WHERE Id = :recipient.id
                LIMIT 1
            ];
            request.accountId = opp.AccountId;
            request.opportunityId = opp.Id;
            if (String.isBlank(request.phone) && opp.Account != null) {
                request.phone = pickPhone(opp.Account);
            }
        }
        return request;
    }

    private static Id resolveChannelId(String channelKey, String existingChannelId, String existingChannelDevName, String channelPhone) {
        // 1) já recebido
        if (String.isNotBlank(existingChannelId)) {
            return Id.valueOf(existingChannelId);
        }
        // 2) por developerName direto do registro
        if (String.isNotBlank(existingChannelDevName)) {
            List<MessagingChannel> byDev = [
                SELECT Id
                FROM MessagingChannel
                WHERE DeveloperName = :existingChannelDevName
                LIMIT 1
            ];
            if (!byDev.isEmpty()) {
                return byDev[0].Id;
            }
        }
        // 3) pelo mapeamento estático channelKey -> DeveloperName
        String developerName = CHANNEL_DEVELOPER_NAMES.get(channelKey);
        if (String.isNotBlank(developerName)) {
            List<MessagingChannel> channels = [
                SELECT Id
                FROM MessagingChannel
                WHERE DeveloperName = :developerName
                LIMIT 1
            ];
            if (!channels.isEmpty()) {
                return channels[0].Id;
            }
        }
        // 4) fallback: tenta localizar por telefone no MasterLabel (bruto e normalizado)
        String normalizedPhone = normalizePhone(channelPhone);
        String rawPhone = String.isNotBlank(channelPhone) ? channelPhone.trim() : null;
        List<MessagingChannel> candidates = [
            SELECT Id, MasterLabel
            FROM MessagingChannel
            LIMIT 50
        ];
        for (MessagingChannel ch : candidates) {
            String label = ch.MasterLabel != null ? ch.MasterLabel : '';
            String normalizedLabel = normalizePhone(label);
            if (String.isNotBlank(rawPhone) && label.contains(rawPhone)) {
                return ch.Id;
            }
            if (String.isNotBlank(normalizedPhone) && String.isNotBlank(normalizedLabel) && normalizedLabel.contains(normalizedPhone)) {
                return ch.Id;
            }
        }
        throw new AuraHandledException('Não foi encontrado um MessagingChannel para o canal selecionado.');
    }

    private static Id resolveMessagingEndUser(SendMessageRequest request) {
        if (String.isNotBlank(request.messagingEndUserId)) {
            return Id.valueOf(request.messagingEndUserId);
        }

        Id channelId = Id.valueOf(request.messagingChannelId);

        // Tenta localizar por telefone e canal antes de criar
        Id existingByPhone = findExistingEndUserByPhone(request.phone, channelId);
        if (existingByPhone != null) {
            return existingByPhone;
        }

        Id existing = findExistingEndUser(request.contactId, request.accountId, channelId);
        if (existing != null) {
            return existing;
        }

        String phone = request.phone;
        String derivedName = 'Cliente';

        if (String.isBlank(phone) && String.isNotBlank(request.contactId)) {
            Contact contactRecord = [SELECT Id, Name, Phone, MobilePhone, Telefone_Formatado__c FROM Contact WHERE Id = :request.contactId LIMIT 1];
            phone = pickPhone(contactRecord);
            derivedName = contactRecord.Name;
        } else if (String.isBlank(phone) && String.isNotBlank(request.accountId)) {
            Account accountRecord = [SELECT Id, Name, Phone, Telefone_Formatado__c FROM Account WHERE Id = :request.accountId LIMIT 1];
            phone = pickPhone(accountRecord);
            derivedName = accountRecord.Name;
        } else if (String.isBlank(phone) && String.isNotBlank(request.opportunityId)) {
            Opportunity opportunityRecord = [
                SELECT Id, Name, AccountId, Account.Name, Account.Phone, Account.Telefone_Formatado__c
                FROM Opportunity
                WHERE Id = :request.opportunityId
                LIMIT 1
            ];
            if (opportunityRecord.AccountId != null && String.isBlank(request.accountId)) {
                request.accountId = opportunityRecord.AccountId;
            }
            if (String.isBlank(phone) && opportunityRecord.Account != null) {
                phone = pickPhone(opportunityRecord.Account);
            }
            derivedName = opportunityRecord.Name;
        } else if (String.isBlank(phone) && String.isNotBlank(request.leadId)) {
            Lead leadRecord = [SELECT Id, Name, Phone, MobilePhone, Telefone_Formatado__c FROM Lead WHERE Id = :request.leadId LIMIT 1];
            phone = String.isNotBlank(leadRecord.Telefone_Formatado__c)
                ? leadRecord.Telefone_Formatado__c
                : (String.isNotBlank(leadRecord.MobilePhone) ? leadRecord.MobilePhone : leadRecord.Phone);
            derivedName = leadRecord.Name;
        }

        if (String.isBlank(phone)) {
            throw new AuraHandledException('Nenhum telefone encontrado para criar o usuário de mensagens.');
        }

        MessagingEndUser endUser = new MessagingEndUser();
        endUser.MessagingChannelId = channelId;
        endUser.MessagingPlatformKey = phone;
        endUser.MessagingConsentStatus = 'ImplicitlyOptedIn';
        if (String.isNotBlank(request.contactId)) {
            endUser.ContactId = request.contactId;
        } else if (String.isNotBlank(request.accountId)) {
            endUser.AccountId = request.accountId;
        }
        endUser.Name = derivedName;

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

    private static Id findExistingEndUserByPhone(String phone, Id channelId) {
        String normalized = normalizePhone(phone);
        if (String.isBlank(normalized)) {
            return null;
        }
        List<MessagingEndUser> candidates = [
            SELECT Id
            FROM MessagingEndUser
            WHERE MessagingChannelId = :channelId
                AND MessagingPlatformKey = :normalized
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

    private static String normalizePhone(String rawPhone) {
        if (String.isBlank(rawPhone)) {
            return null;
        }
        String digits = rawPhone.replaceAll('[^0-9]', '');
        return String.isBlank(digits) ? null : digits;
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
