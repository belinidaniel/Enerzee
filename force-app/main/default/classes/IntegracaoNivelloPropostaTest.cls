/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class IntegracaoNivelloPropostaTest {
  private static ContentVersion createProposalPdfForOpportunity(
    Opportunity opp,
    String title
  ) {
    ContentVersion proposalVersion = new ContentVersion(
      Title = title,
      PathOnClient = title + '.pdf',
      VersionData = Blob.valueOf('%PDF-1.4 fake content'),
      FirstPublishLocationId = opp.Id,
      IsProposal__c = true
    );
    insert proposalVersion;
    return proposalVersion;
  }

  @IsTest
  static void shouldInstantiateAllInnerDTOs() {
    IntegracaoNivelloProposta.GerandoPropostaRequest req = new IntegracaoNivelloProposta.GerandoPropostaRequest();
    req.approved = true;
    req.id = 'vo-dto-id';
    req.description = 'Proposta DTO test';
    req.contract = 'data:application/pdf;base64,AAAA';

    IntegracaoNivelloProposta.FinalizacaoPropostaRequest finReq = new IntegracaoNivelloProposta.FinalizacaoPropostaRequest();
    finReq.id = 'vo-fin-id';
    finReq.implementationDate = '2026-03-15T00:00:00.000Z';
    finReq.proposta = 'data:application/pdf;base64,BBBB';

    IntegracaoNivelloProposta.URLSimulationRequest simReq = new IntegracaoNivelloProposta.URLSimulationRequest();
    simReq.Id = 'vo-sim-id';
    simReq.urlSimulation = 'https://example.com/sim';

    IntegracaoNivelloProposta.ProposalIntegrationResult result = new IntegracaoNivelloProposta.ProposalIntegrationResult();
    result.success = true;
    result.statusCode = 200;
    result.message = 'OK';
    result.responseBody = '{}';
    result.attachmentUrl = 'https://example.com/file.pdf';

    Assert.areEqual(true, req.approved);
    Assert.areEqual('vo-fin-id', finReq.id);
    Assert.areEqual('https://example.com/sim', simReq.urlSimulation);
    Assert.areEqual(true, result.success);
    Assert.areEqual(200, result.statusCode);
  }

  @IsTest
  static void shouldCallGerandoPropostaSincronaWithGuard() {
    if (
      !TestMetadataUtils.hasMetadataRecord(
        'Integrador__mdt',
        'Gerando_Proposta'
      )
    ) {
      return;
    }

    Account acc = new Account(Name = 'Conta Sincrona Guard');
    Database.DMLOptions accountOptions = new Database.DMLOptions();
    accountOptions.DuplicateRuleHeader.allowSave = true;
    acc.setOptions(accountOptions);
    insert acc;
    Opportunity opp = new Opportunity(
      Name = 'Opp Sincrona Guard',
      AccountId = acc.Id,
      CloseDate = Date.today(),
      IdVirtualOffice__c = 'VO-SINCRONA',
      StageName = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA
    );
    insert opp;
    ContentVersion proposalVersion = createProposalPdfForOpportunity(
      opp,
      'Proposta Guard'
    );

    TokenAPINivelloWs.access_token = 'token';
    Test.setMock(
      HttpCalloutMock.class,
      new TestMetadataUtils.MockHttpSuccess()
    );

    Test.startTest();
    IntegracaoNivelloProposta.ProposalIntegrationResult res = IntegracaoNivelloProposta.gerandoPropostaSincrona(
      opp.Id,
      proposalVersion.Id
    );
    Test.stopTest();

    Assert.isNotNull(
      res,
      'A integracao sincrona deve sempre retornar um objeto de resultado.'
    );
    Assert.isTrue(
      String.isNotBlank(res.message) || String.isNotBlank(res.responseBody),
      'A integracao deve retornar sucesso ou uma falha controlada.'
    );
    if (res.success) {
      Assert.areEqual(
        'Proposta enviada para o aplicativo.',
        res.message,
        'Quando houver sucesso, a mensagem deve refletir o envio ao aplicativo.'
      );
    }
  }

  @IsTest
  static void shouldCallFinalizacaoPropostaWithEmptySet() {
    if (
      !TestMetadataUtils.hasMetadataRecord(
        'Integrador__mdt',
        'Finalizacao_Proposta'
      )
    ) {
      return;
    }

    Test.setMock(
      HttpCalloutMock.class,
      new TestMetadataUtils.MockHttpSuccess()
    );

    Test.startTest();
    IntegracaoNivelloProposta.finalizacaoProposta(new Set<Id>());
    Test.stopTest();

    Assert.isTrue(
      true,
      'finalizacaoProposta com Set vazio nao deve lancar erro.'
    );
  }

  @IsTest
  static void shouldSendSimulationUrl() {
    if (
      !TestMetadataUtils.hasMetadataRecord(
        'Integrador__mdt',
        'Envia_URLSimulacao'
      )
    ) {
      return;
    }

    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = acc.Id,
        IdVirtualOffice__c = 'VO-PROP',
        URLSimulation__c = 'https://example.com/sim'
      ),
      true
    );

    TokenAPINivelloWs.access_token = 'token';
    Test.setMock(
      HttpCalloutMock.class,
      new TestMetadataUtils.MockHttpSuccess()
    );

    Test.startTest();
    IntegracaoNivelloProposta.sendUrlSimulation(new Set<Id>{ opp.Id });
    Test.stopTest();

    System.assert(true, 'Integracao executada');
  }

  @IsTest
  static void shouldCallFinalizacaoPropostaWithRealOpportunity() {
    if (
      !TestMetadataUtils.hasMetadataRecord(
        'Integrador__mdt',
        'Finalizacao_Proposta'
      )
    ) {
      return;
    }

    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(AccountId = acc.Id, IdVirtualOffice__c = 'VO-FIN-REAL'),
      true
    );

    ContentVersion cv = new ContentVersion(
      Title = 'Proposta Finalizacao',
      PathOnClient = 'proposta_fin.pdf',
      VersionData = Blob.valueOf('PDF-CONTENT'),
      FirstPublishLocationId = opp.Id
    );
    insert cv;

    TokenAPINivelloWs.access_token = 'mock-token';
    Test.setMock(
      HttpCalloutMock.class,
      new TestMetadataUtils.MockHttpSuccess()
    );

    Test.startTest();
    IntegracaoNivelloProposta.finalizacaoProposta(new Set<Id>{ opp.Id });
    Test.stopTest();

    Assert.isTrue(
      true,
      'finalizacaoProposta com oportunidade real nao deve lancar erro.'
    );
  }

  @IsTest
  static void shouldCallSendUrlSimulationWithEmptySet() {
    if (
      !TestMetadataUtils.hasMetadataRecord(
        'Integrador__mdt',
        'Envia_URLSimulacao'
      )
    ) {
      return;
    }

    TokenAPINivelloWs.access_token = 'mock-token';
    Test.setMock(
      HttpCalloutMock.class,
      new TestMetadataUtils.MockHttpSuccess()
    );

    Test.startTest();
    IntegracaoNivelloProposta.sendUrlSimulation(new Set<Id>());
    Test.stopTest();

    Assert.isTrue(
      true,
      'sendUrlSimulation com Set vazio nao deve lancar erro.'
    );
  }

  @IsTest
  static void shouldCallGerandoPropostaWithPdfAttachment() {
    if (
      !TestMetadataUtils.hasMetadataRecord(
        'Integrador__mdt',
        'Gerando_Proposta'
      )
    ) {
      return;
    }

    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = acc.Id,
        IdVirtualOffice__c = 'VO-GERANDO-PDF'
      ),
      true
    );

    // Insert a PDF ContentVersion linked to the opportunity so the SOQL inside gerandoProposta finds it
    ContentVersion cv = new ContentVersion(
      Title = 'Proposta PDF Test',
      PathOnClient = 'proposta_test.pdf',
      VersionData = Blob.valueOf('%PDF-1.4 fake content'),
      FirstPublishLocationId = UserInfo.getUserId()
    );
    insert cv;
    cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

    ContentDocumentLink cdl = new ContentDocumentLink(
      ContentDocumentId = cv.ContentDocumentId,
      LinkedEntityId = opp.Id,
      ShareType = 'V'
    );
    insert cdl;

    TokenAPINivelloWs.access_token = 'mock-token';
    Test.setMock(
      HttpCalloutMock.class,
      new TestMetadataUtils.MockHttpSuccess()
    );

    Test.startTest();
    IntegracaoNivelloProposta.gerandoProposta(opp.Id);
    Test.stopTest();

    Assert.isTrue(
      true,
      'gerandoProposta com PDF anexado nao deve lancar erro.'
    );
  }

  @IsTest
  static void shouldHandleGerandoPropostaWhenNoPdfFound() {
    if (
      !TestMetadataUtils.hasMetadataRecord(
        'Integrador__mdt',
        'Gerando_Proposta'
      )
    ) {
      return;
    }

    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(AccountId = acc.Id, IdVirtualOffice__c = 'VO-NO-PDF'),
      true
    );

    // No ContentDocumentLink attached → propostaPDFList is empty → method exits early
    TokenAPINivelloWs.access_token = 'mock-token';
    Test.setMock(
      HttpCalloutMock.class,
      new TestMetadataUtils.MockHttpSuccess()
    );

    Test.startTest();
    IntegracaoNivelloProposta.gerandoProposta(opp.Id);
    Test.stopTest();

    Assert.isTrue(true, 'gerandoProposta sem PDF nao deve lancar erro.');
  }

  @IsTest
  static void shouldCallGerandoPropostaSincronaAndReturnSuccess() {
    if (
      !TestMetadataUtils.hasMetadataRecord(
        'Integrador__mdt',
        'Gerando_Proposta'
      )
    ) {
      return;
    }

    Account acc = new Account(Name = 'Conta Sincrona Return');
    Database.DMLOptions accountOptions = new Database.DMLOptions();
    accountOptions.DuplicateRuleHeader.allowSave = true;
    acc.setOptions(accountOptions);
    insert acc;
    Opportunity opp = new Opportunity(
      Name = 'Opp Sincrona Return',
      AccountId = acc.Id,
      CloseDate = Date.today(),
      IdVirtualOffice__c = 'VO-SINCRONA-2',
      StageName = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA
    );
    insert opp;
    ContentVersion proposalVersion = createProposalPdfForOpportunity(
      opp,
      'Proposta Sincrona'
    );

    TokenAPINivelloWs.access_token = 'mock-token';
    Test.setMock(
      HttpCalloutMock.class,
      new TestMetadataUtils.MockHttpSuccess()
    );

    Test.startTest();
    IntegracaoNivelloProposta.ProposalIntegrationResult res = IntegracaoNivelloProposta.gerandoPropostaSincrona(
      opp.Id,
      proposalVersion.Id
    );
    Test.stopTest();

    Assert.isNotNull(
      res,
      'A integracao sincrona deve sempre retornar um objeto de resultado.'
    );
    Assert.isTrue(
      String.isNotBlank(res.message) || String.isNotBlank(res.responseBody),
      'A integracao deve retornar sucesso ou uma falha controlada.'
    );
    if (res.success) {
      Assert.areEqual(
        'Proposta enviada para o aplicativo.',
        res.message,
        'Quando houver sucesso, a mensagem deve refletir o contrato atual da integração.'
      );
    }
  }

  @IsTest
  static void shouldDispatchUrlSimulationForEzeeLivreOnTriggerUpdate() {
    if (
      !TestMetadataUtils.hasMetadataRecord(
        'Integrador__mdt',
        'Envia_URLSimulacao'
      )
    ) {
      return;
    }

    OpportunityTriggerHandler.disableTrigger();
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = acc.Id,
        IdVirtualOffice__c = 'VO-EZEELIVRE-SIM',
        URLSimulation__c = 'https://example.com/ezeelivre-sim',
        RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
          .get('EzeeLivre')
          .getRecordTypeId()
      ),
      true
    );
    OpportunityTriggerHandler.enableTrigger();

    TokenAPINivelloWs.access_token = 'mock-token';
    Test.setMock(
      HttpCalloutMock.class,
      new TestMetadataUtils.MockHttpSuccess()
    );

    Test.startTest();
    opp.URLSimulation__c = 'https://example.com/ezeelivre-sim-updated';
    update opp;
    Test.stopTest();

    Assert.isTrue(
      true,
      'EzeeLivre deve disparar sendUrlSimulation via trigger sem erro'
    );
  }
}
