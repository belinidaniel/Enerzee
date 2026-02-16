public without sharing class OpportunityShareHandler {
    public static void gerenciarCompartilhamentoOportunidade(List<Opportunity> newRecordList, Map<Id, Opportunity> oldRecordsMap){
        if(newRecordList == null || newRecordList.isEmpty()){
            return;
        }

        List<OpportunityShare> shares = new List<OpportunityShare>();
        Set<Id> consultorIds = new Set<Id>();
        Map<Id, Id> opportunityToConsultor = new Map<Id, Id>();
        
        for (Opportunity opp : newRecordList) {
            if (opp == null || opp.Id == null || opp.ConsultorOportunidade__c == null) {
                continue;
            }

            Opportunity oldOpp = oldRecordsMap != null ? oldRecordsMap.get(opp.Id) : null;
            Boolean hasConsultorChanged = oldOpp == null || oldOpp.ConsultorOportunidade__c != opp.ConsultorOportunidade__c;
            if(!hasConsultorChanged){
                continue;
            }

            opportunityToConsultor.put(opp.Id, opp.ConsultorOportunidade__c);
            consultorIds.add(opp.ConsultorOportunidade__c);
        }

        if(opportunityToConsultor.isEmpty()){
            return;
        }

        Map<Id, Consultor__c> consultoresMap = new Map<Id, Consultor__c>();
        if (!consultorIds.isEmpty()) {
            consultoresMap.putAll([
                SELECT Id, Usuario__c 
                FROM Consultor__c 
                WHERE Id IN :consultorIds
            ]);
        }

        for (Id opportunityId : opportunityToConsultor.keySet()) {
            Consultor__c consultor = consultoresMap.get(opportunityToConsultor.get(opportunityId));

            if (consultor != null && consultor.Usuario__c != null) {
                OpportunityShare share = new OpportunityShare();
                share.OpportunityId = opportunityId;
                share.UserOrGroupId = consultor.Usuario__c;
                share.OpportunityAccessLevel = 'Edit';
                share.RowCause = Schema.OpportunityShare.RowCause.Manual;

                shares.add(share);
            }
        }

        if (!shares.isEmpty()) {
            System.enqueueJob(new InsertOpportunityShareQueueable(shares));
        }
    }

    public class InsertOpportunityShareQueueable implements Queueable {
        private List<OpportunityShare> shares;

        public InsertOpportunityShareQueueable(List<OpportunityShare> shares) {
            this.shares = shares;
        }

        public void execute(QueueableContext context) {
            try {
                insert shares;
            } catch (DmlException e) {
                System.debug('Erro ao inserir OpportunityShare: ' + e.getMessage());
            }
        }
    }
}
