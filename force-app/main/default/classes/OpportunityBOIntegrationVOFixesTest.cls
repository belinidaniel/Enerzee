@IsTest
private class OpportunityBOIntegrationVOFixesTest {
    private static User createUserWithEmail(String emailValue, String aliasPrefix) {
        Id profileId = [SELECT Id FROM Profile LIMIT 1].Id;
        String uniqueToken = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.mod(Crypto.getRandomInteger(), 10000));

        User userRecord = new User(
            Alias = (aliasPrefix + uniqueToken).left(8),
            Email = emailValue,
            Username = uniqueToken + '.' + emailValue,
            LastName = 'VOFix',
            TimeZoneSidKey = 'America/Sao_Paulo',
            LocaleSidKey = 'pt_BR',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'pt_BR',
            ProfileId = profileId
        );
        insert userRecord;
        return userRecord;
    }

    @IsTest
    static void createRequiredFieldsReminderTasksShouldCreateFinanceSimulationTaskWithoutNpe() {
        Account accountRecord = new Account(Name = 'Conta Simulacao');
        insert accountRecord;

        Opportunity persistedOpp = new Opportunity(
            Name = 'Opp Simulacao Financiamento',
            AccountId = accountRecord.Id,
            StageName = 'Prospecção',
            CloseDate = Date.today().addDays(10)
        );
        insert persistedOpp;

        Opportunity oldOpportunity = new Opportunity(
            Id = persistedOpp.Id,
            AccountId = accountRecord.Id,
            OwnerId = persistedOpp.OwnerId,
            StageName = 'Prospecção',
            Financiamento_solicitado__c = false
        );

        Opportunity newOpportunity = new Opportunity(
            Id = persistedOpp.Id,
            AccountId = accountRecord.Id,
            OwnerId = persistedOpp.OwnerId,
            StageName = 'Prospecção',
            Financiamento_solicitado__c = true
        );

        List<User> financeOwners = [
            SELECT Id
            FROM User
            WHERE Email LIKE 'dayane.silva@enerzee.com.br%'
            AND IsActive = true
            LIMIT 1
        ];
        Id expectedOwnerId = financeOwners.isEmpty() ? UserInfo.getUserId() : financeOwners[0].Id;

        Test.startTest();
        OpportunityBO.createRequiredFieldsReminderTasks(
            new List<Opportunity>{ newOpportunity },
            new Map<Id, Opportunity>{ persistedOpp.Id => oldOpportunity }
        );
        Test.stopTest();

        Task createdTask = [
            SELECT Subject, OwnerId, WhatId
            FROM Task
            WHERE WhatId = :persistedOpp.Id
            AND Subject LIKE 'Anexar Simulações de Financiamento%'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        System.assertEquals(expectedOwnerId, createdTask.OwnerId, 'Task de simulação financeira deve usar owner resolvido com fallback.');
    }

    @IsTest
    static void createRequiredFieldsReminderTasksShouldUseSlotSevenOwnerForAwaitingPayment() {
        User paymentOwner = createUserWithEmail('financeiro@enerzee.com.br.test', 'fin');

        Account accountRecord = new Account(Name = 'Conta Pagamento');
        insert accountRecord;

        Opportunity persistedOpp = new Opportunity(
            Name = 'Opp Aguardando Pagamento',
            AccountId = accountRecord.Id,
            StageName = 'Prospecção',
            CloseDate = Date.today().addDays(5)
        );
        insert persistedOpp;

        Opportunity oldOpportunity = new Opportunity(
            Id = persistedOpp.Id,
            AccountId = accountRecord.Id,
            OwnerId = persistedOpp.OwnerId,
            StageName = 'Prospecção',
            Status__c = null
        );

        Opportunity newOpportunity = new Opportunity(
            Id = persistedOpp.Id,
            AccountId = accountRecord.Id,
            OwnerId = persistedOpp.OwnerId,
            StageName = 'Negociação',
            Status__c = OpportunityUtils.SUB_STATUS_AGUARDANDO_PAGAMENTO
        );

        Test.startTest();
        OpportunityBO.createRequiredFieldsReminderTasks(
            new List<Opportunity>{ newOpportunity },
            new Map<Id, Opportunity>{ persistedOpp.Id => oldOpportunity }
        );
        Test.stopTest();

        Task createdTask = [
            SELECT Subject, OwnerId, WhatId
            FROM Task
            WHERE WhatId = :persistedOpp.Id
            AND Subject LIKE 'É necessário  confirmar o pagamento da oportunidade%'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        System.assertEquals(paymentOwner.Id, createdTask.OwnerId, 'Task de pagamento deve usar o owner do slot 7 (financeiro).');
    }
}
