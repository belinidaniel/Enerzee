@IsTest
public class ProposalPendingControllerTest {

    private class ProposalPendingCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req){
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if(req.getEndpoint().contains('TypesDocumentPending')){
                res.setBody('{"success":true,"data":[{"id":1,"name":"CPF frente"},{"id":2,"name":"RG"}]}');
                res.setStatusCode(200);
                return res;
            }

            res.setBody('{"success":true}');
            res.setStatusCode(200);
            return res;
        }
    }

    @TestSetup
    static void setupData(){
        Account account = (Account) TestFactory.createSObject(new Account(), true);
        OpportunityTriggerHandler.disableTrigger();
        Opportunity opportunity = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId = account.Id
        ), true);
        OpportunityTriggerHandler.enableTrigger();

        // Garantir que haverá ao menos uma pendência existente para o método get.
        ProposalPending__c pending = new ProposalPending__c();
        pending.Opportunity__c    = opportunity.Id;
        pending.Description__c    = 'Pendência existente';
        pending.DocumentTypeId__c = 1;
        pending.DocumentTypeName__c = 'CPF frente';
        pending.Status__c         = 'Aguardando';
        insert pending;
    }

    @IsTest
    static void shouldCreateAndListPendings(){
        Opportunity opp = [SELECT Id, IdVirtualOffice__c FROM Opportunity LIMIT 1];

        TokenAPINivelloWs.access_token = 'token';
        Test.setMock(HttpCalloutMock.class, new ProposalPendingCalloutMock());

        ProposalPendingController.PendingInput input = new ProposalPendingController.PendingInput();
        input.description = 'Foto legível RG';
        input.documentTypeId = 2;
        input.documentTypeName = 'RG';
        input.requestDocument = true;

        Test.startTest();
        String payloadJson = JSON.serialize(new List<ProposalPendingController.PendingInput>{ input });

        List<ProposalPendingController.ProposalPendingDTO> created = ProposalPendingController.createPendings(
            opp.Id,
            payloadJson
        );
        Test.stopTest();

        System.assertEquals(1, created.size(), 'Deveria criar uma pendência.');
        System.assertEquals('Foto legível RG', created[0].description);
        System.assertEquals('RG', created[0].documentTypeName);
        System.assertEquals('Aguardando', created[0].status);

        List<ProposalPendingController.ProposalPendingDTO> pendings = ProposalPendingController.getPendings(opp.Id);
        System.assert(pendings.size() >= 2, 'getPendings deve listar registros existentes.');
    }

    @IsTest
    static void shouldAllowPendingWithoutDocument(){
        Opportunity opp = [SELECT Id, IdVirtualOffice__c FROM Opportunity LIMIT 1];

        TokenAPINivelloWs.access_token = 'token';
        Test.setMock(HttpCalloutMock.class, new ProposalPendingCalloutMock());

        ProposalPendingController.PendingInput input = new ProposalPendingController.PendingInput();
        input.description = 'Sem documento';
        input.requestDocument = false;

        Test.startTest();
        List<ProposalPendingController.ProposalPendingDTO> created = ProposalPendingController.createPendings(
            opp.Id,
            JSON.serialize(new List<ProposalPendingController.PendingInput>{ input })
        );
        Test.stopTest();

        System.assertEquals(1, created.size(), 'Pendência deveria ser criada.');
        System.assertEquals(null, created[0].documentTypeId, 'Tipo de documento deve permanecer vazio.');
    }

    @IsTest
    static void shouldUpdateStatus(){
        ProposalPending__c pending = [SELECT Id, Status__c FROM ProposalPending__c LIMIT 1];

        TokenAPINivelloWs.access_token = 'token';
        Test.setMock(HttpCalloutMock.class, new ProposalPendingCalloutMock());

        Test.startTest();
        ProposalPendingController.ProposalPendingDTO updated = ProposalPendingController.updatePendingStatus(
            pending.Id,
            'Aprovado'
        );
        Test.stopTest();

        System.assertEquals('Aprovado', updated.status, 'Status deveria ser atualizado.');
    }

    @IsTest
    static void shouldReturnDocumentTypesFromService(){
        TokenAPINivelloWs.access_token = 'token';
        Test.setMock(HttpCalloutMock.class, new ProposalPendingCalloutMock());

        Test.startTest();
        List<EzeeConnectProposalPendingService.DocumentTypeOption> types = ProposalPendingController.getDocumentTypes();
        Test.stopTest();

        System.assertEquals(2, types.size(), 'Deveria retornar as opções mockadas.');
    }

    @IsTest
    static void shouldValidateVirtualOffice(){
        Account account = (Account) TestFactory.createSObject(new Account(), true);
        OpportunityTriggerHandler.disableTrigger();
        Opportunity opp = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId = account.Id
        ));
        OpportunityTriggerHandler.enableTrigger();
        opp.IdVirtualOffice__c = null;
        OpportunityTriggerHandler.disableTrigger();
        insert opp;
        OpportunityTriggerHandler.enableTrigger();

        ProposalPendingController.PendingInput input = new ProposalPendingController.PendingInput();
        input.description = 'Teste';
        input.documentTypeId = 1;
        input.documentTypeName = 'CPF frente';
        input.requestDocument = true;


        try{
            ProposalPendingController.createPendings(
                opp.Id,
                JSON.serialize(new List<ProposalPendingController.PendingInput>{ input })
            );
            System.assert(false, 'Era esperado erro por falta de ID Virtual Office.');
        } catch (AuraHandledException expected){
            System.assert(expected.getMessage().contains('ID Virtual Office'), 'Mensagem deve mencionar o campo obrigatório.');
        }
    }

}
