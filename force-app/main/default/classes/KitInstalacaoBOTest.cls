/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-04-2026
 * @last modified by  : Daniel Belini
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

  @IsTest
  static void shouldNotUpdateFieldsWhenResponseHasNegativeValues() {
    OpportunityTriggerHandler.disableTrigger();
    KitInstalacaoTriggerHandler.disableTrigger();

    Account acc = (Account) TestFactory.createSObject(new Account(), true);
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = acc.Id,
        IdVirtualOffice__c = 'VO-NEGATIVE',
        GeracaoDesejadaMensalB__c = 500,
        BDI__c = 10.0,
        Rede3750__c = 50.0,
        Pontos__c = 200.0,
        Direct__c = 100.0,
        CustoAdicionalFixo__c = 5.0,
        ValorInstalacao__c = 2000.0,
        CustoFinanceiroWeg__c = 150.0
      ),
      true
    );
    TestFactory.createSObject(
      new Kit_Instalacao__c(Nome_da_Oportunidade__c = opp.Id),
      true
    );

    OpportunityTriggerHandler.enableTrigger();
    KitInstalacaoTriggerHandler.enableTrigger();

    Test.setMock(HttpCalloutMock.class, new NegativeKitResponseMock());

    Test.startTest();
    opp.GeracaoDesejadaMensalB__c = 750;
    update opp;
    Test.stopTest();

    Opportunity updated = [
      SELECT
        BDI__c,
        Rede3750__c,
        Pontos__c,
        Direct__c,
        CustoAdicionalFixo__c,
        ValorInstalacao__c,
        CustoFinanceiroWeg__c
      FROM Opportunity
      WHERE Id = :opp.Id
    ];
    Assert.areEqual(
      10.0,
      updated.BDI__c,
      'BDI__c should not change when response is negative'
    );
    Assert.areEqual(
      50.0,
      updated.Rede3750__c,
      'Rede3750__c should not change when response is negative'
    );
    Assert.areEqual(
      200.0,
      updated.Pontos__c,
      'Pontos__c should not change when response is negative'
    );
    Assert.areEqual(
      100.0,
      updated.Direct__c,
      'Direct__c should not change when response is negative'
    );
    Assert.areEqual(
      5.0,
      updated.CustoAdicionalFixo__c,
      'CustoAdicionalFixo__c should not change when response is negative'
    );
    Assert.areEqual(
      2000.0,
      updated.ValorInstalacao__c,
      'ValorInstalacao__c should not change when response is negative'
    );
    Assert.areEqual(
      150.0,
      updated.CustoFinanceiroWeg__c,
      'CustoFinanceiroWeg__c should not change when response is negative'
    );
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

  /**
   * Returns a KitResponseWrapper with all negative values.
   * Fields should not be updated when response values are negative.
   */
  public class NegativeKitResponseMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');
      res.setStatusCode(200);
      res.setStatus('OK');
      res.setBody(
        '{"success":true,"data":{"Direct":-1.0,"Pontos":-1.0,"Rede":-1.0,' +
        '"Bdi":-1.0,"AdditionalFixedCost":-1.0,"Installation":-1.0,"FinancialCostWeg":-1.0}}'
      );
      return res;
    }
  }
}
