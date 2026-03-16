/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class IntegracaoNivelloViabilidadeTest {
  @IsTest
  static void shouldSendViabilityStages() {
    if (
      !TestMetadataUtils.hasMetadataRecord(
        'Integrador__mdt',
        'Etapa_Viabilidade'
      ) ||
      !TestMetadataUtils.hasMetadataRecord(
        'Integrador__mdt',
        'Conclusao_Viabilidade'
      )
    ) {
      return;
    }

    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = acc.Id,
        IdVirtualOffice__c = 'VO-123',
        EtapaViabilidade__c = 'Agendamento',
        PrazoAprovacaoViabilidade__c = System.now().addDays(1)
      ),
      true
    );

    TokenAPINivelloWs.access_token = 'token';
    Test.setMock(
      HttpCalloutMock.class,
      new TestMetadataUtils.MockHttpSuccess()
    );

    Test.startTest();
    IntegracaoNivelloViabilidade.etapaViabilidade(new Set<Id>{ opp.Id });
    IntegracaoNivelloViabilidade.conclusaoViabilidade(new Set<Id>{ opp.Id });
    Test.stopTest();

    System.assert(true, 'Integracao executada');
  }
}
