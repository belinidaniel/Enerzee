@isTest
private class LeadDistributionSelectorTest {

    @isTest
    static void testSelectByEmail() {
        Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();
        if (!leadFields.containsKey('Distributiontype__c') || !leadFields.containsKey('DistributionValue__c')) {
            return;
        }
        String statusValue = getNonNovoStatus();
        if (String.isBlank(statusValue)) {
            return;
        }

        Consultor__c consultor = (Consultor__c) TestFactory.createSObject(new Consultor__c(
            Email__c = 'a@test.com',
            SendLead__c = true,
            FreezeConsult__c = false,
            Lb65_Graduacao__c = 'Builder',
            Lb065_UltimoLeadRecebido__c = System.now().addDays(-2)
        ), true);

        Lead lead = new Lead(
            LastName = 'Lead Email',
            Company = 'Empresa',
            Status = statusValue,
            Rating = 'Warm',
            Phone = '11999999999'
        );
        setIfExists(lead, 'Lb065_LeadVencido__c', false);
        lead.put('Distributiontype__c', 'Email');
        lead.put('DistributionValue__c', 'a@test.com');
        insert lead;

        LeadDistributionSelector.Request req = new LeadDistributionSelector.Request();
        req.leadId = lead.Id;
        List<LeadDistributionSelector.Response> res = LeadDistributionSelector.selectConsultant(
            new List<LeadDistributionSelector.Request>{ req }
        );

        System.assertEquals(1, res.size(), 'Deve retornar uma resposta.');
        System.assertEquals(consultor.Id, res[0].consultantId, 'Deve selecionar o consultor pelo email.');

        Consultor__c updated = [SELECT Lb065_UltimoLeadRecebido__c FROM Consultor__c WHERE Id = :consultor.Id];
        System.assertNotEquals(null, updated.Lb065_UltimoLeadRecebido__c, 'Deve atualizar o último lead recebido.');
    }

    @isTest
    static void testSelectByStateWarm() {
        String statusValue = getNonNovoStatus();
        if (String.isBlank(statusValue)) {
            return;
        }

        Consultor__c consultor = (Consultor__c) TestFactory.createSObject(new Consultor__c(
            Estado__c = 'SP',
            SendLead__c = true,
            FreezeConsult__c = false,
            Lb65_Graduacao__c = 'Advanced Builder',
            Lb065_UltimoLeadRecebido__c = System.now().addDays(-3)
        ), true);

        Lead lead = new Lead(
            LastName = 'Lead State',
            Company = 'Empresa',
            Status = statusValue,
            Rating = 'Warm',
            State = 'SP',
            Phone = '11999999999'
        );
        setIfExists(lead, 'Lb065_LeadVencido__c', false);
        insert lead;

        LeadDistributionSelector.Request req = new LeadDistributionSelector.Request();
        req.leadId = lead.Id;
        List<LeadDistributionSelector.Response> res = LeadDistributionSelector.selectConsultant(
            new List<LeadDistributionSelector.Request>{ req }
        );

        System.assertEquals(consultor.Id, res[0].consultantId, 'Deve selecionar consultor pelo estado.');
    }

    private static String getNonNovoStatus() {
        Schema.DescribeFieldResult statusDescribe = Lead.Status.getDescribe();
        if (statusDescribe == null) {
            return null;
        }
        for (Schema.PicklistEntry entry : statusDescribe.getPicklistValues()) {
            if (entry != null && entry.getValue() != 'Novo') {
                return entry.getValue();
            }
        }
        return null;
    }

    private static void setIfExists(SObject record, String fieldName, Object value) {
        if (record == null || String.isBlank(fieldName)) {
            return;
        }
        if (record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldName)) {
            record.put(fieldName, value);
        }
    }
}