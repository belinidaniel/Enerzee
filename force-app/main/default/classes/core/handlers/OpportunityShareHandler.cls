public without sharing class OpportunityShareHandler {
    public static void gerenciarCompartilhamentoOportunidade(List<Opportunity> newRecordList, Map<Id, Opportunity> oldRecordsMap){
        List<OpportunityShare> shares = new List<OpportunityShare>();

        Map<Id, Consultor__c> consultoresMap = new Map<Id, Consultor__c>();
        
        for (Opportunity opp : newRecordList) {
            if (opp.ConsultorOportunidade__c != null) {
                consultoresMap.put(opp.ConsultorOportunidade__c, null);
            }
        }

        if (!consultoresMap.isEmpty()) {
            consultoresMap.putAll([
                SELECT Id, Usuario__c 
                FROM Consultor__c 
                WHERE Id IN :consultoresMap.keySet()
            ]);
        }

        for (Opportunity opp : newRecordList) {
            if (opp.ConsultorOportunidade__c != null) {
                Consultor__c consultor = consultoresMap.get(opp.ConsultorOportunidade__c);

                if (consultor != null && consultor.Usuario__c != null) {
                    OpportunityShare share = new OpportunityShare();
                    share.OpportunityId = opp.Id;
                    share.UserOrGroupId = consultor.Usuario__c;
                    share.OpportunityAccessLevel = 'Edit';
                    share.RowCause = Schema.OpportunityShare.RowCause.Manual; 

                    shares.add(share);
                }
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