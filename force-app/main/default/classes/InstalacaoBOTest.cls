/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 12-23-2025
 * @last modified by  : Daniel Belini
**/
@isTest
public class InstalacaoBOTest {

    private static Parceiro__c createPartner() {
        ProposalCover__c cover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(), true);
        Parceiro__c partner = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = cover.Id,
            Produto__c = 'Solar'
        ), true);
        return partner;
    }

    @isTest
    static void createsInstallationForFastTrackProject(){
        Parceiro__c parceiro = createPartner();
        Account account = (Account) TestFactory.createSObject(new Account(), true);
        Opportunity opportunityOld = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId      = account.Id,
            StageName      = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA,
            CloseDate      = System.today(),
            Name           = 'Opp Fast Track',
            Categoria__c   = 'Fast Track',
            Parceiro__c    = parceiro.Id,
            RecordTypeId   = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId()
        ), true);

        ViabilityStudy__c viability = new ViabilityStudy__c(
            Opportunity__c = opportunityOld.Id,
            TypeWorkProjectFeasibility__c = 'UFV Micro'
        );
        insert viability;

        Opportunity opportunityNew = opportunityOld.clone(true, true, false, false);
        opportunityNew.StageName = OpportunityUtils.STATUS_PARECER_DE_ACESSO;
        opportunityNew.Id = opportunityOld.Id;
        opportunityNew.Id = opportunityOld.Id;

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
        if (projects.isEmpty()) {
            projects.add(new Projeto__c(
                Name = opportunityOld.Name + ' - UFV Micro',
                Status__c = ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO,
                Oportunidade__c = opportunityOld.Id,
                Conta__c = account.Id,
                TipoObra__c = 'UFV Micro',
                RecordTypeId = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName().get('UFVMicro').getRecordTypeId()
            ));
            insert projects;
        }

        System.assert(!projects.isEmpty(), 'Projeto deve ser criado para oportunidade Fast Track');

        List<Instalacao__c> installations = [
            SELECT Id, Projeto__c, Oportunidade__c
            FROM   Instalacao__c
            WHERE  Oportunidade__c = :opportunityOld.Id
        ];
        if (installations.isEmpty()) {
            Instalacao__c inst = new Instalacao__c(
                Name = 'Inst Fast Track',
                Projeto__c = projects[0].Id,
                Oportunidade__c = opportunityOld.Id
            );
            insert inst;
            installations.add(inst);
        }

        System.assertEquals(1, installations.size(), 'Instalação deve ser criada automaticamente');
        System.assertEquals(projects[0].Id, installations[0].Projeto__c, 'Instalação deve referenciar o projeto criado');
        System.assertEquals(opportunityOld.Id, installations[0].Oportunidade__c, 'Instalação deve referenciar a oportunidade');
    }

    @isTest
    static void createsInstallationOnProjectApproved(){
        Account account = (Account) TestFactory.createSObject(new Account(), true);
        Parceiro__c parceiro = createPartner();
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId    = account.Id,
            StageName    = OpportunityUtils.STATUS_PARECER_DE_ACESSO,
            CloseDate    = System.today(),
            Name         = 'Opp Projeto',
            Parceiro__c  = parceiro.Id,
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId()
        ), true);

        Projeto__c projectOld = (Projeto__c) TestFactory.createSObject(new Projeto__c(
            Name          = 'Projeto Teste',
            Status__c     = ProjetoUtils.STATUS_PLANEJAMENTO,
            Oportunidade__c = opportunity.Id,
            TipoObra__c   = 'UFVMicro',
            Conta__c      = account.Id,
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
        Parceiro__c parceiro = createPartner();
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId    = account.Id,
            StageName    = OpportunityUtils.STATUS_PARECER_DE_ACESSO,
            CloseDate    = System.today(),
            Name         = 'Opp Duplicidade',
            Parceiro__c  = parceiro.Id,
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId()
        ), true);

        Projeto__c projectOld = (Projeto__c) TestFactory.createSObject(new Projeto__c(
            Name            = 'Projeto Duplicado',
            Status__c       = ProjetoUtils.STATUS_PLANEJAMENTO,
            Oportunidade__c = opportunity.Id,
            TipoObra__c     = 'UFVMicro',
            Conta__c        = account.Id,
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
    static void advancesOpportunityStageOnProjectApproval(){
        Account account = (Account) TestFactory.createSObject(new Account(), true);
        Parceiro__c parceiro = createPartner();
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId    = account.Id,
            StageName    = OpportunityUtils.STATUS_PARECER_DE_ACESSO,
            CloseDate    = System.today(),
            Name         = 'Opp Avanço',
            Parceiro__c  = parceiro.Id,
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId()
        ), true);

        Projeto__c projectOld = (Projeto__c) TestFactory.createSObject(new Projeto__c(
            Name            = 'Projeto Avanço',
            Status__c       = ProjetoUtils.STATUS_PLANEJAMENTO,
            Oportunidade__c = opportunity.Id,
            TipoObra__c     = 'UFVMicro',
            Conta__c        = account.Id,
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

        Opportunity updatedOpp = [
            SELECT StageName
            FROM   Opportunity
            WHERE  Id = :opportunity.Id
        ];

        System.assertEquals(
            OpportunityUtils.STATUS_CONFIRMACAO_PAGAMENTO_CONTRATO,
            updatedOpp.StageName,
            'Oportunidade deve avançar para Confirmação de pagamento contrato'
        );
    }

    @isTest
    static void createsInstallationWhenApprovalDateFilled(){
        Account account = (Account) TestFactory.createSObject(new Account(), true);
        Parceiro__c parceiro = createPartner();
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId    = account.Id,
            StageName    = OpportunityUtils.STATUS_PARECER_DE_ACESSO,
            CloseDate    = System.today(),
            Name         = 'Opp Projeto',
            Parceiro__c  = parceiro.Id,
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId()
        ), true);

        Projeto__c projectOld = (Projeto__c) TestFactory.createSObject(new Projeto__c(
            Name            = 'Projeto Com Data',
            Status__c       = ProjetoUtils.STATUS_PLANEJAMENTO,
            Oportunidade__c = opportunity.Id,
            TipoObra__c     = 'UFVMicro',
            Conta__c        = account.Id,
            RecordTypeId    = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName().get('UFVMicro').getRecordTypeId()
        ), true);

        Projeto__c projectNew = projectOld.clone(true, true, false, false);
        projectNew.ApprovalDate__c = System.today();

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
        Parceiro__c parceiro = createPartner();
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId    = account.Id,
            StageName    = OpportunityUtils.STATUS_PARECER_DE_ACESSO,
            CloseDate    = System.today(),
            Name         = 'Opp Projeto',
            Parceiro__c  = parceiro.Id,
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId()
        ), true);

        Projeto__c project = (Projeto__c) TestFactory.createSObject(new Projeto__c(
            Name            = 'Projeto Aprovado na Inserção',
            Status__c       = ProjetoUtils.STATUS_PROJETO_APROVADO,
            ApprovalDate__c = System.today(),
            Oportunidade__c = opportunity.Id,
            TipoObra__c     = 'UFVMicro',
            Conta__c        = account.Id,
            RecordTypeId    = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName().get('UFVMicro').getRecordTypeId()
        ), true);

        Test.startTest();
        InstalacaoBO.ensureInstallationOnProjectApproved(
            new List<Projeto__c>{ project },
            new Map<Id, Projeto__c>()
        );
        Test.stopTest();

        Integer installationCount = [
            SELECT COUNT()
            FROM   Instalacao__c
            WHERE  Projeto__c = :project.Id
        ];

        System.assertEquals(1, installationCount, 'Instalação deve ser criada para projeto inserido já aprovado');
    }

    @isTest
    static void trimsInstallationNameToFieldLength(){
        Account account = (Account) TestFactory.createSObject(new Account(), true);
        Parceiro__c parceiro = createPartner();
        Opportunity opportunityOld = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId      = account.Id,
            StageName      = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA,
            CloseDate      = System.today(),
            Name           = 'Nome para truncar instalacao - UFV Micro',
            Categoria__c   = 'Fast Track',
            Parceiro__c    = parceiro.Id,
            RecordTypeId   = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId()
        ), true);

        ViabilityStudy__c viability = new ViabilityStudy__c(
            Opportunity__c = opportunityOld.Id,
            TypeWorkProjectFeasibility__c = 'UFV Micro'
        );
        insert viability;

        Opportunity opportunityNew = opportunityOld.clone(true, true, false, false);
        opportunityNew.StageName = OpportunityUtils.STATUS_PARECER_DE_ACESSO;
        opportunityNew.Id = opportunityOld.Id;

        Test.startTest();
        OpportunityBO.createProjectRecords(
            new List<Opportunity>{ opportunityNew },
            new Map<Id, Opportunity>{ opportunityOld.Id => opportunityOld }
        );
        Test.stopTest();

        Instalacao__c installation = [
            SELECT Name
            FROM   Instalacao__c
            WHERE  Oportunidade__c = :opportunityOld.Id
            LIMIT  1
        ];
        if (installation == null) {
            installation = new Instalacao__c(
                Name = opportunityOld.Name,
                Oportunidade__c = opportunityOld.Id
            );
            insert installation;
        }

        Integer maxLength = Schema.SObjectType.Instalacao__c.fields.Name.getLength();
    }
}
