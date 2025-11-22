@isTest
public class InstalacaoBOTest {

    @isTest
    static void createsInstallationForFastTrackProject(){
        Account account = (Account) TestFactory.createSObject(new Account(), true);
        Opportunity opportunityOld = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId      = account.Id,
            StageName      = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA,
            CloseDate      = System.today(),
            Name           = 'Opp Fast Track',
            Categoria__c   = 'Fast Track',
            RecordTypeId   = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId()
        ), true);

        ViabilityStudy__c viability = new ViabilityStudy__c(
            Opportunity__c = opportunityOld.Id,
            TypeWorkProjectFeasibility__c = 'UFV Micro'
        );
        insert viability;

        Opportunity opportunityNew = opportunityOld.clone(true, true, false, false);
        opportunityNew.StageName = OpportunityUtils.STATUS_PARECER_DE_ACESSO;

        Test.startTest();
        OpportunityBO.createProjectRecords(
            new List<Opportunity>{ opportunityNew },
            new Map<Id, Opportunity>{ opportunityOld.Id => opportunityOld }
        );
        Test.stopTest();

        List<Projeto__c> projects = [
            SELECT Id, Oportunidade__c
            FROM   Projeto__c
            WHERE  Oportunidade__c = :opportunityOld.Id
        ];

        System.assert(!projects.isEmpty(), 'Projeto deve ser criado para oportunidade Fast Track');

        List<Instalacao__c> installations = [
            SELECT Id, Projeto__c, Oportunidade__c
            FROM   Instalacao__c
            WHERE  Oportunidade__c = :opportunityOld.Id
        ];

        System.assertEquals(1, installations.size(), 'Instalação deve ser criada automaticamente');
        System.assertEquals(projects[0].Id, installations[0].Projeto__c, 'Instalação deve referenciar o projeto criado');
        System.assertEquals(opportunityOld.Id, installations[0].Oportunidade__c, 'Instalação deve referenciar a oportunidade');
    }

    @isTest
    static void createsInstallationOnProjectApproved(){
        Account account = (Account) TestFactory.createSObject(new Account(), true);
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId    = account.Id,
            StageName    = OpportunityUtils.STATUS_PARECER_DE_ACESSO,
            CloseDate    = System.today(),
            Name         = 'Opp Projeto',
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId()
        ), true);

        Projeto__c projectOld = (Projeto__c) TestFactory.createSObject(new Projeto__c(
            Name          = 'Projeto Teste',
            Status__c     = ProjetoUtils.STATUS_PLANEJAMENTO,
            Oportunidade__c = opportunity.Id,
            RecordTypeId  = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName().get('UFVMicro').getRecordTypeId()
        ), true);

        Projeto__c projectNew = projectOld.clone(true, true, false, false);
        projectNew.Status__c = ProjetoUtils.STATUS_PROJETO_APROVADO;

        Test.startTest();
        InstalacaoBO.ensureInstallationOnProjectApproved(
            new List<Projeto__c>{ projectNew },
            new Map<Id, Projeto__c>{ projectOld.Id => projectOld }
        );
        Test.stopTest();

        List<Instalacao__c> installations = [
            SELECT Id, Projeto__c
            FROM   Instalacao__c
            WHERE  Projeto__c = :projectOld.Id
        ];

        System.assertEquals(1, installations.size(), 'Instalação deve ser criada ao aprovar projeto');
    }

    @isTest
    static void doesNotCreateDuplicateInstallation(){
        Account account = (Account) TestFactory.createSObject(new Account(), true);
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId    = account.Id,
            StageName    = OpportunityUtils.STATUS_PARECER_DE_ACESSO,
            CloseDate    = System.today(),
            Name         = 'Opp Duplicidade',
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId()
        ), true);

        Projeto__c projectOld = (Projeto__c) TestFactory.createSObject(new Projeto__c(
            Name            = 'Projeto Duplicado',
            Status__c       = ProjetoUtils.STATUS_PLANEJAMENTO,
            Oportunidade__c = opportunity.Id,
            RecordTypeId    = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName().get('UFVMicro').getRecordTypeId()
        ), true);

        // Cria instalação existente vinculada ao projeto
        Instalacao__c existingInstallation = new Instalacao__c(
            Name            = 'Instalação Existente',
            Projeto__c      = projectOld.Id,
            Oportunidade__c = opportunity.Id
        );
        insert existingInstallation;

        Projeto__c projectNew = projectOld.clone(true, true, false, false);
        projectNew.Status__c = ProjetoUtils.STATUS_PROJETO_APROVADO;

        Test.startTest();
        InstalacaoBO.ensureInstallationOnProjectApproved(
            new List<Projeto__c>{ projectNew },
            new Map<Id, Projeto__c>{ projectOld.Id => projectOld }
        );
        Test.stopTest();

        Integer installationCount = [
            SELECT COUNT()
            FROM   Instalacao__c
            WHERE  Projeto__c = :projectOld.Id
        ];

        System.assertEquals(1, installationCount, 'Não deve criar instalações duplicadas');
    }

    @isTest
    static void createsInstallationWhenApprovalDateFilled(){
        Account account = (Account) TestFactory.createSObject(new Account(), true);
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId    = account.Id,
            StageName    = OpportunityUtils.STATUS_PARECER_DE_ACESSO,
            CloseDate    = System.today(),
            Name         = 'Opp Projeto',
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId()
        ), true);

        Projeto__c projectOld = (Projeto__c) TestFactory.createSObject(new Projeto__c(
            Name            = 'Projeto Com Data',
            Status__c       = ProjetoUtils.STATUS_PLANEJAMENTO,
            Oportunidade__c = opportunity.Id,
            RecordTypeId    = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName().get('UFVMicro').getRecordTypeId()
        ), true);

        Projeto__c projectNew = projectOld.clone(true, true, false, false);
        projectNew.ApprovalDate__c = System.today();
        projectNew.Status__c = ProjetoUtils.STATUS_PROJETO_APROVADO;

        Test.startTest();
        InstalacaoBO.ensureInstallationOnProjectApproved(
            new List<Projeto__c>{ projectNew },
            new Map<Id, Projeto__c>{ projectOld.Id => projectOld }
        );
        Test.stopTest();

        Integer installationCount = [
            SELECT COUNT()
            FROM   Instalacao__c
            WHERE  Projeto__c = :projectOld.Id
        ];

        System.assertEquals(1, installationCount, 'Instalação deve ser criada ao preencher Data de Aprovação');
    }

    @isTest
    static void createsInstallationIfInsertedAlreadyApproved(){
        Account account = (Account) TestFactory.createSObject(new Account(), true);
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId    = account.Id,
            StageName    = OpportunityUtils.STATUS_PARECER_DE_ACESSO,
            CloseDate    = System.today(),
            Name         = 'Opp Projeto',
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId()
        ), true);

        Projeto__c project = (Projeto__c) TestFactory.createSObject(new Projeto__c(
            Name            = 'Projeto Aprovado na Inserção',
            Status__c       = ProjetoUtils.STATUS_PROJETO_APROVADO,
            ApprovalDate__c = System.today(),
            Oportunidade__c = opportunity.Id,
            RecordTypeId    = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName().get('UFVMicro').getRecordTypeId()
        ), true);

        Test.startTest();
        new ProjetoTriggerHandler().afterInsert(); // will call ensureInstallationOnProjectApproved with empty oldMap
        Test.stopTest();

        Integer installationCount = [
            SELECT COUNT()
            FROM   Instalacao__c
            WHERE  Projeto__c = :project.Id
        ];

        System.assertEquals(1, installationCount, 'Instalação deve ser criada para projeto inserido já aprovado');
    }

    @isTest
    static void createsInstallationWhenAlreadyApprovedStatusNoChange(){
        Account account = (Account) TestFactory.createSObject(new Account(), true);
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId    = account.Id,
            StageName    = OpportunityUtils.STATUS_PARECER_DE_ACESSO,
            CloseDate    = System.today(),
            Name         = 'Opp Projeto',
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId()
        ), true);

        Projeto__c projectOld = (Projeto__c) TestFactory.createSObject(new Projeto__c(
            Name            = 'Projeto Aprovado Com Mudanca',
            Status__c       = ProjetoUtils.STATUS_PLANEJAMENTO,
            Oportunidade__c = opportunity.Id,
            RecordTypeId    = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName().get('UFVMicro').getRecordTypeId()
        ), true);

        Projeto__c projectNew = projectOld.clone(true, true, false, false);
        projectNew.Status__c = ProjetoUtils.STATUS_PROJETO_APROVADO;

        Test.startTest();
        InstalacaoBO.ensureInstallationOnProjectApproved(
            new List<Projeto__c>{ projectNew },
            new Map<Id, Projeto__c>{ projectOld.Id => projectOld }
        );
        Test.stopTest();

        Integer installationCount = [
            SELECT COUNT()
            FROM   Instalacao__c
            WHERE  Projeto__c = :projectOld.Id
        ];

        System.assertEquals(1, installationCount, 'Instalação deve ser criada quando o status muda para aprovado');
    }
}
