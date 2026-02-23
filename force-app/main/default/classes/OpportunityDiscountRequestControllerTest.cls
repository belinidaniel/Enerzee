@IsTest
private class OpportunityDiscountRequestControllerTest {
    private static final String TARGET_STAGE = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA;
    private static final String TARGET_STAGE_PROPOSAL_GENERATED = OpportunityUtils.STATUS_PROPOSTA_GERADA;
    private static final String PROPOSAL_ATTACHMENT_TYPE = 'Proposal';
    private static String lastRequestBody;
    private static String lastEndpoint;
    private static Id partnerId;
    private static Id accountId;

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            OpportunityDiscountRequestControllerTest.lastRequestBody = req.getBody();
            OpportunityDiscountRequestControllerTest.lastEndpoint = req.getEndpoint();

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success":true}');
            return res;
        }
    }

    private class Http400Mock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setStatus('Bad Request');
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error":"payload inválido"}');
            return res;
        }
    }

    private class TimeoutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Read timed out');
        }
    }

    @IsTest
    static void shouldSendDiscountRequestAndConvertPercentage() {
        Opportunity opp = createOpportunity(TARGET_STAGE, 'VO-001', 16017.36, 'https://example.com/prefill.pdf');
        OpportunityAttachmentLink__c oldProposal = createAttachment(
            opp.Id,
            'https://example.com/proposta-antiga.pdf',
            PROPOSAL_ATTACHMENT_TYPE
        );
        OpportunityAttachmentLink__c latestProposal = createAttachment(
            opp.Id,
            'https://example.com/proposta-final.pdf',
            PROPOSAL_ATTACHMENT_TYPE
        );
        Test.setCreatedDate(oldProposal.Id, DateTime.now().addMinutes(-10));
        Test.setCreatedDate(latestProposal.Id, DateTime.now().addMinutes(-1));
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        TokenAPINivelloWs.access_token = 'token';

        Test.startTest();
        OpportunityDiscountRequestController.DiscountSubmitResult result =
            OpportunityDiscountRequestController.submitDiscountRequest(
                opp.Id,
                null,
                20,
                'Solicitação de desconto de teste'
            );
        Test.stopTest();

        System.assertEquals(true, result.success, 'Envio deveria retornar sucesso.');
        System.assertEquals(200, result.statusCode, 'Status HTTP esperado 200.');
        System.assertEquals(Decimal.valueOf('3203.47'), result.requestDiscount, 'Conversão 20% de 16017,36 deve resultar em 3203,47.');

        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(lastRequestBody);
        System.assertEquals('VO-001', payload.get('id'), 'Payload deve enviar IdVirtualOffice__c.');
        System.assertEquals(1, Integer.valueOf(String.valueOf(payload.get('StatusDiscount'))), 'StatusDiscount deve ser fixo em 1.');
        System.assertEquals(null, payload.get('JustifyObs'), 'JustifyObs deve ser null.');
        System.assertEquals(null, payload.get('FileProposal'), 'FileProposal deve ser null.');
        System.assertEquals('Solicitação de desconto de teste', String.valueOf(payload.get('discountApprovalComments')));
        System.assertEquals('https://example.com/proposta-final.pdf', String.valueOf(payload.get('urlFile')));
        System.assertEquals(Decimal.valueOf('3203.47'), Decimal.valueOf(String.valueOf(payload.get('requestDiscount'))));
        System.assertNotEquals(null, lastEndpoint, 'Endpoint do callout deve ser preenchido a partir do metadata.');
        System.assert(lastEndpoint.toLowerCase().contains('/api/proposal/discount'), 'Endpoint deve apontar para /api/Proposal/discount.');

        List<Log__c> logs = [
            SELECT RelatedId__c, StatusCode__c, RequestURI__c, RequestBody__c, Class__c, Method__c
            FROM Log__c
            WHERE RelatedId__c = :String.valueOf(opp.Id)
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals(1, logs.size(), 'Deve registrar log técnico.');
        System.assertEquals(200, logs[0].StatusCode__c, 'Log deve registrar status HTTP de sucesso.');
        System.assertEquals('ProposalDiscountService', logs[0].Class__c, 'Classe de log deve seguir padrão da integração.');
        System.assertEquals('requestDiscount', logs[0].Method__c, 'Método de log deve seguir padrão da integração.');
        System.assert(logs[0].RequestBody__c.contains('"StatusDiscount":1'), 'Log deve conter o payload enviado.');
    }

    @IsTest
    static void shouldHandleHttp400Error() {
        Opportunity opp = createOpportunity(TARGET_STAGE, 'VO-400', 1000, 'https://example.com/file.pdf');
        createAttachment(opp.Id, 'https://example.com/file.pdf', PROPOSAL_ATTACHMENT_TYPE);
        Test.setMock(HttpCalloutMock.class, new Http400Mock());
        TokenAPINivelloWs.access_token = 'token';

        Test.startTest();
        try {
            OpportunityDiscountRequestController.submitDiscountRequest(
                opp.Id,
                100,
                null,
                'Teste erro'
            );
            System.assert(false, 'Era esperado erro para retorno 400.');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage(), 'A falha de integração deve retornar mensagem para o usuário.');
        }
        Test.stopTest();

        List<Log__c> logs = [
            SELECT StatusCode__c, Class__c, Method__c, Message__c
            FROM Log__c
            WHERE RelatedId__c = :String.valueOf(opp.Id)
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals(400, logs[0].StatusCode__c, 'Log deve registrar status 400.');
        System.assertEquals('ProposalDiscountService', logs[0].Class__c, 'Classe de log deve seguir padrão da integração.');
        System.assertEquals('requestDiscount', logs[0].Method__c, 'Método de log deve seguir padrão da integração.');
        System.assert(
            logs[0].Message__c != null && logs[0].Message__c.contains('Erro de integração de desconto. HTTP 400.'),
            'Mensagem técnica do log deve informar o HTTP 400.'
        );
    }

    @IsTest
    static void shouldHandleTimeout() {
        Opportunity opp = createOpportunity(TARGET_STAGE, 'VO-TIMEOUT', 1000, 'https://example.com/file.pdf');
        createAttachment(opp.Id, 'https://example.com/file.pdf', PROPOSAL_ATTACHMENT_TYPE);
        Test.setMock(HttpCalloutMock.class, new TimeoutMock());
        TokenAPINivelloWs.access_token = 'token';

        Test.startTest();
        try {
            OpportunityDiscountRequestController.submitDiscountRequest(
                opp.Id,
                null,
                10,
                'Teste timeout'
            );
            System.assert(false, 'Era esperado erro de timeout.');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage(), 'A falha de timeout deve retornar mensagem para o usuário.');
        }
        Test.stopTest();
    }

    @IsTest
    static void shouldValidateInvalidDiscountAndUrl() {
        Opportunity opp = createOpportunity(TARGET_STAGE, 'VO-VALID', 1000, 'https://example.com/default.pdf');
        OpportunityAttachmentLink__c proposal = createAttachment(
            opp.Id,
            'https://example.com/default.pdf',
            PROPOSAL_ATTACHMENT_TYPE
        );

        try {
            OpportunityDiscountRequestController.submitDiscountRequest(
                opp.Id,
                null,
                null,
                null
            );
            System.assert(false, 'Era esperado erro por ausência de desconto.');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage(), 'Validação de desconto deve retornar mensagem de erro.');
        }

        try {
            OpportunityDiscountRequestController.submitDiscountRequest(
                opp.Id,
                2000,
                null,
                null
            );
            System.assert(false, 'Era esperado erro por desconto acima do valor original.');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage(), 'Validação de teto de desconto deve retornar mensagem de erro.');
        }

        proposal.AttachmentURL__c = 'ftp://example.com/default.pdf';
        update proposal;

        try {
            OpportunityDiscountRequestController.submitDiscountRequest(
                opp.Id,
                100,
                null,
                null
            );
            System.assert(false, 'Era esperado erro de URL inválida.');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage(), 'Validação de URL deve retornar mensagem de erro.');
        }
    }

    @IsTest
    static void shouldFailWhenOpportunityHasNoProposalAttachment() {
        Opportunity opp = createOpportunity(TARGET_STAGE, 'VO-NOPROPOSAL', 1000, 'https://example.com/default.pdf');

        try {
            OpportunityDiscountRequestController.submitDiscountRequest(
                opp.Id,
                100,
                null,
                'Sem proposta'
            );
            System.assert(false, 'Era esperado erro quando não existe proposta gerada.');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage(), 'Deve retornar mensagem quando não há proposta gerada.');
        }
    }

    @IsTest
    static void shouldRequireVirtualOfficeId() {
        try {
            createOpportunity(TARGET_STAGE, '   ', 1000, 'https://example.com/file.pdf');
            System.assert(false, 'Era esperado erro por ausência de IdVirtualOffice__c.');
        } catch (Exception ex) {
            String message = ex.getMessage() != null ? ex.getMessage() : '';
            System.assert(
                message.contains('IdVirtualOffice__c') || message.contains('ID Virtual Office'),
                'Deve falhar quando IdVirtualOffice__c não é informado.'
            );
        }
    }

    @IsTest
    static void shouldExposeStageVisibilityInContext() {
        Opportunity eligibleOpp = createOpportunity(TARGET_STAGE, 'VO-CONTEXT-1', 1000, 'https://example.com/1.pdf');
        Opportunity generatedOpp = createOpportunity(TARGET_STAGE_PROPOSAL_GENERATED, 'VO-CONTEXT-3', 1000, 'https://example.com/3.pdf');
        Opportunity notEligibleOpp = createOpportunity('Negociação', 'VO-CONTEXT-2', 1000, 'https://example.com/2.pdf');

        OpportunityDiscountRequestController.DiscountContext eligibleCtx =
            OpportunityDiscountRequestController.getContext(eligibleOpp.Id);
        OpportunityDiscountRequestController.DiscountContext generatedCtx =
            OpportunityDiscountRequestController.getContext(generatedOpp.Id);
        OpportunityDiscountRequestController.DiscountContext notEligibleCtx =
            OpportunityDiscountRequestController.getContext(notEligibleOpp.Id);

        System.assertEquals(true, eligibleCtx.isEligibleStage, 'Etapa de elaboração deve estar elegível.');
        System.assertEquals(true, generatedCtx.isEligibleStage, 'Etapa de proposta gerada deve estar elegível.');
        System.assertEquals(false, notEligibleCtx.isEligibleStage, 'Outras etapas não devem estar elegíveis.');
        System.assertEquals(false, eligibleCtx.hasLatestProposal, 'Sem anexo de proposta, contexto deve indicar ausência.');
        System.assertEquals(false, generatedCtx.hasLatestProposal, 'Sem anexo de proposta, contexto deve indicar ausência.');
    }

    private static Opportunity createOpportunity(String stageName, String externalId, Decimal originalValue, String url) {
        if (partnerId == null) {
            partnerId = ((Parceiro__c) TestFactory.createSObject(
                new Parceiro__c(
                    Name = 'Parceiro Desconto Teste',
                    Produto__c = 'Solar',
                    GrupoTarifario__c = 'Grupo A'
                ),
                true
            )).Id;
        }

        if (accountId == null) {
            accountId = ((Account) TestFactory.createSObject(new Account(), true)).Id;
        }

        OpportunityTriggerHandler.disableTrigger();
        Opportunity opp;
        try {
            opp = (Opportunity) TestFactory.createSObject(
                new Opportunity(
                    AccountId = accountId,
                    StageName = stageName,
                    Parceiro__c = partnerId,
                    CloseDate = Date.today().addDays(15),
                    IdVirtualOffice__c = externalId,
                    ValorTotalPropostaOriginal__c = originalValue,
                    URL__c = url
                ),
                true
            );
        } finally {
            OpportunityTriggerHandler.enableTrigger();
        }
        return opp;
    }

    private static OpportunityAttachmentLink__c createAttachment(Id opportunityId, String url, String typeValue) {
        OpportunityAttachmentLink__c attachment = new OpportunityAttachmentLink__c(
            OpportunityId__c = opportunityId,
            AttachmentURL__c = url,
            Type__c = typeValue,
            Name = 'Anexo ' + String.valueOf(Crypto.getRandomInteger())
        );
        insert attachment;
        return attachment;
    }
}
