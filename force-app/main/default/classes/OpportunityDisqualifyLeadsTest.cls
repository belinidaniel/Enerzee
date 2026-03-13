/**
 * @description Test class for OpportunityBO.disqualifyLinkedLeads
 *              Covers all acceptance criteria scenarios defined in the requirement.
 * @author      Daniel Belini
 * @last modified on  : 03-13-2026
 * @last modified by  : Daniel Belini
 **/
@IsTest
private class OpportunityDisqualifyLeadsTest {

  // ─── Test Data Factory ─────────────────────────────────────────────────────

  private static Account createAccount() {
    Account acc = new Account(Name = 'Test Account');
    insert acc;
    return acc;
  }

  private static Lead createLead(String status) {
    Lead l = new Lead(
      FirstName = 'Test',
      LastName = 'Lead',
      Company = 'Test Company',
      Status = status
    );
    insert l;
    return l;
  }

  private static Opportunity createOpportunity(Account acc, String stage, Id leadId) {
    Opportunity opp = new Opportunity(
      Name = 'Test Opp',
      AccountId = acc.Id,
      StageName = stage,
      CloseDate = Date.today().addDays(30),
      Lead__c = leadId != null ? String.valueOf(leadId) : null
    );
    insert opp;
    return opp;
  }

  // ─── Cenário 1: Happy Path ──────────────────────────────────────────────────

  @IsTest
  static void givenOppWithLead_whenMovedToFechadoPerdido_thenLeadIsDisqualified() {
    Account acc = createAccount();
    Lead lead = createLead('Open - Not Contacted');

    Opportunity oldOpp = createOpportunity(acc, OpportunityUtils.STATUS_PROPOSTA_ENVIADA, lead.Id);
    Opportunity newOpp = oldOpp.clone(false, true, true, true);
    newOpp.StageName = OpportunityUtils.STATUS_FECHADO_PERDIDO;

    Test.startTest();
    OpportunityBO.disqualifyLinkedLeads(
      new List<Opportunity>{ newOpp },
      new Map<Id, Opportunity>{ oldOpp.Id => oldOpp }
    );
    Test.stopTest();

    Lead updated = [SELECT Status FROM Lead WHERE Id = :lead.Id];
    Assert.areEqual(
      OpportunityUtils.LEAD_STATUS_NAO_QUALIFICADO,
      updated.Status,
      'Lead deve ser desqualificado quando Opportunity é fechada como perdida'
    );
  }

  // ─── Cenário 2: Opportunity sem Lead ────────────────────────────────────────

  @IsTest
  static void givenOppWithoutLead_whenMovedToFechadoPerdido_thenNoLeadIsUpdated() {
    Account acc = createAccount();

    Opportunity oldOpp = createOpportunity(acc, OpportunityUtils.STATUS_PROPOSTA_ENVIADA, null);
    Opportunity newOpp = oldOpp.clone(false, true, true, true);
    newOpp.StageName = OpportunityUtils.STATUS_FECHADO_PERDIDO;

    Integer leadCountBefore = [SELECT COUNT() FROM Lead];

    Test.startTest();
    OpportunityBO.disqualifyLinkedLeads(
      new List<Opportunity>{ newOpp },
      new Map<Id, Opportunity>{ oldOpp.Id => oldOpp }
    );
    Test.stopTest();

    Integer leadCountAfter = [SELECT COUNT() FROM Lead];
    Assert.areEqual(leadCountBefore, leadCountAfter, 'Nenhum Lead deve ser alterado');
  }

  // ─── Cenário 3: Bulk (200 registros) ────────────────────────────────────────

  @IsTest
  static void givenBulk200OppsWithLeads_whenAllMovedToFechadoPerdido_thenAllLeadsDisqualified() {
    Account acc = createAccount();

    List<Lead> leads = new List<Lead>();
    for (Integer i = 0; i < 200; i++) {
      leads.add(new Lead(
        FirstName = 'Test',
        LastName = 'Lead ' + i,
        Company = 'Company ' + i,
        Status = 'Open - Not Contacted'
      ));
    }
    insert leads;

    List<Opportunity> oldOpps = new List<Opportunity>();
    for (Integer i = 0; i < 200; i++) {
      oldOpps.add(new Opportunity(
        Name = 'Bulk Opp ' + i,
        AccountId = acc.Id,
        StageName = OpportunityUtils.STATUS_PROPOSTA_ENVIADA,
        CloseDate = Date.today().addDays(30),
        Lead__c = String.valueOf(leads[i].Id)
      ));
    }
    insert oldOpps;

    List<Opportunity> newOpps = new List<Opportunity>();
    Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>();
    for (Opportunity old : oldOpps) {
      Opportunity nw = old.clone(false, true, true, true);
      nw.StageName = OpportunityUtils.STATUS_FECHADO_PERDIDO;
      newOpps.add(nw);
      oldMap.put(old.Id, old);
    }

    Test.startTest();
    OpportunityBO.disqualifyLinkedLeads(newOpps, oldMap);
    Test.stopTest();

    Integer disqualifiedCount = [
      SELECT COUNT()
      FROM Lead
      WHERE Status = :OpportunityUtils.LEAD_STATUS_NAO_QUALIFICADO
        AND Id IN :new Map<Id, Lead>(leads).keySet()
    ];
    Assert.areEqual(200, disqualifiedCount, 'Todos os 200 Leads devem ser desqualificados');
  }

  // ─── Cenário 4: Stage já era Fechado Perdido (sem transição) ────────────────

  @IsTest
  static void givenOppAlreadyFechadoPerdido_whenSavedAgain_thenLeadIsNotUpdated() {
    Account acc = createAccount();
    Lead lead = createLead('Open - Not Contacted');

    // Opp já está em Fechado Perdido desde o insert
    Opportunity oldOpp = createOpportunity(acc, OpportunityUtils.STATUS_FECHADO_PERDIDO, lead.Id);
    Opportunity newOpp = oldOpp.clone(false, true, true, true);
    newOpp.StageName = OpportunityUtils.STATUS_FECHADO_PERDIDO;

    Test.startTest();
    OpportunityBO.disqualifyLinkedLeads(
      new List<Opportunity>{ newOpp },
      new Map<Id, Opportunity>{ oldOpp.Id => oldOpp }
    );
    Test.stopTest();

    Lead afterCall = [SELECT Status FROM Lead WHERE Id = :lead.Id];
    Assert.areEqual(
      'Open - Not Contacted',
      afterCall.Status,
      'Lead não deve ser alterado se stage não mudou'
    );
  }

  // ─── Cenário 5: Lead já desqualificado ──────────────────────────────────────

  @IsTest
  static void givenLeadAlreadyDisqualified_whenOppClosedLost_thenNoDmlIsExecuted() {
    Account acc = createAccount();
    Lead lead = createLead(OpportunityUtils.LEAD_STATUS_NAO_QUALIFICADO);

    Opportunity oldOpp = createOpportunity(acc, OpportunityUtils.STATUS_PROPOSTA_ENVIADA, lead.Id);
    Opportunity newOpp = oldOpp.clone(false, true, true, true);
    newOpp.StageName = OpportunityUtils.STATUS_FECHADO_PERDIDO;

    Test.startTest();
    // Se executar DML desnecessário, o DML limit seria consumido; o método deve pular
    OpportunityBO.disqualifyLinkedLeads(
      new List<Opportunity>{ newOpp },
      new Map<Id, Opportunity>{ oldOpp.Id => oldOpp }
    );
    Test.stopTest();

    // Verify DML count = 0 via Limits (no update should fire)
    Assert.areEqual(
      0,
      Limits.getDmlStatements(),
      'Nenhum DML deve ser executado se o Lead já está desqualificado'
    );
  }

  // ─── Edge: null inputs ───────────────────────────────────────────────────────

  @IsTest
  static void givenNullInputs_whenCalled_thenNoException() {
    Test.startTest();
    Boolean exceptionThrown = false;
    try {
      OpportunityBO.disqualifyLinkedLeads(null, null);
      OpportunityBO.disqualifyLinkedLeads(new List<Opportunity>(), new Map<Id, Opportunity>());
    } catch (Exception e) {
      exceptionThrown = true;
    }
    Test.stopTest();

    Assert.isFalse(exceptionThrown, 'Nenhuma exceção deve ser lançada para inputs nulos/vazios');
  }
}
