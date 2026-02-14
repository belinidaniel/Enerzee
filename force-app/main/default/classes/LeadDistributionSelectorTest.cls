@isTest
private class LeadDistributionSelectorTest {
    private static Integer consultorSequence = 0;

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

        Consultor__c consultor = createConsultor(new Consultor__c(
            Email__c = 'a@test.com',
            SendLead__c = true,
            FreezeConsult__c = false,
            Lb65_Graduacao__c = 'Builder',
            Lb065_UltimoLeadRecebido__c = System.now().addDays(-2)
        ));

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
        String saoPauloState = getSaoPauloStateValue();
        if (String.isBlank(saoPauloState)) {
            return;
        }

        Consultor__c consultor = createConsultor(new Consultor__c(
            Estado__c = 'SP',
            SendLead__c = true,
            FreezeConsult__c = false,
            Lb65_Graduacao__c = 'Advanced Builder',
            Lb065_UltimoLeadRecebido__c = System.now().addDays(-3)
        ));

        Lead lead = new Lead(
            LastName = 'Lead State',
            Company = 'Empresa',
            Status = statusValue,
            Rating = 'Warm',
            State = saoPauloState,
            Phone = '11999999999'
        );
        applyBrazilState(lead, 'SP', saoPauloState);
        setIfExists(lead, 'Lb065_LeadVencido__c', false);
        insert lead;

        LeadDistributionSelector.Request req = new LeadDistributionSelector.Request();
        req.leadId = lead.Id;
        List<LeadDistributionSelector.Response> res = LeadDistributionSelector.selectConsultant(
            new List<LeadDistributionSelector.Request>{ req }
        );

        System.assertEquals(
            consultor.Id,
            res[0].consultantId,
            'Deve selecionar consultor pelo estado. Mensagem seletor: ' + res[0].message
        );
    }

    @isTest
    static void testSelectConsultorLeadWithGeoPriority() {
        Id consultorRt = getLeadRecordTypeId('QualificacaodeConsultores');
        if (consultorRt == null) {
            return;
        }
        String saoPauloState = getSaoPauloStateValue();
        if (String.isBlank(saoPauloState)) {
            return;
        }

        Consultor__c cityStateConsultor = createConsultor(
            new Consultor__c(
            Email__c = 'consultor-cidade@test.com',
            SendLead__c = true,
            FreezeConsult__c = false,
            Ativo__c = true,
            Lb65_Graduacao__c = 'Gold',
            Municipio__c = 'Campinas',
            EstadoCobranca__c = 'SP',
            Lb065_UltimoLeadRecebido__c = System.now().addDays(-1)
            ),
            true,
            false,
            '3'
        );

        Consultor__c stateOnlyConsultor = createConsultor(
            new Consultor__c(
            Email__c = 'consultor-estado@test.com',
            SendLead__c = true,
            FreezeConsult__c = false,
            Ativo__c = true,
            Lb65_Graduacao__c = 'Gold',
            Municipio__c = 'Santos',
            EstadoCobranca__c = 'SP',
            Lb065_UltimoLeadRecebido__c = System.now().addDays(-10)
            ),
            true,
            false,
            '3'
        );

        Lead lead = new Lead(
            LastName = 'Lead Consultor',
            Company = 'Empresa',
            Status = 'Novo',
            RecordTypeId = consultorRt,
            LeadSource = 'Web-To-Lead Integrador',
            City = 'Campinas',
            State = saoPauloState,
            Phone = '11911112222'
        );
        applyBrazilState(lead, 'SP', saoPauloState);
        insert lead;

        LeadDistributionSelector.Request req = new LeadDistributionSelector.Request();
        req.leadId = lead.Id;
        List<LeadDistributionSelector.Response> res = LeadDistributionSelector.selectConsultant(
            new List<LeadDistributionSelector.Request>{ req }
        );

        System.assertEquals(1, res.size(), 'Deve retornar uma resposta.');
        System.assertEquals(
            cityStateConsultor.Id,
            res[0].consultantId,
            'Cidade+estado deve ter prioridade sobre apenas estado. Mensagem seletor: ' + res[0].message
        );
    }

    @isTest
    static void testSelectB2BLeadAndEmailExclusiveRoute() {
        Id clienteRt = getLeadRecordTypeId('QualificacaodeClientes');
        if (clienteRt == null) {
            return;
        }
        String saoPauloState = getSaoPauloStateValue();
        if (String.isBlank(saoPauloState)) {
            return;
        }

        Consultor__c b2bSp = createConsultor(
            new Consultor__c(
            Email__c = 'b2b-sp@test.com',
            SendLead__c = true,
            FreezeConsult__c = false,
            Ativo__c = true,
            Municipio__c = 'Sao Paulo',
            EstadoCobranca__c = 'SP',
            Lb065_UltimoLeadRecebido__c = System.now().addDays(-2)
            ),
            false,
            true,
            null
        );

        Consultor__c b2bMg = createConsultor(
            new Consultor__c(
            Email__c = 'b2b-mg@test.com',
            SendLead__c = true,
            FreezeConsult__c = false,
            Ativo__c = true,
            Municipio__c = 'Belo Horizonte',
            EstadoCobranca__c = 'MG',
            Lb065_UltimoLeadRecebido__c = System.now().addDays(-20)
            ),
            false,
            true,
            null
        );

        Lead b2bLead = new Lead(
            LastName = 'Lead B2B',
            Company = 'Empresa',
            Status = 'Novo',
            RecordTypeId = clienteRt,
            LeadSource = 'Campanha B2B - BESS',
            City = 'Sao Paulo',
            State = saoPauloState,
            Phone = '11933334444'
        );
        applyBrazilState(b2bLead, 'SP', saoPauloState);
        setIfExists(b2bLead, 'Nome_da_Campanha_Meta__c', 'Campanha BESS Outbound');
        insert b2bLead;

        LeadDistributionSelector.Request reqB2B = new LeadDistributionSelector.Request();
        reqB2B.leadId = b2bLead.Id;
        List<LeadDistributionSelector.Response> b2bResponse = LeadDistributionSelector.selectConsultant(
            new List<LeadDistributionSelector.Request>{ reqB2B }
        );
        System.assertEquals(
            b2bSp.Id,
            b2bResponse[0].consultantId,
            'Lead B2B deve ir para recebedor B2B habilitado com prioridade geografica. Mensagem seletor: ' +
            b2bResponse[0].message
        );

        Consultor__c emailTarget = createConsultor(new Consultor__c(
            Email__c = 'meta-direto@test.com',
            SendLead__c = true,
            FreezeConsult__c = false,
            Ativo__c = true,
            Lb065_UltimoLeadRecebido__c = System.now().addDays(-30)
        ));

        Lead directEmailLead = new Lead(
            LastName = 'Lead Email Direto',
            Company = 'Empresa',
            Status = 'Novo',
            RecordTypeId = clienteRt,
            LeadSource = 'Campanha B2B - Meta',
            City = 'Sao Paulo',
            State = saoPauloState,
            Phone = '11955556666'
        );
        applyBrazilState(directEmailLead, 'SP', saoPauloState);
        setIfExists(directEmailLead, 'EmailConsultor__c', 'meta-direto@test.com');
        setIfExists(directEmailLead, 'Nome_da_Campanha_Meta__c', 'B2B Meta');
        insert directEmailLead;

        LeadDistributionSelector.Request reqEmail = new LeadDistributionSelector.Request();
        reqEmail.leadId = directEmailLead.Id;
        List<LeadDistributionSelector.Response> emailResponse = LeadDistributionSelector.selectConsultant(
            new List<LeadDistributionSelector.Request>{ reqEmail }
        );

        System.assertEquals(emailTarget.Id, emailResponse[0].consultantId,
            'Quando EmailConsultor__c estiver preenchido, o direcionamento deve ser exclusivo.');
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

    private static Id getLeadRecordTypeId(String developerName) {
        Map<String, Schema.RecordTypeInfo> rts = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName();
        if (rts == null || !rts.containsKey(developerName)) {
            return null;
        }
        return rts.get(developerName).getRecordTypeId();
    }

    private static void setIfExists(SObject record, String fieldName, Object value) {
        if (record == null || String.isBlank(fieldName)) {
            return;
        }
        if (record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldName)) {
            record.put(fieldName, value);
        }
    }

    private static Consultor__c createConsultor(Consultor__c consultor) {
        return createConsultor(consultor, null, null, null);
    }

    private static Consultor__c createConsultor(
        Consultor__c consultor,
        Boolean receiveConsultorLead,
        Boolean receiveB2BLead,
        String consultantDeadlineRange
    ) {
        consultorSequence++;
        String uniqueSuffix = String.valueOf(System.now().getTime()) + '-' + String.valueOf(consultorSequence);
        setIfExists(consultor, 'IdVirtualOffice__c', 'vo-selector-' + uniqueSuffix);
        setIfExists(consultor, 'NumeroIdentificacao__c', 'ni-selector-' + uniqueSuffix);
        if (consultantDeadlineRange != null) {
            setIfExists(consultor, 'ConsultantDeadlineRange__c', consultantDeadlineRange);
        }
        if (receiveConsultorLead != null) {
            setIfExists(consultor, 'ReceiveConsultorLead__c', receiveConsultorLead);
        }
        if (receiveB2BLead != null) {
            setIfExists(consultor, 'ReceiveB2BLead__c', receiveB2BLead);
        }
        return (Consultor__c) TestFactory.createSObject(consultor, true);
    }

    private static void applyBrazilState(Lead lead, String stateCode, String stateName) {
        if (lead == null) {
            return;
        }
        if (!String.isBlank(stateName)) {
            lead.State = stateName;
        }
        setIfExists(lead, 'CountryCode', 'BR');
        setIfExists(lead, 'StateCode', stateCode);
    }

    private static String getSaoPauloStateValue() {
        Schema.DescribeFieldResult stateDescribe = Lead.State.getDescribe();
        if (stateDescribe == null) {
            return null;
        }

        for (Schema.PicklistEntry entry : stateDescribe.getPicklistValues()) {
            if (entry == null || !entry.isActive()) {
                continue;
            }
            String normalized = normalizeText(entry.getValue());
            if (normalized == 'SP' || normalized.contains('SAO PAULO')) {
                return entry.getValue();
            }
        }
        return null;
    }

    private static String normalizeText(String value) {
        if (String.isBlank(value)) {
            return '';
        }
        String normalized = value.trim().toUpperCase();
        normalized = normalized.replace('Á', 'A').replace('À', 'A').replace('Â', 'A').replace('Ã', 'A').replace('Ä', 'A');
        normalized = normalized.replace('É', 'E').replace('È', 'E').replace('Ê', 'E').replace('Ë', 'E');
        normalized = normalized.replace('Í', 'I').replace('Ì', 'I').replace('Î', 'I').replace('Ï', 'I');
        normalized = normalized.replace('Ó', 'O').replace('Ò', 'O').replace('Ô', 'O').replace('Õ', 'O').replace('Ö', 'O');
        normalized = normalized.replace('Ú', 'U').replace('Ù', 'U').replace('Û', 'U').replace('Ü', 'U');
        normalized = normalized.replace('Ç', 'C');
        normalized = normalized.replaceAll('[^A-Z0-9 ]', ' ');
        normalized = normalized.replaceAll(' +', ' ');
        return normalized.trim();
    }
}
