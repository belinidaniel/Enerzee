@isTest
public class UtilsTest {
    @isTest
    static void callIntegrationNivelloTest(){
        Test.setMock(HttpCalloutMock.class, new IntegracaoSAPExemploMock());

        Test.startTest();

        TokenAPINivelloWs.access_token = 'teste';
        
        ProposalCover__c ProposalCover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(), true);
        Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = ProposalCover.id,
            Produto__c = 'Solar'
        ), true);

        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            StageName = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA,
            Parceiro__c = parceiro.id
        ), true);
        
        opportunity.StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE;
        opportunity.EtapaViabilidade__c = 'Agendamento';
        update opportunity;

        Test.stopTest();
    }

    @isTest
    static void callIntegrationSAPTest(){
        Test.setMock(HttpCalloutMock.class, new IntegracaoSAPExemploMock());

        Test.startTest();

        Account cliente = (Account) TestFactory.createSObject(new Account(), true);
        
        Test.stopTest();
    }

    @isTest
    static void createLogTest(){
        //  Exception
        try{
            Integer num = 5 / 0;
        }catch(Exception e){
            Utils.createLog('UtilsTest', 'createLogTest', e);
        }

        //  RestRequest
        OpportunityEntryRestTest.makeData();
        OpportunityEntryRestTest.testCallout();

        //  HttpResponse
        callIntegrationNivelloTest();
    }

    @isTest
    static void notificacaoPersonalizadaTest(){
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(), true);

        Utils.notificacaoPersonalizada('mensagem', 'titulo', opportunity.Id, opportunity.Id);
    }
    
    public class IntegracaoSAPExemploMock implements HttpCalloutMock{
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();

            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '    {' +
                '        "codigoHttp": "201",' +
                '        "mensagem": "Inserido com sucesso",' +
                '        "resultado": null' +
                '    }'
            );
            res.setStatusCode(200);
            res.setStatus('OK');

            return res;
        }
    }

    public class IntegracaoNivelloMock implements HttpCalloutMock{
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();

            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '    {' +
                '        "success": "true"' +
                '    }'
            );
            res.setStatusCode(200);
            res.setStatus('OK');

            return res;
        }
    }
}