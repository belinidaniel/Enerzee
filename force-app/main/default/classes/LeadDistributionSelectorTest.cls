@isTest
private class LeadDistributionSelectorTest {
    private static Integer consultantSequence = 0;

    private static String formatCpf(String digits) {
        return digits.substring(0, 3) + '.' + digits.substring(3, 6) + '.' + digits.substring(6, 9) + '-' + digits.substring(9, 11);
    }

    private static String formatCnpj(String digits) {
        return digits.substring(0, 2) + '.' + digits.substring(2, 5) + '.' + digits.substring(5, 8) + '/' + digits.substring(8, 12) + '-' + digits.substring(12, 14);
    }

    private static Consultor__c createConsultant(String email, String graduation, String state, String region, String city, DateTime lastLeadDate) {
        consultantSequence++;
        String sequenceDigits = String.valueOf(DateTime.now().getTime()) + String.valueOf(consultantSequence);
        sequenceDigits = sequenceDigits.replaceAll('[^0-9]', '');
        while (sequenceDigits.length() < 14) {
            sequenceDigits += '0';
        }
        String cpfDigits = sequenceDigits.substring(sequenceDigits.length() - 11);
        String cnpjDigits = sequenceDigits.substring(sequenceDigits.length() - 14);

        Consultor__c consultor = new Consultor__c(
            Email__c = email,
            Ativo__c = true,
            SendLead__c = true,
            FreezeConsult__c = false,
            CPF__c = formatCpf(cpfDigits),
            CNPJ__c = formatCnpj(cnpjDigits),
            NumeroIdentificacao__c = sequenceDigits.substring(sequenceDigits.length() - 10),
            IdVirtualOffice__c = 'vo-' + sequenceDigits + '-' + consultantSequence,
            Lb65_Graduacao__c = graduation,
            Estado__c = state,
            Municipio__c = city,
            Lb065_RegiaoConsultorEstado__c = region,
            Lb065_UltimoLeadRecebido__c = lastLeadDate
        );
        return (Consultor__c) TestFactory.createSObject(consultor, true);
    }

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

        Consultor__c consultor = createConsultant(
            'a@test.com',
            'Builder',
            'SP',
            'REGIAO-EMAIL',
            'São Paulo',
            System.now().addDays(-2)
        );

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

        Consultor__c consultor = createConsultant(
            'state.warm.' + System.currentTimeMillis() + '@test.com',
            'Advanced Builder',
            'SP',
            'REGIAO-SP',
            'São Paulo',
            System.now().addDays(-3)
        );

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

    @isTest
    static void testSelectByGraduationDistribution() {
        Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();
        if (!leadFields.containsKey('Distributiontype__c') || !leadFields.containsKey('DistributionValue__c')) {
            return;
        }
        String statusValue = getNonNovoStatus();
        if (String.isBlank(statusValue)) {
            return;
        }

        Consultor__c consultor = createConsultant(
            'graduation.' + System.currentTimeMillis() + '@test.com',
            'Gold',
            'RJ',
            'REGIAO-RJ',
            'Rio de Janeiro',
            System.now().addDays(-4)
        );

        Lead lead = new Lead(
            LastName = 'Lead Graduation',
            Company = 'Empresa',
            Status = statusValue,
            Rating = 'Warm',
            Phone = '11999999998'
        );
        lead.put('Distributiontype__c', 'Graduação');
        lead.put('DistributionValue__c', 'Gold');
        setIfExists(lead, 'Lb065_LeadVencido__c', false);
        insert lead;

        LeadDistributionSelector.Request req = new LeadDistributionSelector.Request();
        req.leadId = lead.Id;
        List<LeadDistributionSelector.Response> res = LeadDistributionSelector.selectConsultant(
            new List<LeadDistributionSelector.Request>{ req }
        );

        System.assertEquals(consultor.Id, res[0].consultantId, 'Deve selecionar consultor por graduação.');
    }

    @isTest
    static void testSelectFallbacksByRegionAndNoState() {
        String statusValue = getNonNovoStatus();
        if (String.isBlank(statusValue)) {
            return;
        }

        Consultor__c warmConsultor = createConsultant(
            'warm.' + System.currentTimeMillis() + '@test.com',
            'Builder',
            'RJ',
            null,
            'Rio de Janeiro',
            System.now().addDays(-6)
        );
        Consultor__c hotConsultor = createConsultant(
            'hot.' + System.currentTimeMillis() + '@test.com',
            'Gold',
            'RJ',
            null,
            'Rio de Janeiro',
            System.now().addDays(-7)
        );
        Consultor__c priorConsultor = createConsultant(
            'prior.' + System.currentTimeMillis() + '@test.com',
            'Diamond',
            'MG',
            null,
            'Belo Horizonte',
            System.now().addDays(-8)
        );

        Lead warmLead = new Lead(
            LastName = 'Lead Warm Region',
            Company = 'Empresa',
            Status = statusValue,
            Rating = 'Warm',
            Phone = '11999999997'
        );
        setIfExists(warmLead, 'Lb065_LeadVencido__c', false);
        insert warmLead;

        LeadDistributionSelector.Request warmReq = new LeadDistributionSelector.Request();
        warmReq.leadId = warmLead.Id;
        List<LeadDistributionSelector.Response> warmRes = LeadDistributionSelector.selectConsultant(
            new List<LeadDistributionSelector.Request>{ warmReq }
        );
        System.assertEquals(warmConsultor.Id, warmRes[0].consultantId, 'Sem estado, rating Warm deve cair no filtro de graduação sem estado.');

        Lead hotLead = new Lead(
            LastName = 'Lead Hot Region',
            Company = 'Empresa',
            Status = statusValue,
            Rating = 'Hot',
            Phone = '11999999996'
        );
        setIfExists(hotLead, 'Lb065_LeadVencido__c', false);
        insert hotLead;

        LeadDistributionSelector.Request hotReq = new LeadDistributionSelector.Request();
        hotReq.leadId = hotLead.Id;
        List<LeadDistributionSelector.Response> hotRes = LeadDistributionSelector.selectConsultant(
            new List<LeadDistributionSelector.Request>{ hotReq }
        );
        System.assertEquals(hotConsultor.Id, hotRes[0].consultantId, 'Sem estado, rating Hot deve cair no filtro de graduação sem estado.');

        Lead priorLead = new Lead(
            LastName = 'Lead Prioritario',
            Company = 'Empresa',
            Status = statusValue,
            Rating = 'Prioritário',
            Phone = '11999999995'
        );
        setIfExists(priorLead, 'Lb065_LeadVencido__c', false);
        insert priorLead;

        LeadDistributionSelector.Request priorReq = new LeadDistributionSelector.Request();
        priorReq.leadId = priorLead.Id;
        List<LeadDistributionSelector.Response> priorRes = LeadDistributionSelector.selectConsultant(
            new List<LeadDistributionSelector.Request>{ priorReq }
        );
        System.assertEquals(priorConsultor.Id, priorRes[0].consultantId, 'Deve usar filtro prioritário quando rating for Prioritário.');
    }

    @isTest
    static void testCandidateHelpers() {
        Id consultorRt = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName().containsKey('QualificacaodeConsultores')
            ? Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName().get('QualificacaodeConsultores').getRecordTypeId()
            : null;

        Lead consultorLead = new Lead(LeadSource = 'Web-To-Lead Consultor', SDRAgent__c = false, RecordTypeId = consultorRt);
        System.assertEquals(true, LeadDistributionSelector.isConsultorLeadCandidate(consultorLead), 'Lead de consultor deve ser identificado.');

        Lead b2bLead = new Lead(LeadSource = 'Campanha BESS');
        if (Schema.SObjectType.Lead.fields.getMap().containsKey('Distributiontype__c')) {
            b2bLead.put('Distributiontype__c', 'B2B');
        }
        System.assertEquals(true, LeadDistributionSelector.isB2BLeadCandidate(b2bLead), 'Lead B2B deve ser identificado.');
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
        Map<String, Schema.SObjectField> fieldMap = record.getSObjectType().getDescribe().fields.getMap();
        if (!fieldMap.containsKey(fieldName)) {
            return;
        }
        Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
        if (!fieldDescribe.isCalculated() && (fieldDescribe.isCreateable() || fieldDescribe.isUpdateable())) {
            record.put(fieldName, value);
        }
    }
}
