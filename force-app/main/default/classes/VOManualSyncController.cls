public with sharing class VOManualSyncController {
    public class ActionResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String correlationId;
    }

    @AuraEnabled
    public static ActionResponse syncAccount(Id accountId) {
        if (accountId == null) {
            throw new AuraHandledException('Registro de Account não informado para sincronização com VO.');
        }

        String correlationId = VOLogService.newCorrelationId('ACCBTN', accountId);
        Map<Id, String> correlationByRecordId = new Map<Id, String>{ accountId => correlationId };

        System.enqueueJob(
            new VOAccountSyncQueueable(
                new Set<Id>{ accountId },
                'Button:Account',
                false,
                correlationByRecordId
            )
        );

        ActionResponse response = new ActionResponse();
        response.success = true;
        response.correlationId = correlationId;
        response.message = 'Sincronização de Account com VO enfileirada. CorrelationId: ' + correlationId;
        return response;
    }

    @AuraEnabled
    public static ActionResponse syncOpportunity(Id opportunityId) {
        if (opportunityId == null) {
            throw new AuraHandledException('Registro de Opportunity não informado para sincronização com VO.');
        }

        Opportunity opportunityRecord = [
            SELECT Id, StageName, IdVirtualOffice__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        if (!OpportunityUtils.isStatusClosedWon(opportunityRecord)) {
            throw new AuraHandledException('A ação "Enviar para VO" está disponível apenas para oportunidades em "Ganho fechado".');
        }

        if (VOIntegrationService.hasSyncedOpportunityVoId(opportunityRecord.IdVirtualOffice__c)) {
            throw new AuraHandledException('A oportunidade já possui IdVirtualOffice__c preenchido.');
        }

        String correlationId = VOLogService.newCorrelationId('OPPBTN', opportunityId);
        Map<Id, String> correlationByRecordId = new Map<Id, String>{ opportunityId => correlationId };

        System.enqueueJob(
            new VOOpportunitySyncQueueable(
                new Set<Id>{ opportunityId },
                'Button:Opportunity',
                true,
                correlationByRecordId
            )
        );

        ActionResponse response = new ActionResponse();
        response.success = true;
        response.correlationId = correlationId;
        response.message = 'Sincronização de Opportunity com VO enfileirada. CorrelationId: ' + correlationId;
        return response;
    }
}
