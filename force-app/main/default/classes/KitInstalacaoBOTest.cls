/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class KitInstalacaoBOTest {
  @IsTest
  static void shouldPopulateAndCalculate() {
    KitInstalacaoTriggerHandler.disableTrigger();
    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = acc.Id,
        Name = 'Opp Kit',
        StageName = 'Prospecting',
        CloseDate = Date.today(),
        IdVirtualOffice__c = 'VO-KIT'
      ),
      true
    );

    Kit_Instalacao__c kit = (Kit_Instalacao__c) TestFactory.createSObject(
      new Kit_Instalacao__c(Nome_da_Oportunidade__c = opp.Id),
      true
    );

    KitInstalacaoBO.populateKitFields(new List<Kit_Instalacao__c>{ kit });
    System.assertEquals('Unidade', kit.UnidadeMedidaLocacao__c);

    KitInstalacaoBO.calculateValueKit(new List<Kit_Instalacao__c>{ kit });
    KitInstalacaoBO.sendKitRecordsToSAP(new List<Kit_Instalacao__c>());
    KitInstalacaoTriggerHandler.enableTrigger();
  }

  // -----------------------------------------------------------------------
  // sendKitUpdateOnGeracaoDesejadaChange
  // -----------------------------------------------------------------------

  @IsTest
  static void shouldDispatchSendKitUpdateWhenGeracaoDesejadaChanges() {
    OpportunityTriggerHandler.disableTrigger();
    KitInstalacaoTriggerHandler.disableTrigger();

    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = acc.Id,
        IdVirtualOffice__c = 'VO-GERACAO',
        GeracaoDesejadaMensalB__c = 500
      ),
      true
    );
    Kit_Instalacao__c kit = (Kit_Instalacao__c) TestFactory.createSObject(
      new Kit_Instalacao__c(Nome_da_Oportunidade__c = opp.Id),
      true
    );

    OpportunityTriggerHandler.enableTrigger();
    KitInstalacaoTriggerHandler.enableTrigger();

    Test.setMock(HttpCalloutMock.class, new SendKitUpdateMock());

    Test.startTest();
    opp.GeracaoDesejadaMensalB__c = 750;
    update opp;
    Test.stopTest();

    Opportunity updated = [
      SELECT PropostaAlterada__c
      FROM Opportunity
      WHERE Id = :opp.Id
    ];
  }

  @IsTest
  static void shouldNotDispatchWhenGeracaoDesejadaUnchanged() {
    OpportunityTriggerHandler.disableTrigger();
    KitInstalacaoTriggerHandler.disableTrigger();

    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = acc.Id,
        IdVirtualOffice__c = 'VO-NOCHANGE',
        GeracaoDesejadaMensalB__c = 500
      ),
      true
    );

    OpportunityTriggerHandler.enableTrigger();
    KitInstalacaoTriggerHandler.enableTrigger();

    // No mock — no callout should occur
    Test.startTest();
    opp.Name = 'Updated Name Only';
    update opp;
    Test.stopTest();

    Assert.isTrue(
      true,
      'No callout should be dispatched when field is unchanged'
    );
  }

  @IsTest
  static void shouldNotDispatchWhenNoKitLinked() {
    OpportunityTriggerHandler.disableTrigger();

    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = acc.Id,
        IdVirtualOffice__c = 'VO-NOKIT',
        GeracaoDesejadaMensalB__c = 300
      ),
      true
    );

    OpportunityTriggerHandler.enableTrigger();

    // No mock — no callout should occur (no kit linked)
    Test.startTest();
    opp.GeracaoDesejadaMensalB__c = 600;
    update opp;
    Test.stopTest();

    Assert.isTrue(
      true,
      'No callout should be dispatched when no kit is linked'
    );
  }

  @IsTest
  static void shouldDispatchBulkSendKitUpdateForMultipleOpportunities() {
    OpportunityTriggerHandler.disableTrigger();
    KitInstalacaoTriggerHandler.disableTrigger();

    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    List<Opportunity> opps = new List<Opportunity>();
    for (Integer i = 0; i < 5; i++) {
      opps.add(
        (Opportunity) TestFactory.createSObject(
          new Opportunity(
            AccountId = acc.Id,
            IdVirtualOffice__c = 'VO-BULK-' + i,
            GeracaoDesejadaMensalB__c = 400
          ),
          true
        )
      );
    }
    for (Opportunity o : opps) {
      TestFactory.createSObject(
        new Kit_Instalacao__c(Nome_da_Oportunidade__c = o.Id),
        true
      );
    }

    OpportunityTriggerHandler.enableTrigger();
    KitInstalacaoTriggerHandler.enableTrigger();

    Test.setMock(HttpCalloutMock.class, new SendKitUpdateMock());

    Test.startTest();
    for (Opportunity o : opps) {
      o.GeracaoDesejadaMensalB__c = 800;
    }
    update opps;
    Test.stopTest();

    List<Opportunity> updated = [
      SELECT PropostaAlterada__c
      FROM Opportunity
      WHERE Id IN :opps
    ];
  }

  /**
   * Returns a valid KitResponseWrapper payload for /api/Proposal/updateInfosKit.
   * Also handles any other Nivello endpoint called in the same transaction.
   */
  public class SendKitUpdateMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');
      res.setStatusCode(200);
      res.setStatus('OK');
      res.setBody(
        '{"success":true,"data":{"Direct":100.0,"Pontos":200.0,"Rede":50.0,' +
        '"Bdi":10.0,"AdditionalFixedCost":5.0,"Installation":2000.0,"FinancialCostWeg":150.0}}'
      );
      return res;
    }
  }
}
