/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 12-11-2025
 * @last modified by  : Daniel Belini
**/
@isTest
public class OpportunityTriggerTest {
    @TestSetup
    static void makeData(){
    }

    @isTest
    static void opportunityEntryRestMethodsTest(){
        Test.startTest();
        OpportunityEntryRestTest.makeData();
        OpportunityEntryRestTest.testCallout();
        Test.stopTest();
    }

    @isTest
    static void nivelloMethodsTest1(){
        IntegracaoNivelloTest.gerandoPropostaPositive();
    }

    @isTest
    static void nivelloMethodsTest2(){
        IntegracaoNivelloTest.etapaViabilidadePositive();
    }

    @isTest
    static void nivelloMethodsTest3(){
        IntegracaoNivelloTest.conclusaoViabilidadePositive();
    }

    @isTest
    static void nivelloMethodsTest4(){
        IntegracaoNivelloTest.pagamentoPositive();
    }

    @isTest
    static void nivelloMethodsTest5(){
        IntegracaoNivelloTest.conclusaoViabilidadePositive();
    }

    @isTest
    static void nivelloMethodsTest6(){
        IntegracaoNivelloTest.sendTechnicalVisitDatePositive();
    }

    @isTest
    static void createSellBuyOrderTest(){
        Test.startTest();
        ProposalCover__c ProposalCover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(), true);
        Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = ProposalCover.id,
            Produto__c = 'Solar'
        ), true);
        
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(), true);

        opportunity.StageName = 'Fechado';
        opportunity.DescontoUFV__c = 2;
        opportunity.BDI__c = 2;
        opportunity.Rede3750__c = 2;
        opportunity.Direct__c = 2;
        opportunity.ValorTotalProdutos__c = 1;
        opportunity.Parceiro__c = parceiro.id;
        update opportunity;
        Test.stopTest();
    }

    @isTest
    static void assignDefaultOwnerTest(){
        Id nivelloUserId = [
                SELECT  Id
                FROM    User
                WHERE   Email = 'daniel.belini@enerzee.com.br'
                LIMIT   1
        ].Id;
        
        Id defaultUserId = [
            SELECT  Id
            FROM    User
            WHERE   Email LIKE '%daniel.belini@enerzee.com.br'
            LIMIT   1
        ].Id;
        
        Test.startTest();
        
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(), true);
        opportunity.OwnerId = nivelloUserId;
        update opportunity;
        
        opportunity = [
            SELECT	Id, OwnerId, Origem__c
            FROM	Opportunity
            WHERE	Id = :opportunity.Id
        ];
        
        OpportunityBO.assignDefaultOwner(new List<Opportunity>{opportunity});
        update opportunity;

        Test.stopTest();

        opportunity = [
            SELECT	Id, OwnerId, Origem__c
            FROM	Opportunity
            WHERE	Id = :opportunity.Id
        ];
        
        //System.assertEquals('Nivello', opportunity.Origem__c);
        //System.assertEquals(defaultUserId, opportunity.OwnerId);
    }

    @isTest
    static void setContractSendingDateTest(){
        Test.startTest();
        
        ProposalCover__c ProposalCover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(), true);
        Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = ProposalCover.id,
            Produto__c = 'Solar'
        ), true);
        
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            DataEnvioContrato__c = null,
            Parceiro__c = parceiro.id
        ), true);
        
        //opportunity.StageName = 'Contrato enviado';
        opportunity.StageName = OpportunityUtils.STATUS_CONTRATO;
        opportunity.Status__c = OpportunityUtils.SUB_STATUS_CONTRATO_ENVIADO;
        update opportunity;
        
        opportunity = [
            SELECT	DataEnvioContrato__c
            FROM	Opportunity
            WHERE	Id = :opportunity.Id
        ];
        
        System.assertEquals(System.today(), opportunity.DataEnvioContrato__c);
        Test.stopTest();
    }

    @isTest
    static void calculateDataToProposalGraphic25YearsTest(){
        Test.startTest();
        Opportunity opportunityA = (Opportunity) TestFactory.createSObject(new Opportunity(
            GrupoTarifario__c = 'Grupo A'
        ), true);

        Opportunity opportunityB = (Opportunity) TestFactory.createSObject(new Opportunity(
            IdVirtualOffice__c = '298qejkjmklasd',
            GrupoTarifario__c = 'Grupo B'
        ), true);
        Test.stopTest();
    }

    @isTest
    public static void createProjectRecordsTest(){
        Test.startTest();
        ProposalCover__c ProposalCover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(), true);
        Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = ProposalCover.id,
            Produto__c = 'Solar'
        ), true);
        
        Account account = (Account) TestFactory.createSObject(new Account(), true);
        Consultor__c consultor = (Consultor__c) TestFactory.createSObject(new Consultor__c(), true);
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId                = account.Id,
            ConsultorOportunidade__c = consultor.Id,
            Parceiro__c				 = parceiro.id,
            PotenciaPicoSistema__c   = 12
        ), true);

        ViabilityStudy__c viability = new ViabilityStudy__c();
        viability.Opportunity__c = opportunity.Id;
        viability.TypeWorkProjectFeasibility__c = 'UFV Mini acima de 300';
        insert viability;

        opportunity.ViabilityStudyFinished__c = true;
        //opportunity.StageName = OpportunityUtils.STATUS_CONTRATO_FIRMADO_ASSINADO;
        opportunity.StageName = OpportunityUtils.STATUS_CONTRATO;
        opportunity.Status__c = OpportunityUtils.SUB_STATUS_CONTRATO_ASSINADO;
        update opportunity;

        List<Projeto__c> projetos = [
            SELECT  Conta__c, Consultor__c, UFConcessionaria__c, Concessionaria__c, 
                    Oportunidade__c, PotenciaSistema__c, Status__c
            FROM    Projeto__c
        ];
        Test.stopTest();
    }

    @isTest
    static void utilsMethodsTest(){
        Test.startTest();
        Opportunity oppt1 = (Opportunity) TestFactory.createSObject(new Opportunity(
            IdVirtualOffice__c = 'klsjdlakjdlkjas'
        ), true);
        Opportunity oppt2 = (Opportunity) TestFactory.createSObject(new Opportunity(
            IdVirtualOffice__c = '1sd2asd1d2',
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId()
        ), true);
        Opportunity oppt3 = (Opportunity) TestFactory.createSObject(new Opportunity(
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('OutrasOportunidades').getRecordTypeId()
        ), true);

        System.assert(OpportunityUtils.isRecordTypeSolar(oppt1));
        System.assert(OpportunityUtils.isRecordTypeSolar(oppt2));
        System.assert(OpportunityUtils.isRecordTypeOtherOpportunities(oppt3));


        oppt1.StageName = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA;
        System.assert(OpportunityUtils.isStatusProposalElaboration(oppt1));

        oppt1.StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE;
        System.assert(OpportunityUtils.isStatusViabilityAnalysis(oppt1));

        //oppt1.StageName = OpportunityUtils.STATUS_METODO_DE_PAGAMENTO;
        oppt1.StageName = OpportunityUtils.STATUS_CONFIRMACAO_PAGAMENTO_SINAL;
        System.assert(OpportunityUtils.isStatusPaymentConfirmationSinal(oppt1));

        oppt1.StageName = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA;
        oppt2.StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE;
        System.assert(OpportunityUtils.isChangingToViabilityAnalysis(oppt2, oppt1));

        oppt1.StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE;
        oppt2.StageName = OpportunityUtils.STATUS_CONFIRMACAO_PAGAMENTO_SINAL;
        System.assert(OpportunityUtils.isChangingToPaymentConfirmationSinal(oppt2, oppt1));

        oppt1.StageName = OpportunityUtils.STATUS_CONFIRMACAO_PAGAMENTO_SINAL;
        oppt2.StageName = OpportunityUtils.STATUS_GANHO_FECHADO;
        System.assert(OpportunityUtils.isChangingToClosedWon(oppt2, oppt1));

        oppt1.StageName = OpportunityUtils.STATUS_CONFIRMACAO_PAGAMENTO_SINAL;
        oppt2.StageName = OpportunityUtils.STATUS_FECHADO_PERDIDO;
        System.assert(OpportunityUtils.isChangingToClosedLost(oppt2, oppt1));


        oppt1.EtapaViabilidade__c = 'Agendamento';
        oppt2.EtapaViabilidade__c = 'Visita';
        System.assert(OpportunityUtils.isViabilityStepChanging(oppt2, oppt1));

        oppt1.EtapaViabilidade__c = 'Agendamento';
        oppt2.EtapaViabilidade__c = 'Estudo';
        System.assert(OpportunityUtils.isViabilityAnalysisOver(oppt2, oppt1));


        oppt1.PropostaGerada__c = false;
        oppt2.PropostaGerada__c = true;
        System.assert(OpportunityUtils.hasProposalBeenGenerated(oppt2, oppt1));

        oppt1.Proposta_aprovada__c = true;
        System.assert(OpportunityUtils.isProposalApproved(oppt1));


        oppt1.ContratoGerado__c = false;
        oppt2.ContratoGerado__c = true;
        System.assert(OpportunityUtils.hasContractBeenGenerated(oppt2, oppt1));

        oppt1.Contrato_aprovado__c = false;
        oppt2.Contrato_aprovado__c = true;
        System.assert(OpportunityUtils.hasContractBeenApproved(oppt2, oppt1));

        oppt1.Contrato_aprovado__c = true;
        System.assert(OpportunityUtils.isContractApproved(oppt1));
        Test.stopTest();
    }

    @isTest
    static void coverageOtherTriggerMethods(){
        Test.startTest();
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(), true);
      
        ViabilityStudy__c viability = new ViabilityStudy__c();
        viability.Opportunity__c = opportunity.Id;
        viability.TypeWorkProjectFeasibility__c = 'UFV Micro';
        insert viability;

        opportunity.ViabilityStudyFinished__c = true;
        opportunity.Name = 'Teste 2';
        update opportunity;

        delete [
            SELECT Id
            FROM ViabilityStudy__c
            WHERE Opportunity__c = :opportunity.Id
        ];
        delete opportunity;

        OpportunityTriggerHandler.disableTrigger();
        System.assert(!OpportunityTriggerHandler.isTriggerEnabled());
        
        OpportunityTriggerHandler.enableTrigger();
        System.assert(OpportunityTriggerHandler.isTriggerEnabled());
        Test.stopTest();
    }

    @isTest
    private static void shouldCreateCaseCustomerJourney(){

        Account account = (Account) TestFactory.createSObject(new Account(), true);

        Test.startTest();
        ProposalCover__c ProposalCover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(), true);
        Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = ProposalCover.id,
            Produto__c = 'Solar'
        ), true);
        
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId(),
            PotenciaNominalSistema__c = 250,
            GrupoTarifario__c = 'Grupo B',
            AccountId = account.Id,
            ValorTotalProdutos__c = 15000,
            Parceiro__c = parceiro.id
        ), true);

        ViabilityStudy__c viability = new ViabilityStudy__c();
        viability.Opportunity__c = opportunity.Id;
        viability.TypeWorkProjectFeasibility__c = 'UFV Mini acima de 300';
        insert viability;

        opportunity.ViabilityStudyFinished__c = true;
        //opportunity.StageName = OpportunityUtils.STATUS_CONTRATO_FIRMADO_ASSINADO;
        opportunity.StageName = OpportunityUtils.STATUS_CONTRATO;
        opportunity.Status__c = OpportunityUtils.SUB_STATUS_CONTRATO_ASSINADO;
        update opportunity;

        opportunity.StageName = OpportunityUtils.STATUS_GANHO_FECHADO;

        update opportunity;
        
        Test.stopTest();	
    }

    @isTest
    static void shareHandlerTest(){
        Test.startTest();
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(), true);
        Consultor__c consultor = (Consultor__c) TestFactory.createSObject(new Consultor__c(), true);
        
        Id user = [SELECT ID FROM USER WHERE ISACTIVE = TRUE LIMIT 1].Id;
        
        consultor.usuario__c = user;
        update consultor;

        opportunity.ConsultorOportunidade__c = consultor.id;
        update opportunity;
        
        Test.stopTest();
    }
}
