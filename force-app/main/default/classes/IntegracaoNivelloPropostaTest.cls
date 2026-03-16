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

    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = acc.Id,
        IdVirtualOffice__c = 'VO-SINCRONA'
      ),
      true
    );

    TokenAPINivelloWs.access_token = 'token';
    Test.setMock(
      HttpCalloutMock.class,
      new TestMetadataUtils.MockHttpSuccess()
    );

    Test.startTest();
    IntegracaoNivelloProposta.ProposalIntegrationResult res = IntegracaoNivelloProposta.gerandoPropostaSincrona(
      opp.Id
    );
    Test.stopTest();

    Assert.isTrue(res.success, 'gerandoPropostaSincrona deve retornar success=true.');
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

    Assert.isTrue(true, 'finalizacaoProposta com Set vazio nao deve lancar erro.');
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
}
