/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 11-14-2025
 * @last modified by  : Daniel Belini
**/
public with sharing class ProposalPendingController {

    private static final Map<Id, List<ProposalPendingDTO>> cache = new Map<Id, List<ProposalPendingDTO>>();

    @AuraEnabled(cacheable=true)
    public static List<ProposalPendingDTO> getPendings(Id opportunityId) {
        if(opportunityId == null){
            return new List<ProposalPendingDTO>();
        }

        List<ProposalPending__c> records = [
            SELECT  Id,
                    Name,
                    Description__c,
                    DocumentTypeId__c,
                    DocumentTypeName__c,
                    Status__c,
                    Response__c,
                    FileUrl__c,
                    RespondedDate__c,
                    CreatedDate,
                    LastModifiedDate
            FROM    ProposalPending__c
            WHERE   Opportunity__c = :opportunityId
            ORDER BY CreatedDate DESC
        ];

        List<ProposalPendingDTO> dtos = toDTO(records);
        cache.put(opportunityId, dtos);
        return dtos;
    }

    @AuraEnabled(cacheable=true)
    public static List<EzeeConnectProposalPendingService.DocumentTypeOption> getDocumentTypes() {
        return EzeeConnectProposalPendingService.getDocumentTypes();
    }

    @AuraEnabled
    public static List<ProposalPendingDTO> createPendings(Id opportunityId, String pendingInputsJson) {
        List<PendingInput> pendingInputs = new List<PendingInput>();

        if(!String.isBlank(pendingInputsJson)){
            pendingInputs = (List<PendingInput>) JSON.deserialize(pendingInputsJson, List<PendingInput>.class);
        }

        System.debug(LoggingLevel.INFO, 'ProposalPendingController.createPendings - payload: ' + pendingInputsJson);
        Opportunity opportunity = loadOpportunity(opportunityId);

        if(pendingInputs == null || pendingInputs.isEmpty()){
            throw new AuraHandledException('Inclua ao menos uma pendência antes de salvar.');
        }

        List<ProposalPending__c> recordsToInsert = new List<ProposalPending__c>();

        for(PendingInput input : pendingInputs){
            validateInput(input);

            ProposalPending__c record = new ProposalPending__c();
            record.Opportunity__c     = opportunity.Id;
            record.Description__c     = input.description != null ? input.description.trim() : null;
            record.DocumentTypeId__c  = input.documentTypeId;
            record.DocumentTypeName__c= input.documentTypeName;
            record.Status__c          = 'Aguardando';
            recordsToInsert.add(record);
        }

        Savepoint sp = Database.setSavepoint();

        try{
            insert recordsToInsert;
            enqueueSend(recordsToInsert);
        } catch(Exception e){
            Database.rollback(sp);
            throw new AuraHandledException('Erro ao enviar pendências para o aplicativo: ' + e.getMessage());
        }

        List<ProposalPendingDTO> inserted = toDTO([
            SELECT  Id,
                    Name,
                    Description__c,
                    DocumentTypeId__c,
                    DocumentTypeName__c,
                    Status__c,
                    Response__c,
                    FileUrl__c,
                    RespondedDate__c,
                    CreatedDate,
                    LastModifiedDate
            FROM    ProposalPending__c
            WHERE   Id IN :recordsToInsert
        ]);

        cache.remove(opportunity.Id);

        return inserted;
    }

    @AuraEnabled
    public static ProposalPendingDTO updatePendingStatus(Id pendingId, String status) {
        if(pendingId == null){
            throw new AuraHandledException('Informe a pendência que deseja atualizar.');
        }

        if(String.isBlank(status)){
            throw new AuraHandledException('Selecione o novo status.');
        }

        ProposalPending__c pending = [
            SELECT  Id,
                    Status__c,
                    Opportunity__r.IdVirtualOffice__c
            FROM    ProposalPending__c
            WHERE   Id = :pendingId
            LIMIT   1
        ];

        if(String.isBlank(pending.Opportunity__r.IdVirtualOffice__c)){
            throw new AuraHandledException('A oportunidade não possui o campo "ID Virtual Office" preenchido.');
        }

        Savepoint sp = Database.setSavepoint();

        try{
            pending.Status__c = status;
            update pending;
            enqueueStatusUpdate(pending.Id, status);
        } catch(Exception e){
            Database.rollback(sp);
            throw new AuraHandledException('Não foi possível atualizar o status da pendência: ' + e.getMessage());
        }

        ProposalPending__c refreshed = [
            SELECT  Id,
                    Name,
                    Description__c,
                    DocumentTypeId__c,
                    DocumentTypeName__c,
                    Status__c,
                    Response__c,
                    FileUrl__c,
                    RespondedDate__c,
                    CreatedDate,
                    LastModifiedDate
            FROM    ProposalPending__c
            WHERE   Id = :pending.Id
            LIMIT 1
        ];

        cache.remove(pending.Opportunity__r.Id);

        return toDTO(new List<ProposalPending__c>{ refreshed })[0];
    }

    @TestVisible
    static void enqueueSend(List<ProposalPending__c> records){
        if(records == null || records.isEmpty()){
            return;
        }
        List<Id> ids = new List<Id>();
        for(ProposalPending__c record : records){
            if(record.Id != null){
                ids.add(record.Id);
            }
        }
        if(!ids.isEmpty()){
            System.enqueueJob(new ProposalPendingSendQueueable(ids));
        }
    }

    @TestVisible
    static void enqueueStatusUpdate(Id pendingId, String status){
        if(pendingId == null || String.isBlank(status)){
            return;
        }
        System.enqueueJob(new ProposalPendingStatusQueueable(pendingId, status));
    }

    private static Opportunity loadOpportunity(Id opportunityId) {
        if(opportunityId == null){
            throw new AuraHandledException('Informe a oportunidade.');
        }

        Opportunity opportunity = [
            SELECT  Id, IdVirtualOffice__c
            FROM    Opportunity
            WHERE   Id = :opportunityId
            LIMIT 1
        ];

        if(String.isBlank(opportunity.IdVirtualOffice__c)){
            throw new AuraHandledException('Preencha o campo "ID Virtual Office" antes de criar uma pendência.');
        }

        return opportunity;
    }

    private static void validateInput(PendingInput input){
        if(input == null){
            throw new AuraHandledException('Registro de pendência inválido.');
        }

        if(String.isBlank(input.description)){
            System.debug(LoggingLevel.ERROR, 'Descrição vazia detectada em pending input: ' + JSON.serialize(input));
            throw new AuraHandledException('A descrição é obrigatória.');
        }

        Boolean requestDocument = input.requestDocument == true;

        if(requestDocument && input.documentTypeId == null){
            throw new AuraHandledException('Selecione o tipo de documento.');
        }

        if(!requestDocument){
            input.documentTypeId = null;
            input.documentTypeName = null;
        }
    }

    private static List<ProposalPendingDTO> toDTO(List<ProposalPending__c> records){
        List<ProposalPendingDTO> results = new List<ProposalPendingDTO>();

        for(ProposalPending__c record : records){
            ProposalPendingDTO dto = new ProposalPendingDTO();
            dto.id                = record.Id;
            dto.name              = record.Name;
            dto.description       = record.Description__c;
            dto.documentTypeId    = record.DocumentTypeId__c != null ? Integer.valueOf(record.DocumentTypeId__c.intValue()) : null;
            dto.documentTypeName  = record.DocumentTypeName__c;
            dto.status            = record.Status__c;
            dto.response          = record.Response__c;
            dto.fileUrl           = record.FileUrl__c;
            dto.respondedDate     = record.RespondedDate__c;
            dto.createdDate       = record.CreatedDate;
            dto.lastModifiedDate  = record.LastModifiedDate;
            results.add(dto);
        }

        return results;
    }

    public class PendingInput {
        @AuraEnabled public String description;
        @AuraEnabled public Integer documentTypeId;
        @AuraEnabled public String documentTypeName;
        @AuraEnabled public Boolean requestDocument;
    }

    public class ProposalPendingDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String description;
        @AuraEnabled public Integer documentTypeId;
        @AuraEnabled public String documentTypeName;
        @AuraEnabled public String status;
        @AuraEnabled public String response;
        @AuraEnabled public String fileUrl;
        @AuraEnabled public Datetime respondedDate;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Datetime lastModifiedDate;
    }
}
