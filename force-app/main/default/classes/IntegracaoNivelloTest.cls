@isTest 
public class IntegracaoNivelloTest {
    private static Boolean positiveResult = true;
    
    private static String positiveResponse = 
        '    {' +
        '        "success": "true"' +
        '    }';
    private static String negativeResponse = 
        '    {' +
        '        "success": "false"' +
        '    }';

    @TestSetup
    public static void makeData(){
    }
    
    @isTest
    public static void gerandoPropostaPositive(){
        Test.setMock(HttpCalloutMock.class, new IntegracaoNivelloMock());
        
        Test.startTest();
        
        positiveResult = true;
        
        ProposalCover__c ProposalCover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(), true);
        Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = ProposalCover.id,
            Produto__c = 'Solar'
        ), true);
        
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            //StageName         = OpportunityUtils.STATUS_PROSPECCAO,
            StageName         = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA,
            PropostaGerada__c = false,
            Parceiro__c = parceiro.id
        ), true);

        ContentVersion cv = new ContentVersion();
        cv.ContentLocation        = 'S';
        cv.VersionData            = EncodingUtil.base64Decode('conteudo');
        cv.Title                  = 'Proposta Teste';
        cv.PathOnClient           = 'Proposta Test.pdf';
        cv.FirstPublishLocationId = opportunity.Id;
        insert cv;
      
        
        ViabilityStudy__c viability = new ViabilityStudy__c();
        viability.Opportunity__c = opportunity.Id;
        upsert viability;
        
        opportunity.ViabilityStudyFinished__c = true;
        opportunity.StageName = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA;
        opportunity.PropostaGerada__c = true;
        opportunity.Proposta_aprovada__c = true;
        update opportunity;
        IntegracaoNivelloProposta.gerandoProposta(opportunity.Id);
        IntegracaoNivelloProposta.gerandoProposta(opportunity.Id);

        Test.stopTest();
    }

    /*@isTest
    public static void getStatusEnum(){
        IntegracaoNivelloProposta.getStatusEnum(opportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA);
        IntegracaoNivelloProposta.getStatusEnum(opportunityUtils.STATUS_READEQUACAO_DE_PROPOSTA);
        IntegracaoNivelloProposta.getStatusEnum(opportunityUtils.STATUS_AGENDAMENTO_DA_VISITA_TECNICA);
        IntegracaoNivelloProposta.getStatusEnum(opportunityUtils.STATUS_METODO_DE_PAGAMENTO);
        IntegracaoNivelloProposta.getStatusEnum(opportunityUtils.STATUS_GANHO_FECHADO);
        IntegracaoNivelloProposta.getStatusEnum(opportunityUtils.STATUS_VALIDACAO_DO_METODO_DE_PAGAMENTO);
        IntegracaoNivelloProposta.getStatusEnum(opportunityUtils.STATUS_PROPOSTA_ENVIADA_AGUARDANDO_ACEITE);
        IntegracaoNivelloProposta.getStatusEnum(opportunityUtils.STATUS_GANHO_FECHADO);
        IntegracaoNivelloProposta.getStatusEnum(opportunityUtils.STATUS_CONTRATO_ENVIADO);
        IntegracaoNivelloProposta.getStatusEnum(opportunityUtils.STATUS_CONTRATO_FIRMADO_ASSINADO);
    }*/
    @isTest
    public static void etapaViabilidadePositive(){
        Test.setMock(HttpCalloutMock.class, new IntegracaoNivelloMock());
        
        Test.startTest();
        
        positiveResult = true;
        
        ProposalCover__c ProposalCover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(), true);
        Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = ProposalCover.id,
            Produto__c = 'Solar'
        ), true);
        
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            StageName = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA,
            Parceiro__c = parceiro.id
        ), true);
        
        opportunity.ViabilityStudyFinished__c = true;
        opportunity.StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE;
        opportunity.EtapaViabilidade__c = 'Agendamento';
        update opportunity;

        Test.stopTest();
    }

    @isTest
    public static void conclusaoViabilidadePositive(){
        Test.setMock(HttpCalloutMock.class, new IntegracaoNivelloMock());
        
        Test.startTest();
        
        positiveResult = true;
        
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE
        ), true);
        

        ViabilityStudy__c viability = new ViabilityStudy__c();
        viability.Opportunity__c = opportunity.Id;
        viability.TypeWorkProjectFeasibility__c = 'UFV Micro';
        upsert viability;
        
        opportunity.ViabilityStudyFinished__c = true;
        opportunity.EtapaViabilidade__c = 'Estudo';
        update opportunity;

        Test.stopTest();
    }

    
    @isTest
    public static void pagamentoPositive(){
        Test.setMock(HttpCalloutMock.class, new IntegracaoNivelloMock());
        
        Test.startTest();
        
        positiveResult = true;
        
        ProposalCover__c ProposalCover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(), true);
        Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = ProposalCover.id,
            Produto__c = 'Solar'
        ), true);
        
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE,
            Parceiro__c = parceiro.id
        ), true);
        
        opportunity.ViabilityStudyFinished__c = true;
        //opportunity.StageName = OpportunityUtils.STATUS_GERACAO_DE_CONTRATO;
        opportunity.StageName 	 = OpportunityUtils.STATUS_CONTRATO;
        opportunity.Status__c 	 = OpportunityUtils.SUB_STATUS_GERACAO_CONTRATO;
        opportunity.Categoria__c = 'Fast Track';
        IntegracaoNivelloProposta.sendUrlSimulation(new Set<Id>{opportunity.Id});
        update opportunity;

        ViabilityStudy__c viability = new ViabilityStudy__c();
        viability.Opportunity__c = opportunity.Id;
        viability.TypeWorkProjectFeasibility__c = 'UFV Micro';
        upsert viability;

        Test.stopTest();
    }

    @isTest
    public static void finalizacaoPropostaPositive(){
        Test.setMock(HttpCalloutMock.class, new IntegracaoNivelloMock());
        
        Test.startTest();
        
        positiveResult = true;
        
        ProposalCover__c ProposalCover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(), true);
        Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = ProposalCover.id,
            Produto__c = 'Solar'
        ), true);

        Account account = (Account) TestFactory.createSObject(new Account(), true);
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            //StageName               = OpportunityUtils.STATUS_METODO_DE_PAGAMENTO,
            StageName               = OpportunityUtils.STATUS_CONFIRMACAO_PAGAMENTO_SINAL,
            AccountId               = account.Id,
            Classificacao__c        = 'Contratos de Locação',
            NumeroOrigemContrato__c = '123',
            ValorTotalProdutos__c	= 1,
            Parceiro__c = parceiro.id
        ), true);

        ContentVersion cv = new ContentVersion();
        cv.ContentLocation        = 'S';
        cv.VersionData            = EncodingUtil.base64Decode('conteudo');
        cv.Title                  = 'Proposta Teste';
        cv.PathOnClient           = 'Proposta Test.pdf';
        cv.FirstPublishLocationId = opportunity.Id;
        insert cv;
        
        opportunity.ViabilityStudyFinished__c = true;
        opportunity.StageName = OpportunityUtils.STATUS_GANHO_FECHADO;
        update opportunity;

        ViabilityStudy__c viability = new ViabilityStudy__c();
        viability.Opportunity__c = opportunity.Id;
        viability.TypeWorkProjectFeasibility__c = 'UFV Micro';
        upsert viability;
        
        Test.stopTest();
    }

    @isTest
    public static void sendTechnicalVisitDatePositive(){
        Test.setMock(HttpCalloutMock.class, new IntegracaoNivelloMock());
        
        Test.startTest();
        
        positiveResult = true;
        
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            StageName                    = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE,
            PrazoAprovacaoViabilidade__c = null
        ), true);
        
        opportunity.ViabilityStudyFinished__c = true;
        opportunity.PrazoAprovacaoViabilidade__c = System.now();
        update opportunity;

        ViabilityStudy__c viability = new ViabilityStudy__c();
        viability.Opportunity__c = opportunity.Id;
        viability.TypeWorkProjectFeasibility__c = 'UFV Micro';
        upsert viability;

        ServiceAppointment serviceAppointment = (ServiceAppointment) TestFactory.createSObject(new ServiceAppointment(
            ParentRecordId  = opportunity.Id,
            Oportunidade__c = opportunity.Id
        ), true);
        
        Test.stopTest();
    }

    @isTest
    static void enviarContratoPositive(){
        Test.setMock(HttpCalloutMock.class, new IntegracaoNivelloMock());
        
        Test.startTest();
        
        positiveResult = true;
        
        ProposalCover__c ProposalCover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(), true);
        Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = ProposalCover.id,
            Produto__c = 'Solar'
        ), true);
        
        Account account = (Account) TestFactory.createSObject(new Account(), true);
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            StageName               = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE,
            AccountId               = account.Id,
            Classificacao__c        = 'Contratos de Locação',
            NumeroOrigemContrato__c = '123',
            Parceiro__c = parceiro.id
        ), true);
        
        opportunity.ViabilityStudyFinished__c = true;
        //opportunity.StageName = OpportunityUtils.STATUS_CONTRATO_FIRMADO_ASSINADO;
        opportunity.StageName = OpportunityUtils.STATUS_CONTRATO;
        opportunity.Status__c = OpportunityUtils.SUB_STATUS_CONTRATO_ASSINADO;
        opportunity.Categoria__c = 'Fast Track';
        update opportunity;

        ViabilityStudy__c viability = new ViabilityStudy__c();
        viability.Opportunity__c = opportunity.Id;
        upsert viability;
        
        Test.stopTest();
    }

    
    @isTest
    static void sendTechnicalVisitAnalysisPositive(){
        Test.setMock(HttpCalloutMock.class, new IntegracaoNivelloMock());
        
        Test.startTest();
        
        positiveResult = true;
        
        Account account = (Account) TestFactory.createSObject(new Account(), true);
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            StageName               = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE,
            AccountId               = account.Id,
            Classificacao__c        = 'Contratos de Locação',
            NumeroOrigemContrato__c = '123'
        ), true);
            
        opportunity.ViabilityStudyFinished__c = true;
        opportunity.StatusViabilidade__c = 'Parcialmente Viável';
        update opportunity;

        ViabilityStudy__c viability = new ViabilityStudy__c();
        viability.Opportunity__c = opportunity.Id;
        viability.TypeWorkProjectFeasibility__c = 'UFV Micro';
        upsert viability;
        
        Test.stopTest();
    }

    @isTest
    public static void gerandoPropostaNegative(){
        Test.setMock(HttpCalloutMock.class, new IntegracaoNivelloMock());
        
        Test.startTest();
        
        positiveResult = false;
        
        ProposalCover__c ProposalCover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(), true);
        Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = ProposalCover.id,
            Produto__c = 'Solar'
        ), true);
        
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            //StageName         = OpportunityUtils.STATUS_PROSPECCAO,
            StageName         = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA,
            PropostaGerada__c = false,
            Parceiro__c = parceiro.id
        ), true);

        ContentVersion cv = new ContentVersion();
        cv.ContentLocation        = 'S';
        cv.VersionData            = EncodingUtil.base64Decode('conteudo');
        cv.Title                  = 'Proposta Teste';
        cv.PathOnClient           = 'Proposta Test.pdf';
        cv.FirstPublishLocationId = opportunity.Id;
        insert cv;
        
        opportunity.ViabilityStudyFinished__c = true;
        opportunity.StageName = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA;
        opportunity.PropostaGerada__c = true;
        update opportunity;

        ViabilityStudy__c viability = new ViabilityStudy__c();
        viability.Opportunity__c = opportunity.Id;
        viability.TypeWorkProjectFeasibility__c = 'UFV Micro';
        upsert viability;
        
        Test.stopTest();
    }

    @isTest
    public static void etapaViabilidadeNegative(){
        Test.setMock(HttpCalloutMock.class, new IntegracaoNivelloMock());
        
        Test.startTest();
        
        positiveResult = false;
        
        ProposalCover__c ProposalCover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(), true);
        Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = ProposalCover.id,
            Produto__c = 'Solar'
        ), true);
        
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            StageName = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA,
            Parceiro__c = parceiro.id
        ), true);
        
        opportunity.ViabilityStudyFinished__c = true;
        opportunity.StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE;
        opportunity.EtapaViabilidade__c = 'Agendamento';
        update opportunity;

        ViabilityStudy__c viability = new ViabilityStudy__c();
        viability.Opportunity__c = opportunity.Id;
        viability.TypeWorkProjectFeasibility__c = 'UFV Micro';
        upsert viability;
        
        Test.stopTest();
    }

    @isTest
    public static void conclusaoViabilidadeNegative(){
        Test.setMock(HttpCalloutMock.class, new IntegracaoNivelloMock());
        
        Test.startTest();
        
        positiveResult = false;
        
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE
        ), true);
        
        opportunity.ViabilityStudyFinished__c = true;
        opportunity.EtapaViabilidade__c = 'Estudo';
        update opportunity;

        ViabilityStudy__c viability = new ViabilityStudy__c();
        viability.Opportunity__c = opportunity.Id;
        viability.TypeWorkProjectFeasibility__c = 'UFV Micro';
        upsert viability;
        
        Test.stopTest();
    }

    
    @isTest
    public static void pagamentoNegative(){
        Test.setMock(HttpCalloutMock.class, new IntegracaoNivelloMock());
        
        Test.startTest();
        
        positiveResult = false;
        
        ProposalCover__c ProposalCover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(), true);
        Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = ProposalCover.id,
            Produto__c = 'Solar'
        ), true);
        
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE,
            Parceiro__c = parceiro.id
        ), true);
        opportunity.ViabilityStudyFinished__c = true;
        //opportunity.StageName = OpportunityUtils.STATUS_GERACAO_DE_CONTRATO;
        opportunity.StageName = OpportunityUtils.STATUS_CONTRATO;
        opportunity.Status__c = OpportunityUtils.SUB_STATUS_GERACAO_CONTRATO;
        opportunity.Categoria__c = 'Fast Track';
        update opportunity;

        ViabilityStudy__c viability = new ViabilityStudy__c();
        viability.Opportunity__c = opportunity.Id;
        viability.TypeWorkProjectFeasibility__c = 'UFV Micro';
        upsert viability;
        
        Test.stopTest();
    }

    @isTest
    public static void finalizacaoPropostaNegative(){
        Test.setMock(HttpCalloutMock.class, new IntegracaoNivelloMock());
        
        Test.startTest();
        
        positiveResult = false;
        
        ProposalCover__c ProposalCover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(), true);
        Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = ProposalCover.id,
            Produto__c = 'Solar'
        ), true);
        
        Account account = (Account) TestFactory.createSObject(new Account(), true);
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            //StageName               = OpportunityUtils.STATUS_METODO_DE_PAGAMENTO,
            StageName               = OpportunityUtils.STATUS_CONFIRMACAO_PAGAMENTO_SINAL,
            AccountId               = account.Id,
            Classificacao__c        = 'Contratos de Locação',
            NumeroOrigemContrato__c = '123',
            ValorTotalProdutos__c	= 1,
            Parceiro__c = parceiro.id
        ), true);

        ContentVersion cv = new ContentVersion();
        cv.ContentLocation        = 'S';
        cv.VersionData            = EncodingUtil.base64Decode('conteudo');
        cv.Title                  = 'Proposta Teste';
        cv.PathOnClient           = 'Proposta Test.pdf';
        cv.FirstPublishLocationId = opportunity.Id;
        insert cv;
        
        opportunity.StageName = OpportunityUtils.STATUS_GANHO_FECHADO;
        opportunity.ViabilityStudyFinished__c = true;
        update opportunity;

        ViabilityStudy__c viability = new ViabilityStudy__c();
        viability.Opportunity__c = opportunity.Id;
        viability.TypeWorkProjectFeasibility__c = 'UFV Micro';
        upsert viability;
        
        Test.stopTest();
    }

    @isTest
    public static void sendTechnicalVisitDateNegative(){
        Test.setMock(HttpCalloutMock.class, new IntegracaoNivelloMock());
        
        Test.startTest();
        
        positiveResult = false;
        
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            StageName                    = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE,
            PrazoAprovacaoViabilidade__c = null
        ), true);
        
        opportunity.ViabilityStudyFinished__c = true;
        opportunity.PrazoAprovacaoViabilidade__c = System.now();
        update opportunity;

        ViabilityStudy__c viability = new ViabilityStudy__c();
        viability.Opportunity__c = opportunity.Id;
        viability.TypeWorkProjectFeasibility__c = 'UFV Micro';
        upsert viability;

        ServiceAppointment serviceAppointment = (ServiceAppointment) TestFactory.createSObject(new ServiceAppointment(
            ParentRecordId  = opportunity.Id,
            Oportunidade__c = opportunity.Id
        ), true);
        
        Test.stopTest();
    }

    @isTest
    static void enviarContratoNegative(){
        Test.setMock(HttpCalloutMock.class, new IntegracaoNivelloMock());
        
        Test.startTest();
        
        positiveResult = false;
        
        ProposalCover__c ProposalCover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(), true);
        Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = ProposalCover.id,
            Produto__c = 'Solar'
        ), true);
        
        Account account = (Account) TestFactory.createSObject(new Account(), true);
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            StageName               = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE,
            AccountId               = account.Id,
            Classificacao__c        = 'Contratos de Locação',
            NumeroOrigemContrato__c = '123',
            Parceiro__c = parceiro.id
        ), true);
        
        opportunity.ViabilityStudyFinished__c = true;
        //opportunity.StageName = OpportunityUtils.STATUS_CONTRATO_FIRMADO_ASSINADO;
        opportunity.StageName = OpportunityUtils.STATUS_CONTRATO;
        opportunity.Status__c = OpportunityUtils.SUB_STATUS_CONTRATO_ASSINADO;
        opportunity.Categoria__c = 'Fast Track';
        update opportunity;

        ViabilityStudy__c viability = new ViabilityStudy__c();
        viability.Opportunity__c = opportunity.Id;
        upsert viability;
        
        Test.stopTest();
    }
    
    @isTest
    static void sendTechnicalVisitAnalysisNegative(){
        Test.setMock(HttpCalloutMock.class, new IntegracaoNivelloMock());
        
        Test.startTest();
        
        positiveResult = false;
        
        Account account = (Account) TestFactory.createSObject(new Account(), true);
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            StageName               = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE,
            AccountId               = account.Id,
            Classificacao__c        = 'Contratos de Locação',
            NumeroOrigemContrato__c = '123'
        ), true);
            
        opportunity.ViabilityStudyFinished__c = true;
        opportunity.StatusViabilidade__c = 'Parcialmente Viável';
        update opportunity;

        ViabilityStudy__c viability = new ViabilityStudy__c();
        viability.Opportunity__c = opportunity.Id;
        viability.TypeWorkProjectFeasibility__c = 'UFV Micro';
        upsert viability;
        
        Test.stopTest();
    }
    
    public class IntegracaoNivelloMock implements HttpCalloutMock{
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();

            String responseString = positiveResult ? positiveResponse : negativeResponse;
            Integer statusCodeToUse = positiveResult ? 200 : 400;

            res.setHeader('Content-Type', 'application/json');
            res.setBody(responseString);
            res.setStatusCode(statusCodeToUse);
            res.setStatus('OK');

            return res;
        }
    }
}