/**
 * Service responsável por orquestrar os callouts com o aplicativo do EzeeConnect para as pendências de proposta.
 */
public with sharing class EzeeConnectProposalPendingService {

    public class PendingRequest {
        public String ProposalId;
        public String Description;
        public Integer DocumentType;
        public Integer Status;
        public String PendingId;
    }

    public class PendingUpdateRequest {
        public Integer Status;
        public String PendingId;
    }

    public class DocumentTypeOption {
        @AuraEnabled public Integer id;
        @AuraEnabled public String name;
    }

    private static final Map<String, Integer> STATUS_CODE_BY_LABEL = new Map<String, Integer>{
        'Aguardando' => 1,
        'Respondido' => 2,
        'Aprovado'   => 3,
        'Recusado'   => 4
    };

    private static final Map<Integer, String> STATUS_LABEL_BY_CODE = new Map<Integer, String>{
        1 => 'Aguardando',
        2 => 'Respondido',
        3 => 'Aprovado',
        4 => 'Recusado'
    };

    public static Integer getStatusCode(String statusLabel) {
        if(String.isBlank(statusLabel)){
            throw new AuraHandledException('Status inválido informado para integração.');
        }

        Integer code = STATUS_CODE_BY_LABEL.get(statusLabel);

        if(code == null){
            throw new AuraHandledException('Status não suportado pela integração: ' + statusLabel);
        }

        return code;
    }

    public static String getStatusLabel(Integer code) {
        if(code == null){
            return null;
        }

        String label = STATUS_LABEL_BY_CODE.get(code);

        if(label == null){
            throw new AuraHandledException('Código de status não suportado pela integração: ' + code);
        }

        return label;
    }

    public static List<DocumentTypeOption> getDocumentTypes() {
        HttpResponse response = executeCallout('TypesDocumentPending', null);
        ensureSuccess(response, 'Tipos de documento');

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        List<Object> data = (List<Object>) body.get('data');

        List<DocumentTypeOption> options = new List<DocumentTypeOption>();

        if(data == null){
            return options;
        }

        for(Object entry : data){
            Map<String, Object> row = (Map<String, Object>) entry;
            DocumentTypeOption option = new DocumentTypeOption();
            option.id = Integer.valueOf(String.valueOf(row.get('id')));
            option.name = (String) row.get('name');
            options.add(option);
        }

        return options;
    }

    public static void sendPendingToApp(PendingRequest payload) {
        HttpResponse response = executeCallout('SetProposalPending', JSON.serialize(payload));
        ensureSuccess(response, 'Envio de pendência');
    }

    public static void updatePendingInApp(PendingUpdateRequest payload) {
        HttpResponse response = executeCallout('UpdateProposalPending', JSON.serialize(payload));
        ensureSuccess(response, 'Atualização de pendência');
    }

    private static HttpResponse executeCallout(String metadataDeveloperName, String body) {
        Integrador__mdt metadata = [
            SELECT  URL__c, Method__c, ContentType__c
            FROM    Integrador__mdt
            WHERE   DeveloperName = :metadataDeveloperName
            LIMIT 1
        ];

        HttpRequest request = new HttpRequest();
        request.setEndpoint(metadata.URL__c);

        String method = String.isBlank(metadata.Method__c) ? 'POST' : metadata.Method__c;
        request.setMethod(method);

        String contentType = String.isBlank(metadata.ContentType__c) ? 'application/json' : metadata.ContentType__c;
        request.setHeader('Content-Type', contentType);

        if(body != null){
            request.setBody(body);
        }

        Boolean requiresNivelloToken = metadata.URL__c != null && metadata.URL__c.contains('geradorproposta');

        return requiresNivelloToken
            ? Utils.callIntegrationNivello(request)
            : Utils.callIntegrationVO(request);
    }

    private static void ensureSuccess(HttpResponse response, String context) {
        if(response == null){
            throw new AuraHandledException('Sem resposta da integração: ' + context);
        }

        if(response.getStatusCode() < 200 || response.getStatusCode() >= 300){
            throw new AuraHandledException(context + ' falhou. Código ' + response.getStatusCode() + ' - ' + response.getBody());
        }
    }
}
