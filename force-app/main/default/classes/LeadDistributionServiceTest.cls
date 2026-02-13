@isTest
private class LeadDistributionServiceTest {
    private static final String FIELD_NOT_FINISH_MESSAGING = 'NotFinishMessaging__c';
    private static Integer consultantSequence = 0;

    private static String getLeadStatusValue(String preferred) {
        for (Schema.PicklistEntry entry : Lead.Status.getDescribe().getPicklistValues()) {
            if (entry != null && entry.getValue() == preferred) {
                return entry.getValue();
            }
        }
        return null;
    }

    private static Id getLeadRecordTypeId(String developerName) {
        Map<String, Schema.RecordTypeInfo> infos = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName();
        Schema.RecordTypeInfo info = infos != null ? infos.get(developerName) : null;
        return info != null ? info.getRecordTypeId() : null;
    }

    private static Boolean hasLeadField(String fieldName) {
        return !String.isBlank(fieldName) && Schema.SObjectType.Lead.fields.getMap().containsKey(fieldName);
    }

    private static Lead queryLeadForNormalization(Id leadId, Boolean includeNotFinishMessaging) {
        String soql = 'SELECT Id, ConsultorRegional__c, Lab065_IntegracaoDistribuicaoLead__c, Lb065_ProdutoInteresse__c, Sub_Status__c';
        if (includeNotFinishMessaging) {
            soql += ', ' + FIELD_NOT_FINISH_MESSAGING;
        }
        soql += ' FROM Lead WHERE Id = :leadId';
        return (Lead) Database.query(soql);
    }

    private static String formatCpf(String digits) {
        return digits.substring(0, 3) + '.' + digits.substring(3, 6) + '.' + digits.substring(6, 9) + '-' + digits.substring(9, 11);
    }

    private static String formatCnpj(String digits) {
        return digits.substring(0, 2) + '.' + digits.substring(2, 5) + '.' + digits.substring(5, 8) + '/' + digits.substring(8, 12) + '-' + digits.substring(12, 14);
    }

    private static Consultor__c createConsultant(String email, String city, String state, DateTime lastLeadDate, Boolean receiveConsultor, Boolean receiveB2B) {
        consultantSequence++;
        String sequenceDigits = String.valueOf(DateTime.now().getTime()) + String.valueOf(consultantSequence);
        sequenceDigits = sequenceDigits.replaceAll('[^0-9]', '');
        while (sequenceDigits.length() < 14) {
            sequenceDigits += '0';
        }
        String cpfDigits = sequenceDigits.substring(sequenceDigits.length() - 11);
        String cnpjDigits = sequenceDigits.substring(sequenceDigits.length() - 14);

        return (Consultor__c) TestFactory.createSObject(new Consultor__c(
            Email__c = email,
            Ativo__c = true,
            SendLead__c = true,
            FreezeConsult__c = false,
            CPF__c = formatCpf(cpfDigits),
            CNPJ__c = formatCnpj(cnpjDigits),
            NumeroIdentificacao__c = sequenceDigits.substring(sequenceDigits.length() - 10),
            IdVirtualOffice__c = 'vo-' + sequenceDigits + '-' + consultantSequence,
            Lb65_Graduacao__c = 'Gold',
            ConsultantDeadlineRange__c = '3',
            Municipio__c = city,
            Estado__c = state,
            Lb065_UltimoLeadRecebido__c = lastLeadDate,
            ReceiveLeadConsultor__c = receiveConsultor,
            ReceiveB2BLead__c = receiveB2B
        ), true);
    }

    @isTest
    static void shouldDistributeConsultorLeadWithGeoPriority() {
        String statusNovo = getLeadStatusValue('Novo');
        String statusDistribuido = getLeadStatusValue('Distribuído');
        Id consultorRt = getLeadRecordTypeId('QualificacaodeConsultores');
        if (String.isBlank(statusNovo) || String.isBlank(statusDistribuido) || consultorRt == null) {
            return;
        }

        Consultor__c cityConsultant = createConsultant(
            'consultor.city.' + System.currentTimeMillis() + '@test.com',
            'São Paulo',
            'São Paulo SP',
            System.now().addDays(-10),
            true,
            false
        );
        Consultor__c stateConsultant = createConsultant(
            'consultor.state.' + System.currentTimeMillis() + '@test.com',
            'Campinas',
            'São Paulo SP',
            System.now().addDays(-12),
            true,
            false
        );

        Lead lead = new Lead(
            FirstName = 'Maria',
            LastName = 'Consultora',
            Company = 'Empresa Teste',
            Status = statusNovo,
            LeadSource = 'Web-To-Lead Consultor',
            RecordTypeId = consultorRt,
            City = 'São Paulo',
            State = 'SP'
        );
        insert lead;

        Lead insertedLead = [
            SELECT ConsultorRegional__c, Status, Lab065_IntegracaoDistribuicaoLead__c
            FROM Lead
            WHERE Id = :lead.Id
        ];

        System.assertEquals(cityConsultant.Id, insertedLead.ConsultorRegional__c, 'Deve priorizar consultor de mesma cidade e estado.');
        System.assertEquals(statusDistribuido, insertedLead.Status, 'Lead consultor deve ser distribuído automaticamente.');
        System.assertEquals(false, insertedLead.Lab065_IntegracaoDistribuicaoLead__c, 'A integração deve ser reprocessada.');
        System.assertNotEquals(stateConsultant.Id, insertedLead.ConsultorRegional__c, 'Consultor apenas do mesmo estado não deve ser priorizado sobre cidade+estado.');
    }

    @isTest
    static void shouldDistributeB2BLeadAndHonorMetaConsultantEmail() {
        String statusNovo = getLeadStatusValue('Novo');
        if (String.isBlank(statusNovo)) {
            return;
        }

        Consultor__c preferredConsultant = createConsultant(
            'consultor.preferred.' + System.currentTimeMillis() + '@test.com',
            'Barueri',
            'São Paulo SP',
            System.now().addDays(-3),
            false,
            true
        );
        Consultor__c roundRobinConsultant = createConsultant(
            'consultor.b2b.' + System.currentTimeMillis() + '@test.com',
            'Barueri',
            'São Paulo SP',
            System.now().addDays(-20),
            false,
            true
        );

        Lead leadWithExclusiveEmail = new Lead(
            FirstName = 'João',
            LastName = 'B2B Meta',
            Company = 'Empresa BESS',
            Status = statusNovo,
            Nome_da_Campanha_Meta__c = 'Campanha BESS 2026',
            MetaLead__c = 'Sim',
            EmailConsultor__c = preferredConsultant.Email__c,
            City = 'Barueri',
            State = 'SP'
        );
        insert leadWithExclusiveEmail;

        Lead leadWithoutExclusiveEmail = new Lead(
            FirstName = 'Ana',
            LastName = 'B2B Rodizio',
            Company = 'Empresa B2B',
            Status = statusNovo,
            Nome_da_Campanha_Meta__c = 'Campanha B2B',
            MetaLead__c = 'Sim',
            City = 'Barueri',
            State = 'SP'
        );
        insert leadWithoutExclusiveEmail;

        Map<Id, Lead> leads = new Map<Id, Lead>([
            SELECT Id, ConsultorRegional__c
            FROM Lead
            WHERE Id IN :new Set<Id>{leadWithExclusiveEmail.Id, leadWithoutExclusiveEmail.Id}
        ]);

        System.assertEquals(preferredConsultant.Id, leads.get(leadWithExclusiveEmail.Id).ConsultorRegional__c, 'Email de consultor da Meta deve ter direcionamento exclusivo.');
        System.assertEquals(roundRobinConsultant.Id, leads.get(leadWithoutExclusiveEmail.Id).ConsultorRegional__c, 'Lead B2B sem email exclusivo deve seguir rodízio entre habilitados.');
    }

    @isTest
    static void shouldNormalizeSdrLeadAndResetIntegrationFlagOnConsultantChange() {
        String statusDistribuido = getLeadStatusValue('Distribuído');
        if (String.isBlank(statusDistribuido)) {
            return;
        }
        Boolean hasNotFinishMessaging = hasLeadField(FIELD_NOT_FINISH_MESSAGING);

        Consultor__c consultantOne = createConsultant(
            'consultor.one.' + System.currentTimeMillis() + '@test.com',
            'São Paulo',
            'São Paulo SP',
            System.now().addDays(-8),
            false,
            false
        );
        Consultor__c consultantTwo = createConsultant(
            'consultor.two.' + System.currentTimeMillis() + '@test.com',
            'São Paulo',
            'São Paulo SP',
            System.now().addDays(-5),
            false,
            false
        );

        Lead lead = new Lead(
            FirstName = 'Carlos',
            LastName = 'Cliente',
            Company = 'Empresa',
            Status = statusDistribuido,
            ConsultorRegional__c = consultantOne.Id,
            Lab065_IntegracaoDistribuicaoLead__c = true,
            SDRAgent__c = true,
            Lb065_ProdutoInteresse__c = 'Ezee Solar'
        );
        insert lead;

        lead = queryLeadForNormalization(lead.Id, hasNotFinishMessaging);
        lead.ConsultorRegional__c = consultantTwo.Id;
        if (hasNotFinishMessaging) {
            lead.put(FIELD_NOT_FINISH_MESSAGING, true);
        } else {
            lead.Sub_Status__c = 'Lead incompleto';
        }
        update lead;

        Lead updatedLead = queryLeadForNormalization(lead.Id, hasNotFinishMessaging);

        System.assertEquals(false, updatedLead.Lab065_IntegracaoDistribuicaoLead__c, 'Troca de consultor deve reabrir integração.');
        System.assertEquals('Não indicou ou não soube informar', updatedLead.Lb065_ProdutoInteresse__c, 'Lead SDR incompleto deve manter produto neutro.');
        System.assertEquals('Lead incompleto', updatedLead.Sub_Status__c, 'Sub-status deve marcar lead incompleto.');
        if (hasNotFinishMessaging) {
            System.assertEquals(true, (Boolean) updatedLead.get(FIELD_NOT_FINISH_MESSAGING), 'Flag de conversa incompleta deve permanecer ativa.');
        }
    }

    @isTest
    static void shouldNotAutoDistributeWhenStatusIsNotNovo() {
        String statusTrabalhando = getLeadStatusValue('Trabalhando');
        Id consultorRt = getLeadRecordTypeId('QualificacaodeConsultores');
        if (String.isBlank(statusTrabalhando) || consultorRt == null) {
            return;
        }

        createConsultant(
            'consultor.novo.block.' + System.currentTimeMillis() + '@test.com',
            'São Paulo',
            'São Paulo SP',
            System.now().addDays(-30),
            true,
            false
        );

        Lead lead = new Lead(
            FirstName = 'Status',
            LastName = 'Nao Novo',
            Company = 'Empresa',
            Status = statusTrabalhando,
            LeadSource = 'Web-To-Lead Consultor',
            RecordTypeId = consultorRt,
            City = 'São Paulo',
            State = 'SP'
        );
        insert lead;

        Lead insertedLead = [SELECT ConsultorRegional__c, Status FROM Lead WHERE Id = :lead.Id];
        System.assertEquals(null, insertedLead.ConsultorRegional__c, 'Não deve distribuir automaticamente quando status não é Novo.');
        System.assertEquals(statusTrabalhando, insertedLead.Status, 'Status original deve ser preservado.');
    }

    @isTest
    static void shouldResetIntegrationFlagWhenLeadBecomesDistributed() {
        String statusNovo = getLeadStatusValue('Novo');
        String statusDistribuido = getLeadStatusValue('Distribuído');
        if (String.isBlank(statusNovo) || String.isBlank(statusDistribuido)) {
            return;
        }

        Consultor__c consultant = createConsultant(
            'consultor.flag.' + System.currentTimeMillis() + '@test.com',
            'São Paulo',
            'São Paulo SP',
            System.now().addDays(-15),
            false,
            false
        );

        Lead lead = new Lead(
            FirstName = 'Flag',
            LastName = 'Distribuicao',
            Company = 'Empresa',
            Status = statusNovo,
            LeadSource = 'Website',
            State = 'SP',
            Rating = 'Hot',
            ConsultorRegional__c = consultant.Id,
            Lab065_IntegracaoDistribuicaoLead__c = true
        );
        insert lead;

        lead = [SELECT Id, Status, ConsultorRegional__c, Lab065_IntegracaoDistribuicaoLead__c FROM Lead WHERE Id = :lead.Id];
        lead.Status = statusDistribuido;
        update lead;

        Lead updated = [SELECT Lab065_IntegracaoDistribuicaoLead__c FROM Lead WHERE Id = :lead.Id];
        System.assertEquals(false, updated.Lab065_IntegracaoDistribuicaoLead__c, 'Ao virar Distribuído com consultor definido, flag técnica deve ser resetada.');
    }

    @isTest
    static void shouldKeepSdrProductWhenLeadIsComplete() {
        String statusDistribuido = getLeadStatusValue('Distribuído');
        if (String.isBlank(statusDistribuido)) {
            return;
        }
        Boolean hasNotFinishMessaging = hasLeadField(FIELD_NOT_FINISH_MESSAGING);

        Consultor__c consultant = createConsultant(
            'consultor.complete.' + System.currentTimeMillis() + '@test.com',
            'São Paulo',
            'São Paulo SP',
            System.now().addDays(-10),
            false,
            false
        );

        Lead lead = new Lead(
            FirstName = 'SDR',
            LastName = 'Completo',
            Company = 'Empresa',
            Status = statusDistribuido,
            ConsultorRegional__c = consultant.Id,
            SDRAgent__c = true,
            Lb065_ProdutoInteresse__c = 'Ezee Solar'
        );
        if (hasNotFinishMessaging) {
            lead.put(FIELD_NOT_FINISH_MESSAGING, false);
        }
        insert lead;

        lead = queryLeadForNormalization(lead.Id, hasNotFinishMessaging);
        lead.Description = 'Atualização sem incompletude';
        update lead;

        Lead updated = queryLeadForNormalization(lead.Id, hasNotFinishMessaging);
        System.assertEquals('Ezee Solar', updated.Lb065_ProdutoInteresse__c, 'Produto não deve ser alterado quando o lead SDR está completo.');
    }
}
