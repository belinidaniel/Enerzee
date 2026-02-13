@isTest
private class LeadQualificationScoreServiceTest {
    private static String getLeadStatusValue(String preferred) {
        for (Schema.PicklistEntry entry : Lead.Status.getDescribe().getPicklistValues()) {
            if (entry != null && entry.getValue() == preferred) {
                return entry.getValue();
            }
        }
        return null;
    }

    private static String getCustoEnergiaByContains(String token) {
        for (Schema.PicklistEntry entry : Lead.CustoEnergiaMes__c.getDescribe().getPicklistValues()) {
            if (entry != null && entry.getValue() != null && entry.getValue().toUpperCase().contains(token.toUpperCase())) {
                return entry.getValue();
            }
        }
        return null;
    }

    @isTest
    static void shouldCalculateScoreUsingFallbackRules() {
        String statusNovo = getLeadStatusValue('Novo');
        String custoComMil = getCustoEnergiaByContains('1.000');
        if (String.isBlank(statusNovo) || String.isBlank(custoComMil)) {
            return;
        }

        LeadQualificationScoreService.disableMetadataForTest = true;
        LeadQualificationScoreService.cachedCatalog = null;

        Lead lead = new Lead(
            FirstName = 'Score',
            LastName = 'Lead',
            Company = 'Empresa',
            Status = statusNovo,
            LeadSource = 'Nivello',
            CustoEnergiaMes__c = custoComMil,
            Lb065_ProdutoInteresse__c = 'Ezee Solar'
        );
        insert lead;

        LeadQualificationScoreService.Request req = new LeadQualificationScoreService.Request();
        req.leadId = lead.Id;

        Test.startTest();
        LeadQualificationScoreService.calculateScore(new List<LeadQualificationScoreService.Request>{ req });
        Test.stopTest();

        Lead updatedLead = [
            SELECT Lb065_PontuacaoOrigem__c, Rating
            FROM Lead
            WHERE Id = :lead.Id
        ];

        System.assertEquals(23, Integer.valueOf(updatedLead.Lb065_PontuacaoOrigem__c), 'Pontuação fallback esperada: 10 (valor) + 3 (origem) + 10 (produto).');
        System.assertEquals('Cold', updatedLead.Rating, 'Classificação esperada pela regra fallback.');

        LeadQualificationScoreService.disableMetadataForTest = false;
        LeadQualificationScoreService.cachedCatalog = null;
    }

    @isTest
    static void shouldHandleUnknownInputsAndEmptyRequests() {
        String statusNovo = getLeadStatusValue('Novo');
        if (String.isBlank(statusNovo)) {
            return;
        }

        LeadQualificationScoreService.disableMetadataForTest = true;
        LeadQualificationScoreService.cachedCatalog = null;

        Lead lead = new Lead(
            FirstName = 'Score',
            LastName = 'Desconhecido',
            Company = 'Empresa',
            Status = statusNovo,
            LeadSource = 'Origem sem regra'
        );
        insert lead;

        LeadQualificationScoreService.calculateScore(new List<LeadQualificationScoreService.Request>());

        LeadQualificationScoreService.Request req = new LeadQualificationScoreService.Request();
        req.leadId = lead.Id;

        Test.startTest();
        LeadQualificationScoreService.calculateScore(new List<LeadQualificationScoreService.Request>{ req, new LeadQualificationScoreService.Request() });
        Test.stopTest();

        Lead updatedLead = [
            SELECT Lb065_PontuacaoOrigem__c, Rating
            FROM Lead
            WHERE Id = :lead.Id
        ];

        System.assertEquals(0, Integer.valueOf(updatedLead.Lb065_PontuacaoOrigem__c), 'Sem regras aplicáveis, pontuação deve ser zero.');
        System.assertEquals('Cold', updatedLead.Rating, 'Sem regras aplicáveis, classificação deve cair no threshold Cold.');

        LeadQualificationScoreService.disableMetadataForTest = false;
        LeadQualificationScoreService.cachedCatalog = null;
    }
}
