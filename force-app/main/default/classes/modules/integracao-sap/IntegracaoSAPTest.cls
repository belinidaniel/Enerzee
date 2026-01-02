@isTest
public class IntegracaoSAPTest {
    private static Boolean positiveResult = true;
    
    private static String positiveResponse = 
        '    {' +
        '        "codigoHttp": "201",' +
        '        "mensagem": "Inserido com sucesso",' +
        '        "resultado": null' +
        '    }';
    private static String negativeResponse = 
        '    {' +
        '        "codigoHttp": "400",' +
        '        "mensagem": "Erro",' +
        '        "resultado": null' +
        '    }';

    @TestSetup
    static void makeData(){
        Account account = (Account) TestFactory.createSObject(new Account(), true);
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId    = account.Id,
            Pricebook2Id = Test.getStandardPricebookId()
        ), true);
        Product2 product = (Product2) TestFactory.createSObject(new Product2(), true);
        OpportunityLineItem item = (OpportunityLineItem) TestFactory.createSObject(new OpportunityLineItem(
            OpportunityId = opportunity.Id,
            Product2Id    = product.Id
        ), true);
    }


    @isTest
    static void sendClientePositive(){
        Test.setMock(HttpCalloutMock.class, new IntegracaoSAPMock());

        Test.startTest();

        positiveResult = true;
        Account cliente = (Account) TestFactory.createSObject(new Account(
            BillingState           = 'São Paulo',
            ShippingState          = 'São Paulo',
            CPF__c                 = '347.375.188-08',
            CNPJ__c                = null,
            IdVirtualOffice__c     = 'wklasdmko3ue9as',
            NumeroIdentificacao__c = 'wklasdmko3ue9as'
        ), true);
        
        Test.stopTest();
    }

    @isTest
    static void sendClienteNegative(){
        Test.setMock(HttpCalloutMock.class, new IntegracaoSAPMock());

        Test.startTest();

        positiveResult = false;
        Account cliente = (Account) TestFactory.createSObject(new Account(
            BillingState           = 'São Paulo',
            ShippingState          = 'São Paulo',
            CPF__c                 = '347.375.188-08',
            CNPJ__c                = null,
            IdVirtualOffice__c     = 'wklasdmko3ue9as',
            NumeroIdentificacao__c = 'wklasdmko3ue9as'
        ), true);
        Test.stopTest();
    }

    // @isTest
    // static void sendFornecedorPositive(){
    //     Test.setMock(HttpCalloutMock.class, new IntegracaoSAPMock());

    //     Test.startTest();

    //     positiveResult = true;
    //     Consultor__c fornecedor = (Consultor__c) TestFactory.createSObject(new Consultor__c(), 'TestFactoryDefaults.FranchisedSeller', true);
        
    //     Test.stopTest();

    //     fornecedor = [
    //         SELECT  Id, SucessoIntegracaoSAP__c, StatusBodyIntegracaoSAP__c
    //         FROM    Consultor__c
    //         WHERE   Id = :fornecedor.Id
    //     ];

    //     System.assertEquals(true, fornecedor.SucessoIntegracaoSAP__c);
    //     System.assertEquals(
    //         '201 ' + positiveResponse + ' OK', 
    //         fornecedor.StatusBodyIntegracaoSAP__c
    //     );
    // }

    // @isTest
    // static void sendFornecedorNegative(){
    //     Test.setMock(HttpCalloutMock.class, new IntegracaoSAPMock());

    //     Test.startTest();

    //     positiveResult = false;
    //     Consultor__c fornecedor = (Consultor__c) TestFactory.createSObject(new Consultor__c(), 'TestFactoryDefaults.FranchisedSeller', true);
        
    //     Test.stopTest();

    //     fornecedor = [
    //         SELECT  Id, SucessoIntegracaoSAP__c, StatusBodyIntegracaoSAP__c
    //         FROM    Consultor__c
    //         WHERE   Id = :fornecedor.Id
    //     ];

    //     System.assertEquals(false, fornecedor.SucessoIntegracaoSAP__c);
    //     System.assertEquals(
    //         '400 ' + negativeResponse + ' Error', 
    //         fornecedor.StatusBodyIntegracaoSAP__c
    //     );
    // }

    @isTest
    static void sendRepresentantePositive(){
        Test.setMock(HttpCalloutMock.class, new IntegracaoSAPMock());

        Test.startTest();

        positiveResult = true;
        Consultor__c representante = (Consultor__c) TestFactory.createSObject(new Consultor__c(), true);
        
        Test.stopTest();
    }

    @isTest
    static void sendRepresentanteNegative(){
        Test.setMock(HttpCalloutMock.class, new IntegracaoSAPMock());

        Test.startTest();

        positiveResult = false;
        Consultor__c representante = (Consultor__c) TestFactory.createSObject(new Consultor__c(), true);
        
        Test.stopTest();
    }
    
    @isTest
    static void sendKitPositive(){
        Test.setMock(HttpCalloutMock.class, new IntegracaoSAPMock());

        Test.startTest();

        positiveResult = true;

        Opportunity opportunity = [
            SELECT  Id
            FROM    Opportunity
            LIMIT   1
        ];

        Kit_Instalacao__c kit = (Kit_Instalacao__c) TestFactory.createSObject(new Kit_Instalacao__c(
            Nome_da_Oportunidade__c = opportunity.Id
        ), true);

        OpportunityLineItem item = [
            SELECT  Kit_Instalacao__c
            FROM    OpportunityLineItem
            LIMIT   1
        ];
        item.Kit_Instalacao__c = kit.Id;
        update item;
        
        Test.stopTest();
    }

    @isTest
    static void sendKitNegative(){
        Test.setMock(HttpCalloutMock.class, new IntegracaoSAPMock());

        Test.startTest();

        positiveResult = false;
        
        Opportunity opportunity = [
            SELECT  Id
            FROM    Opportunity
            LIMIT   1
        ];

        Kit_Instalacao__c kit = (Kit_Instalacao__c) TestFactory.createSObject(new Kit_Instalacao__c(
            Nome_da_Oportunidade__c = opportunity.Id
        ), true);

        OpportunityLineItem item = [
            SELECT  Kit_Instalacao__c
            FROM    OpportunityLineItem
            LIMIT   1
        ];
        item.Kit_Instalacao__c = kit.Id;
        update item;

        Test.stopTest();
    }

    @isTest
    static void enviarPedidosPositive(){
        Test.setMock(HttpCalloutMock.class, new IntegracaoSAPMock());

        Test.startTest();

        positiveResult = true;
        
        ProposalCover__c ProposalCover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(), true);
        Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = ProposalCover.id,
            Produto__c = 'Solar'
        ), true);
        
        Opportunity opportunity = [
            SELECT  Id, StageName
            FROM    Opportunity
            LIMIT   1
        ];

        Kit_Instalacao__c kit = (Kit_Instalacao__c) TestFactory.createSObject(new Kit_Instalacao__c(
            Nome_da_Oportunidade__c = opportunity.Id
        ), true);
        
        OpportunityLineItem item = [
            SELECT  Kit_Instalacao__c
            FROM    OpportunityLineItem
            LIMIT   1
        ];
        item.Kit_Instalacao__c = kit.Id;
        update item;
            
        opportunity.StageName = OpportunityUtils.STATUS_GANHO_FECHADO;
        opportunity.Parceiro__c = parceiro.id;
        update opportunity;

        Test.stopTest();
    }

    @isTest
    static void enviarPedidosNegative(){
        Test.setMock(HttpCalloutMock.class, new IntegracaoSAPMock());

        Test.startTest();

        positiveResult = false;
        
        ProposalCover__c ProposalCover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(), true);
        Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = ProposalCover.id,
            Produto__c = 'Solar'
        ), true);
        
        Opportunity opportunity = [
            SELECT  Id, StageName
            FROM    Opportunity
            LIMIT   1
        ];

        Kit_Instalacao__c kit = (Kit_Instalacao__c) TestFactory.createSObject(new Kit_Instalacao__c(
            Nome_da_Oportunidade__c = opportunity.Id
        ), true);
        
        OpportunityLineItem item = [
            SELECT  Kit_Instalacao__c
            FROM    OpportunityLineItem
            LIMIT   1
        ];
        item.Kit_Instalacao__c = kit.Id;
        update item;
            
        opportunity.StageName = OpportunityUtils.STATUS_GANHO_FECHADO;
        opportunity.Parceiro__c = parceiro.id;
        update opportunity;

        Test.stopTest();
    }

    @isTest
    static void enviarContratoPositive(){
        Test.setMock(HttpCalloutMock.class, new IntegracaoSAPMock());

        Test.startTest();

        positiveResult = true;
        
        ProposalCover__c ProposalCover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(), true);
        Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = ProposalCover.id,
            Produto__c = 'Solar'
        ), true);
        
        Opportunity opportunity = [
            SELECT  Id, StageName
            FROM    Opportunity
            LIMIT   1
        ];

        Kit_Instalacao__c kit = (Kit_Instalacao__c) TestFactory.createSObject(new Kit_Instalacao__c(
            Nome_da_Oportunidade__c = opportunity.Id
        ), true);
        
        OpportunityLineItem item = [
            SELECT  Kit_Instalacao__c
            FROM    OpportunityLineItem
            LIMIT   1
        ];
        item.Kit_Instalacao__c = kit.Id;
        update item;
            
        opportunity.StageName = OpportunityUtils.STATUS_GANHO_FECHADO;
        opportunity.Parceiro__c = parceiro.id;
        update opportunity;

        IntegracaoSAPContrato.sendContract(new Set<Id>{opportunity.Id});

        Test.stopTest();
    }

    @isTest
    static void enviarContratoNegative(){
        Test.setMock(HttpCalloutMock.class, new IntegracaoSAPMock());

        Test.startTest();

        positiveResult = false;
        
        ProposalCover__c ProposalCover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(), true);
        Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = ProposalCover.id,
            Produto__c = 'Solar'
        ), true);
        
        Opportunity opportunity = [
            SELECT  Id, StageName
            FROM    Opportunity
            LIMIT   1
        ];

        Kit_Instalacao__c kit = (Kit_Instalacao__c) TestFactory.createSObject(new Kit_Instalacao__c(
            Nome_da_Oportunidade__c = opportunity.Id
        ), true);
        
        OpportunityLineItem item = [
            SELECT  Kit_Instalacao__c
            FROM    OpportunityLineItem
            LIMIT   1
        ];
        item.Kit_Instalacao__c = kit.Id;
        update item;
            
        //opportunity.StageName = OpportunityUtils.STATUS_GERACAO_DE_CONTRATO;
        opportunity.StageName = OpportunityUtils.STATUS_CONTRATO;
        opportunity.Status__c = OpportunityUtils.SUB_STATUS_GERACAO_CONTRATO;
        opportunity.Parceiro__c = parceiro.id;
        update opportunity;

        IntegracaoSAPContrato.sendContract(new Set<Id>{opportunity.Id});

        Test.stopTest();
    }

    public class IntegracaoSAPMock implements HttpCalloutMock{
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();

            if(positiveResult){
                res.setHeader('Content-Type', 'application/json');
                res.setBody(positiveResponse);
                res.setStatusCode(200);
                res.setStatus('OK');
            } else {
                res.setHeader('Content-Type', 'application/json');
                res.setBody(negativeResponse);
                res.setStatusCode(400);
                res.setStatus('Error');
            }

            return res;
        }
    }
}