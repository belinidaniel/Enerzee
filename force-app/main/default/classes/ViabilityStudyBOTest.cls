/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 11-03-2025
 * @last modified by  : Daniel Belini
**/
@isTest
private class ViabilityStudyBOTest {

    private static Integer userCounter = 0;

    @testSetup
    static void setupQueues(){
        List<Group> queues = new List<Group>{
            new Group(
                Name = 'Assistente Comercial / Viabilidade',
                DeveloperName = 'Assistente_Comercial_Viabilidade_T',
                Type = 'Queue'
            ),
            new Group(
                Name = 'Financeiro',
                DeveloperName = 'Financeiro_Viabilidade_T',
                Type = 'Queue'
            ),
            new Group(
                Name = 'Estagiário de Engenharia / Viabilidade',
                DeveloperName = 'Estagiario_Engenharia_Viabilidade_T',
                Type = 'Queue'
            )
        };

        insert queues;

        List<QueueSobject> queueSObjects = new List<QueueSobject>();
        for(Group queueRecord : queues){
            queueSObjects.add(new QueueSobject(
                QueueId = queueRecord.Id,
                SobjectType = 'Task'
            ));
        }
        insert queueSObjects;

        ViabilityStudyBO.TaskViabilityTable table = new ViabilityStudyBO.TaskViabilityTable();
        table.tableLines = new List<ViabilityStudyBO.TaskViabilityTableLine>();

        ViabilityStudyBO.TaskViabilityTableLine queueLine = new ViabilityStudyBO.TaskViabilityTableLine();
        queueLine.TipoViabilidade     = 'Solar';
        queueLine.Status              = 'AGENDAMENTO_DE_VISITA_TECNICA';
        queueLine.Assunto             = 'AGENDAMENTO DE VISITA';
        queueLine.Acoes               = 'TEXTO';
        queueLine.Responsavel         = 'Assistente Comercial / Viabilidade';
        queueLine.Interessados        = 'Coordenador de Viabilidade';
        queueLine.PrazoDiasUteis      = '7';
        queueLine.DataVencimentoDMais = '7';
        queueLine.TipoProprietario    = 'QUEUE';
        table.tableLines.add(queueLine);

        ViabilityStudyBO.TaskViabilityTableLine roleLineStudy = new ViabilityStudyBO.TaskViabilityTableLine();
        roleLineStudy.TipoViabilidade     = 'Solar';
        roleLineStudy.Status              = 'ESTUDO_EM_ELABORACAO';
        roleLineStudy.Assunto             = 'ELABORAR ESTUDO DE VIABILIDADE';
        roleLineStudy.Acoes               = 'TEXTO';
        roleLineStudy.Responsavel         = 'Coordenador de Viabilidade';
        roleLineStudy.Interessados        = 'Coordenador de Viabilidade';
        roleLineStudy.PrazoDiasUteis      = '7';
        roleLineStudy.DataVencimentoDMais = '7';
        roleLineStudy.TipoProprietario    = 'ROLE';
        table.tableLines.add(roleLineStudy);

        ViabilityStudyBO.TaskViabilityTableLine roleLineCloud = new ViabilityStudyBO.TaskViabilityTableLine();
        roleLineCloud.TipoViabilidade     = 'Solar';
        roleLineCloud.Status              = 'ESTUDO_EM_ELABORACAO';
        roleLineCloud.Assunto             = 'ELABORAR NUVEM DE PONTOS';
        roleLineCloud.Acoes               = 'TEXTO';
        roleLineCloud.Responsavel         = 'Coordenador de Viabilidade';
        roleLineCloud.Interessados        = 'Coordenador de Viabilidade';
        roleLineCloud.PrazoDiasUteis      = '7';
        roleLineCloud.DataVencimentoDMais = '7';
        roleLineCloud.TipoProprietario    = 'ROLE';
        table.tableLines.add(roleLineCloud);

        ViabilityStudyBO.taskTableOverride = table;
        ViabilityStudyBO.resetTestState();
    }

    private static Opportunity createOpportunity(){
        Account accountRecord = (Account) TestFactory.createSObject(new Account(), true);
        Opportunity opportunityRecord = new Opportunity(
            AccountId = accountRecord.Id
        );
        return (Opportunity) TestFactory.createSObject(opportunityRecord, true);
    }

    private static User createActiveUser(Id roleId){
        Profile profile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        userCounter++;
        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + '_' + userCounter;
        String alias = ('vown' + userCounter).left(8);

        User userRecord = new User(
            FirstName = 'Viability',
            LastName  = 'User ' + userCounter,
            Alias     = alias,
            Email     = 'viability.user+' + uniqueSuffix + '@example.com',
            Username  = 'viability.user+' + uniqueSuffix + '@example.com',
            TimeZoneSidKey     = 'America/Sao_Paulo',
            LocaleSidKey       = 'pt_BR',
            EmailEncodingKey   = 'UTF-8',
            LanguageLocaleKey  = 'pt_BR',
            ProfileId          = profile.Id,
            UserRoleId         = roleId
        );

        insert userRecord;
        return userRecord;
    }

    @isTest
    static void testCreateTasksOnInsert(){
        ViabilityStudyBO.resetTestState();

        Opportunity opportunity = createOpportunity();

        ViabilityStudy__c viability = new ViabilityStudy__c(
            Opportunity__c = opportunity.Id,
            StatusFeasibility__c = 'Agendamento de Visita Técnica'
        );

        Test.startTest();
        insert viability;
        Test.stopTest();

        List<Task> tasks = [
            SELECT  Subject, OwnerId, PrazoDiasUteis__c
            FROM    Task
            WHERE   WhatId = :viability.Id
        ];

        System.assertEquals(1, tasks.size(), 'A single task should be created for the initial viability status.');

        Group queueRecord = [
            SELECT Id
            FROM Group
            WHERE Name = 'Assistente Comercial / Viabilidade'
            LIMIT 1
        ];

        System.assertEquals(queueRecord.Id, tasks[0].OwnerId, 'Task should be assigned to Assistente Comercial / Viabilidade queue.');
        System.assertEquals('7', tasks[0].PrazoDiasUteis__c);
    }

    @isTest
    static void testCreateTasksOnStatusChange(){
        ViabilityStudyBO.resetTestState();

        UserRole coordinatorRole = new UserRole(
            Name = 'Coordenador de Viabilidade',
            DeveloperName = 'Coordenador_de_Viabilidade',
            RollupDescription = 'Role utilizado para testes de distribuição por papel'
        );
        insert coordinatorRole;

        User roleUserRecent = createActiveUser(coordinatorRole.Id);
        User roleUserIdle = createActiveUser(coordinatorRole.Id);

        System.runAs(roleUserRecent){
            Opportunity opportunity = createOpportunity();

            ViabilityStudy__c viability = new ViabilityStudy__c(
                Opportunity__c = opportunity.Id,
                StatusFeasibility__c = 'Agendamento de Visita Técnica',
                Owner__c = roleUserRecent.Id
            );
            insert viability;

            Task historicalTask = new Task(
                Subject = 'Histórico Papel',
                OwnerId = roleUserRecent.Id,
                WhatId = viability.Id,
                ActivityDate = Date.today()
            );
            insert historicalTask;

            ViabilityStudyBO.resetTestState();

            Test.startTest();
            update new ViabilityStudy__c(
                Id = viability.Id,
                StatusFeasibility__c = 'Estudo em Elaboração',
                Owner__c = roleUserRecent.Id
            );
            Test.stopTest();

            List<Task> roleTasks = [
                SELECT  Subject, OwnerId
                FROM    Task
                WHERE   WhatId = :viability.Id AND Subject IN ('ELABORAR ESTUDO DE VIABILIDADE', 'ELABORAR NUVEM DE PONTOS')
            ];

            System.assertEquals(2, roleTasks.size(), 'Both role-based tasks should have been created.');

            Map<String, Task> tasksBySubject = new Map<String, Task>();
            for(Task taskRecord : roleTasks){
                tasksBySubject.put(taskRecord.Subject, taskRecord);
            }

            System.assertEquals(roleUserIdle.Id, tasksBySubject.get('ELABORAR ESTUDO DE VIABILIDADE').OwnerId, 'User with the oldest assignment should receive the first task.');
            System.assertEquals(roleUserRecent.Id, tasksBySubject.get('ELABORAR NUVEM DE PONTOS').OwnerId, 'Next task should rotate to the next available user.');

            Integer initialCount = [
                SELECT COUNT()
                FROM Task
                WHERE WhatId = :viability.Id
            ];

            Test.startTest();
            update new ViabilityStudy__c(
                Id = viability.Id,
                StatusFeasibility__c = 'Estudo em Elaboração',
                Owner__c = roleUserRecent.Id
            );
            Test.stopTest();

            Integer finalCount = [
                SELECT COUNT()
                FROM Task
                WHERE WhatId = :viability.Id
            ];

            System.assertEquals(initialCount, finalCount, 'Tasks should not be duplicated when the status remains unchanged.');
        }
    }

    @isTest
    static void testSolicitarNovoIntegradorConditional(){
        ViabilityStudyBO.resetTestState();

        Opportunity opportunity = createOpportunity();

        ViabilityStudy__c viabilityWithout = new ViabilityStudy__c(
            Opportunity__c = opportunity.Id,
            StatusFeasibility__c = 'Agendamento de Visita Técnica',
            OwnTeamThirdParty__c = 'Enerzee'
        );
        insert viabilityWithout;

        Test.startTest();
        update new ViabilityStudy__c(
            Id = viabilityWithout.Id,
            StatusFeasibility__c = 'Visita Agendada'
        );
        Test.stopTest();

        List<Task> tasksWithout = [
            SELECT  Id
            FROM    Task
            WHERE   WhatId = :viabilityWithout.Id
            AND     Subject = 'SOLICITAR NOVO INTEGRADOR'
        ];
        System.assertEquals(0, tasksWithout.size(), 'Task should not be created when integrador já cadastrado.');

        ViabilityStudyBO.resetTestState();

        ViabilityStudy__c viabilityWith = new ViabilityStudy__c(
            Opportunity__c = opportunity.Id,
            StatusFeasibility__c = 'Agendamento de Visita Técnica',
            OwnTeamThirdParty__c = 'Nao_cadastrado'
        );
        insert viabilityWith;

        Test.startTest();
        update new ViabilityStudy__c(
            Id = viabilityWith.Id,
            StatusFeasibility__c = 'Visita Agendada'
        );
        Test.stopTest();

        List<Task> tasksWith = [
            SELECT  Id
            FROM    Task
            WHERE   WhatId = :viabilityWith.Id
            AND     Subject = 'SOLICITAR NOVO INTEGRADOR'
        ];
        System.assertEquals(1, tasksWith.size(), 'Task should be created when integrador não cadastrado.');
    }

    @isTest
    static void testNotifyViabilityInvoiceAttachment(){
        ViabilityStudyBO.resetTestState();

        Opportunity opportunity = createOpportunity();
        ViabilityStudy__c viability = new ViabilityStudy__c(
            Opportunity__c = opportunity.Id,
            StatusFeasibility__c = 'Agendamento de Visita Técnica'
        );
        insert viability;

        Task taskRecord = new Task(
            Subject = 'SOLICITAR PAGAMENTO DE INTEGRADOR',
            WhatId = viability.Id,
            OwnerId = UserInfo.getUserId(),
            Status = 'Not Started',
            ActivityDate = Date.today()
        );
        insert taskRecord;

        ContentVersion version = new ContentVersion(
            Title = 'NF Integrador',
            PathOnClient = 'NF.pdf',
            VersionData = Blob.valueOf('test data'),
            FirstPublishLocationId = UserInfo.getUserId()
        );
        insert version;
        version = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :version.Id
        ];

        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = version.ContentDocumentId
        );

        Test.startTest();
        TaskBO.notifyViabilityInvoiceAttachment(taskRecord, link);
        Test.stopTest();
    }

    @isTest
    static void testViabilityStatusAutoProgression(){
        ViabilityStudyBO.resetTestState();

        Opportunity opportunity = createOpportunity();
        ViabilityStudy__c viability = new ViabilityStudy__c(
            Opportunity__c = opportunity.Id,
            StatusFeasibility__c = 'Agendamento de Visita Técnica'
        );
        insert viability;

        Task taskRecord = new Task(
            Subject = 'AGENDAMENTO DE VISITA',
            WhatId = viability.Id,
            OwnerId = UserInfo.getUserId(),
            Status = 'Not Started',
            ActivityDate = Date.today()
        );
        insert taskRecord;

        Task oldTask = taskRecord.clone(false, true, false, false);
        Task newTask = taskRecord.clone(false, true, false, false);
        newTask.Status = 'Completed';

        Map<Id, Task> oldMap = new Map<Id, Task>{ taskRecord.Id => oldTask };

        Test.startTest();
        TaskBO.updateViabilityStatusOnTaskCompletion(new List<Task>{ newTask }, oldMap);
        Test.stopTest();

        ViabilityStudy__c updated = [
            SELECT StatusFeasibility__c
            FROM ViabilityStudy__c
            WHERE Id = :viability.Id
        ];
        System.assertEquals('Visita Agendada', updated.StatusFeasibility__c, 'Status should advance after concluding appointment task.');

        Task finalTask = new Task(
            Subject = 'ANEXAR ARQUIVOS DE VIABILIDADE',
            WhatId = viability.Id,
            OwnerId = UserInfo.getUserId(),
            Status = 'Not Started',
            ActivityDate = Date.today()
        );
        insert finalTask;

        Task oldFinal = finalTask.clone(false, true, false, false);
        Task newFinal = finalTask.clone(false, true, false, false);
        newFinal.Status = 'Completed';

        Test.startTest();
        TaskBO.updateViabilityStatusOnTaskCompletion(new List<Task>{ newFinal }, new Map<Id, Task>{ finalTask.Id => oldFinal });
        Test.stopTest();

        ViabilityStudy__c finalUpdated = [
            SELECT StatusFeasibility__c
            FROM ViabilityStudy__c
            WHERE Id = :viability.Id
        ];
        System.assertEquals('Viabilidade Finalizada', finalUpdated.StatusFeasibility__c, 'Status should close after concluding final task.');
    }

    @isTest
    static void testSyncOpportunityInstalledPower(){
        ViabilityStudyBO.resetTestState();

        Opportunity opportunity = createOpportunity();

        ViabilityStudy__c viability = new ViabilityStudy__c(
            Opportunity__c = opportunity.Id,
            StatusFeasibility__c = 'Agendamento de Visita Técnica',
            InstalledPowerKwp__c = 10
        );
        insert viability;

        Opportunity refreshed = [
            SELECT PotenciaPicoSistema__c
            FROM Opportunity
            WHERE Id = :opportunity.Id
        ];
        System.assertEquals(10, refreshed.PotenciaPicoSistema__c, 'Opportunity should inherit KWp on viabilidade creation.');

        Test.startTest();
        update new ViabilityStudy__c(
            Id = viability.Id,
            InstalledPowerKwp__c = 15
        );
        Test.stopTest();

        Opportunity refreshedAfter = [
            SELECT PotenciaPicoSistema__c
            FROM Opportunity
            WHERE Id = :opportunity.Id
        ];
        System.assertEquals(15, refreshedAfter.PotenciaPicoSistema__c, 'Opportunity KWp should reflect updated viability value.');
    }
}
