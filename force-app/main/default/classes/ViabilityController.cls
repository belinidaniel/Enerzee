public without sharing class ViabilityController {
    @AuraEnabled
    public static void updateViability(
        Id recordId,
        Decimal latitude,
        Decimal longitude,
        String telhado,
        Id consultorId,
        String adequacyEnerzeeValues,
        String adequacyClientValues,
        Decimal technicalVisitCost,
        String ownTeamThirdParty
    ) {
        try {
            List<ViabilityStudy__c> viaList = [
                SELECT  Id,
                        LocalizacaoFixa__Latitude__s,
                        LocalizacaoFixa__Longitude__s,
                        FixationStructureVerifiedPlace__c
                FROM    ViabilityStudy__c
                WHERE   Id = :recordId
            ];
            List<ViabilityStudy__c> viaListUpdt = new List<ViabilityStudy__c>();

            if (viaList.isEmpty()) {
                throw new AuraHandledException('Viabilidade não encontrada para o ID fornecido, ID:' + recordId);
            }

            for (ViabilityStudy__c via : viaList) {
                via.LocalizacaoFixa__Latitude__s = latitude;
                via.LocalizacaoFixa__Longitude__s = longitude;
                via.FixationStructureVerifiedPlace__c = telhado;
                via.EstudoViabilidadeLocal__c = false;
                via.DateTimeVisit__c = System.now();
                via.StatusFeasibility__c = 'Aguardando Elaboração de Estudo';
                via.Consultor__c = consultorId;
                via.AdequacyCostEnerzee__c = adequacyEnerzeeValues;
                via.AdequacyCostClient__c = adequacyClientValues;
                via.TechnicalVisitCost__c = technicalVisitCost;
                via.OwnTeamThirdParty__c = ownTeamThirdParty;
                viaListUpdt.add(via);
            }
            
            update viaListUpdt;

        } catch (DmlException e) {
            throw new AuraHandledException('Erro ao atualizar a Viabilidade: ' + e.getMessage());
        }
    }
}
