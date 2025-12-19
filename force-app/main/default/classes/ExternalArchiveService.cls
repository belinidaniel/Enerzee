/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 12-19-2025
 * @last modified by  : Daniel Belini
**/
public with sharing class ExternalArchiveService {

    public class UploadResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id attachmentId;
    }

    /**
     * Envia um arquivo para o endpoint proposal/ExternalArchive e cria registro em OpportunityAttachmentLink__c.
     */
    @AuraEnabled
    public static UploadResult uploadExternalArchive(
        Id opportunityId,
        String fileName,
        String base64File,
        String sobjectId,
        String activityName
    ) {
        if (String.isBlank(base64File)) {
            throw new AuraHandledException('Arquivo inválido.');
        }
        if (opportunityId == null) {
            throw new AuraHandledException('Oportunidade é obrigatória.');
        }

        Opportunity opp = [
            SELECT Id, IdVirtualOffice__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        if (String.isBlank(opp.IdVirtualOffice__c)) {
            throw new AuraHandledException('IdVirtualOffice__c não está preenchido na oportunidade.');
        }

        Integrador__mdt integracao = [
            SELECT URL__c
            FROM Integrador__mdt
            WHERE DeveloperName = 'ExternalArchive'
            LIMIT 1
        ];

        Map<String, Object> body = new Map<String, Object>{
            'IdProposal' => opp.IdVirtualOffice__c,
            'FileBase64' => base64File,
            'FileName'   => fileName
        };

        System.debug('Body: ' + JSON.serialize(body));
        HttpRequest req = new HttpRequest();
        System.debug('Endpoint: ' + integracao.URL__c);
        req.setEndpoint(integracao.URL__c);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(body));

        HttpResponse res = Utils.callIntegrationNivello(req);

        if (res == null || res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            UploadResult result = new UploadResult();
            result.success = false;
            result.message = 'Erro ao enviar arquivo: ' + (res != null ? res.getStatusCode() + ' - ' + res.getBody() : 'sem resposta');
            return result;
        }

        OpportunityAttachmentLink__c link = new OpportunityAttachmentLink__c();
        link.OpportunityId__c = opportunityId;
        link.ActivityName__c = activityName;
        link.SObjectId__c = sobjectId;
        link.AttachmentDescription__c = fileName;
        insert link;

        UploadResult ok = new UploadResult();
        ok.success = true;
        ok.attachmentId = link.Id;
        ok.message = 'Arquivo enviado com sucesso.';
        return ok;
    }
}
