@IsTest
private class LeadBODistributionIntegrationTest {
    private static Integer consultantSequence = 0;

    private class IntegrationCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setHeader('Content-Type', 'application/json');
            response.setBody('{"data":{"id":"external-123"}}');
            return response;
        }
    }

    private static void ensureQueues() {
        getOrCreateQueue('QualificacaodeClientes', 'QualificacaodeClientes');
        getOrCreateQueue('Consultor', 'Consultor');
    }

    private static Id getOrCreateQueue(String developerName, String label) {
        List<Group> existing = [
            SELECT Id
            FROM Group
            WHERE DeveloperName = :developerName
                AND Type = 'Queue'
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0].Id;
        }

        Group queue = new Group(Name = label, DeveloperName = developerName, Type = 'Queue');
        insert queue;
        return queue.Id;
    }

    private static Id getLeadRecordTypeId(String developerName) {
        Map<String, Schema.RecordTypeInfo> recordTypes = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName();
        if (recordTypes == null || !recordTypes.containsKey(developerName)) {
            return null;
        }
        return recordTypes.get(developerName).getRecordTypeId();
    }

    private static Consultor__c createConsultant(
        String email,
        String city,
        String state,
        String graduation,
        DateTime lastReceived,
        Boolean receiveConsultorLead,
        Boolean receiveB2BLead
    ) {
        consultantSequence++;
        String uniqueSuffix = String.valueOf(System.now().getTime()) + '-' + String.valueOf(consultantSequence);

        Consultor__c consultorSeed = new Consultor__c(
            Email__c = email,
            Ativo__c = true,
            SendLead__c = true,
            FreezeConsult__c = false,
            Municipio__c = city,
            Estado__c = state,
            EstadoCobranca__c = state,
            Lb65_Graduacao__c = graduation,
            Lb065_UltimoLeadRecebido__c = lastReceived,
            IdVirtualOffice__c = 'vo-' + uniqueSuffix,
            NumeroIdentificacao__c = 'ni-' + uniqueSuffix
        );

        setIfExists(consultorSeed, 'ConsultantDeadlineRange__c', '3');
        setIfExists(consultorSeed, 'ReceiveConsultorLead__c', receiveConsultorLead);
        setIfExists(consultorSeed, 'ReceiveB2BLead__c', receiveB2BLead);

        Consultor__c consultor = (Consultor__c) TestFactory.createSObject(consultorSeed, true);

        return consultor;
    }

    @IsTest
    static void shouldResetIntegrationFlagAndStatusOnManualConsultantChange() {
        ensureQueues();
        Test.setMock(HttpCalloutMock.class, new IntegrationCalloutMock());

        Id clienteRt = getLeadRecordTypeId('QualificacaodeClientes');
        if (clienteRt == null) {
            return;
        }
        String saoPauloState = getSaoPauloStateValue();
        if (String.isBlank(saoPauloState)) {
            return;
        }

        Consultor__c consultorA = createConsultant(
            'manual-a@test.com',
            'Sao Paulo',
            'SP',
            'Advanced Builder',
            System.now().addDays(-5),
            false,
            false
        );
        Consultor__c consultorB = createConsultant(
            'manual-b@test.com',
            'Sao Paulo',
            'SP',
            'Advanced Builder',
            System.now().addDays(-10),
            false,
            false
        );

        Lead lead = new Lead(
            FirstName = 'Manual',
            LastName = 'Swap',
            Company = 'Enerzee',
            RecordTypeId = clienteRt,
            Status = 'Trabalhando',
            Rating = 'Warm',
            City = 'Sao Paulo',
            State = saoPauloState,
            Phone = '11990000001',
            ConsultorRegional__c = consultorA.Id,
            Lab065_IntegracaoDistribuicaoLead__c = true
        );
        applyBrazilState(lead, 'SP', saoPauloState);
        insert lead;

        Test.startTest();
        lead.ConsultorRegional__c = consultorB.Id;
        lead.Rating = 'Warm';
        applyBrazilState(lead, 'SP', saoPauloState);
        update lead;
        Test.stopTest();

        Lead updated = [
            SELECT ConsultorRegional__c, Status, Lab065_IntegracaoDistribuicaoLead__c
            FROM Lead
            WHERE Id = :lead.Id
        ];

        System.assertEquals(consultorB.Id, updated.ConsultorRegional__c, 'Troca manual de consultor deve persistir.');
        System.assertEquals('Distribuído', updated.Status, 'Status deve sair de Trabalhando para Distribuído.');
        System.assertEquals(false, updated.Lab065_IntegracaoDistribuicaoLead__c,
            'Flag tecnica deve ser resetada automaticamente na troca manual de consultor.');
    }

    @IsTest
    static void shouldAutoDistributeWorkingLeadWithoutFlowDependency() {
        ensureQueues();

        Id clienteRt = getLeadRecordTypeId('QualificacaodeClientes');
        if (clienteRt == null) {
            return;
        }
        String saoPauloState = getSaoPauloStateValue();
        if (String.isBlank(saoPauloState)) {
            return;
        }

        Consultor__c eligibleConsultant = createConsultant(
            'working-consultor@test.com',
            'Campinas',
            'SP',
            'Advanced Builder',
            System.now().addDays(-10),
            false,
            false
        );

        Lead lead = new Lead(
            FirstName = 'Working',
            LastName = 'Lead',
            Company = 'Enerzee',
            RecordTypeId = clienteRt,
            Status = 'Trabalhando',
            Rating = 'Warm',
            City = 'Campinas',
            State = saoPauloState,
            Phone = '11990000002',
            Lab065_IntegracaoDistribuicaoLead__c = true
        );
        applyBrazilState(lead, 'SP', saoPauloState);
        insert lead;

        Lead distributed = [
            SELECT ConsultorRegional__c, Status, Lab065_IntegracaoDistribuicaoLead__c
            FROM Lead
            WHERE Id = :lead.Id
        ];

        LeadDistributionSelector.Request request = new LeadDistributionSelector.Request();
        request.leadId = lead.Id;
        LeadDistributionSelector.Response debugResponse = LeadDistributionSelector.selectConsultant(
            new List<LeadDistributionSelector.Request>{ request }
        )[0];

        System.assertEquals(
            eligibleConsultant.Id,
            distributed.ConsultorRegional__c,
            'Lead em Trabalhando deve ser distribuido automaticamente via Apex. Mensagem seletor: ' +
            debugResponse.message + ' / consultor direto: ' + String.valueOf(debugResponse.consultantId)
        );
        System.assertEquals('Distribuído', distributed.Status,
            'Lead distribuido automaticamente deve ser marcado como Distribuído.');
        System.assertEquals(false, distributed.Lab065_IntegracaoDistribuicaoLead__c,
            'Distribuicao automatica deve resetar flag tecnica para reintegracao.');
    }

    @IsTest
    static void shouldAutoDistributeConsultorLeadWithNullRating() {
        ensureQueues();

        Id consultorRt = getLeadRecordTypeId('QualificacaodeConsultores');
        if (consultorRt == null) {
            return;
        }
        String saoPauloState = getSaoPauloStateValue();
        if (String.isBlank(saoPauloState)) {
            return;
        }

        Consultor__c consultorReceiver = createConsultant(
            'consultor-receiver@test.com',
            'Campinas',
            'SP',
            'Gold',
            System.now().addDays(-30),
            true,
            false
        );

        Lead consultorLead = new Lead(
            FirstName = 'Consultor',
            LastName = 'Inbound',
            Company = 'Enerzee',
            RecordTypeId = consultorRt,
            LeadSource = 'Web-To-Lead Integrador',
            Status = 'Novo',
            City = 'Campinas',
            State = saoPauloState,
            Phone = '11990000003'
        );
        applyBrazilState(consultorLead, 'SP', saoPauloState);
        insert consultorLead;

        Lead distributed = [
            SELECT ConsultorRegional__c, Status
            FROM Lead
            WHERE Id = :consultorLead.Id
        ];

        LeadDistributionSelector.Request request = new LeadDistributionSelector.Request();
        request.leadId = consultorLead.Id;
        LeadDistributionSelector.Response debugResponse = LeadDistributionSelector.selectConsultant(
            new List<LeadDistributionSelector.Request>{ request }
        )[0];

        System.assertEquals(
            consultorReceiver.Id,
            distributed.ConsultorRegional__c,
            'Lead consultor com rating nulo deve cair na regra Apex de distribuicao consultor. Mensagem seletor: ' +
            debugResponse.message + ' / consultor direto: ' + String.valueOf(debugResponse.consultantId)
        );
        System.assertEquals('Distribuído', distributed.Status,
            'Lead consultor distribuido em Apex deve ter status Distribuído.');
    }

    @IsTest
    static void shouldTagIncompleteSdrLeadAndNeutralizeProduct() {
        ensureQueues();

        Id clienteRt = getLeadRecordTypeId('QualificacaodeClientes');
        if (clienteRt == null) {
            return;
        }

        Lead sdrLead = new Lead(
            FirstName = 'SDR',
            LastName = 'Incomplete',
            Company = 'Enerzee',
            RecordTypeId = clienteRt,
            Status = 'Novo',
            SDRAgent__c = true,
            Lb065_ProdutoInteresse__c = 'Ezee Solar',
            ResumoInteracao__c = 'Cliente nao soube informar o produto exato e a conversa ficou incompleta.',
            Description = 'Conversa incompleta sem dados suficientes',
            Phone = '11990000004'
        );
        setIfExists(sdrLead, 'NotFinishMessaging__c', true);
        insert sdrLead;

        Lead updated = [
            SELECT Lb065_ProdutoInteresse__c, StatusJustification__c
            FROM Lead
            WHERE Id = :sdrLead.Id
        ];

        System.assertEquals('Não indicou ou não soube informar', updated.Lb065_ProdutoInteresse__c,
            'Quando nao houver clareza de produto no SDR, o lead deve ficar em classificacao neutra.');
        System.assert(updated.StatusJustification__c != null && updated.StatusJustification__c.contains('Lead incompleto'),
            'Lead incompleto deve ser marcado em campo tecnico de justificativa.');
    }

    private static void setIfExists(SObject record, String fieldName, Object value) {
        if (record == null || String.isBlank(fieldName)) {
            return;
        }
        if (record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldName)) {
            record.put(fieldName, value);
        }
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
