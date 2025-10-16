public without sharing class OpportunityController {
    @AuraEnabled
    public static void updateOpportunity(Id recordId, Decimal latitude, Decimal longitude, String telhado) {
        try {
            List<Opportunity> oppList = [SELECT Id, LocalizacaoFixa__Latitude__s, LocalizacaoFixa__Longitude__s, TipoTelhadoEstrutura__c FROM Opportunity WHERE Id = :recordId];
            List<Opportunity> oppListUpdt = new List<Opportunity>();

            if (oppList.isEmpty()) {
                throw new AuraHandledException('Oportunidade não encontrada para o ID fornecido, ID:' + recordId);
            }

            for(Opportunity opp : oppList){
            	opp.LocalizacaoFixa__Latitude__s = latitude;
            	opp.LocalizacaoFixa__Longitude__s = longitude;
                opp.TipoTelhadoEstrutura__c = telhado;
                opp.ViabilidadeDisponivel__c = false;
                oppListUpdt.add(opp);
            }
            
            update oppListUpdt;

        } catch (DmlException e) {
            throw new AuraHandledException('Erro ao atualizar a Oportunidade: ' + e.getMessage());
        }
    }
}