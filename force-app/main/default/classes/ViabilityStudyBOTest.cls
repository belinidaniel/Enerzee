/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 11-08-2025
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

        

        Group queueRecord = [
            SELECT Id
            FROM Group
            WHERE Name = 'Assistente Comercial / Viabilidade'
            LIMIT 1
        ];

        
        
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

        List<FeedItem> viabilityFeedPosts = [
            SELECT  Id, Body, ParentId
            FROM    FeedItem
            WHERE   ParentId = :viability.Id
        ];

    }
}
