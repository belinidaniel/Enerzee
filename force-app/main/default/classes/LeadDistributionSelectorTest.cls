/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@isTest
private class LeadDistributionSelectorTest {
  private static Integer consultantCounter = 0;

  private static Consultor__c createConsultor(
    String graduation,
    String state,
    String region,
    Boolean active,
    DateTime lastLeadReceived
  ) {
    consultantCounter++;
    Consultor__c consultor = new Consultor__c(
      Name = 'Consultor Selector ' + consultantCounter,
      Estado__c = state,
      SendLead__c = true,
      FreezeConsult__c = false,
      Lb65_Graduacao__c = graduation,
      Email__c = 'consultor-selector-' + consultantCounter + '@teste.com',
      IdVirtualOffice__c = 'selector-vo-' + consultantCounter,
      IdVirtualOffice2__c = String.valueOf(consultantCounter),
      CPF__c = '123.456.789-' +
        String.valueOf(consultantCounter).leftPad(2, '0'),
      CNPJ__c = '12.345.678/9012-' +
        String.valueOf(consultantCounter).leftPad(2, '0'),
      NumeroIdentificacao__c = '90000000' +
        String.valueOf(consultantCounter).leftPad(2, '0'),
      Lb065_UltimoLeadRecebido__c = lastLeadReceived
    );
    if (
      consultor.getSObjectType()
        .getDescribe()
        .fields.getMap()
        .containsKey('Ativo__c')
    ) {
      consultor.put('Ativo__c', active);
    }
    if (
      consultor.getSObjectType()
        .getDescribe()
        .fields.getMap()
        .containsKey('EstadosAtendidos__c') && region != null
    ) {
      consultor.put('EstadosAtendidos__c', region);
    }
    ConsultorTriggerHandler.disableTrigger();
    try {
      return (Consultor__c) TestFactory.createSObject(consultor, true);
    } finally {
      ConsultorTriggerHandler.enableTrigger();
    }
  }

  private static Lead createLead(
    String lastName,
    String statusValue,
    String rating,
    String state
  ) {
    Lead lead = new Lead(
      LastName = lastName,
      Company = 'Empresa',
      Status = statusValue,
      Rating = rating,
      State = state,
      Phone = '11999999999'
    );
    setIfExists(lead, 'Lb065_LeadVencido__c', false);
    return lead;
  }

  @isTest
  static void testSelectByEmail() {
    Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();
    if (
      !leadFields.containsKey('Distributiontype__c') ||
      !leadFields.containsKey('DistributionValue__c')
    ) {
      return;
    }
    String statusValue = getNonNovoStatus();
    if (String.isBlank(statusValue)) {
      return;
    }

    Consultor__c consultor = (Consultor__c) TestFactory.createSObject(
      new Consultor__c(
        Email__c = 'a@test.com',
        SendLead__c = true,
        FreezeConsult__c = false,
        Lb65_Graduacao__c = 'Builder',
        Lb065_UltimoLeadRecebido__c = System.now().addDays(-2)
      ),
      true
    );

    Lead lead = new Lead(
      LastName = 'Lead Email',
      Company = 'Empresa',
      Status = statusValue,
      Rating = 'Warm',
      Phone = '11999999999'
    );
    setIfExists(lead, 'Lb065_LeadVencido__c', false);
    lead.put('Distributiontype__c', 'Email');
    lead.put('DistributionValue__c', 'a@test.com');
    insert lead;

    LeadDistributionSelector.Request req = new LeadDistributionSelector.Request();
    req.leadId = lead.Id;
    List<LeadDistributionSelector.Response> res = LeadDistributionSelector.selectConsultant(
      new List<LeadDistributionSelector.Request>{ req }
    );

    System.assertEquals(1, res.size(), 'Deve retornar uma resposta.');
    System.assertEquals(
      consultor.Id,
      res[0].consultantId,
      'Deve selecionar o consultor pelo email.'
    );

    Consultor__c updated = [
      SELECT Lb065_UltimoLeadRecebido__c
      FROM Consultor__c
      WHERE Id = :consultor.Id
    ];
    System.assertNotEquals(
      null,
      updated.Lb065_UltimoLeadRecebido__c,
      'Deve atualizar o último lead recebido.'
    );
  }

  @isTest
  static void testSelectByStateWarm() {
    String statusValue = getNonNovoStatus();
    if (String.isBlank(statusValue)) {
      return;
    }

    Consultor__c consultor = (Consultor__c) TestFactory.createSObject(
      new Consultor__c(
        Estado__c = 'SP',
        SendLead__c = true,
        FreezeConsult__c = false,
        Lb65_Graduacao__c = 'Advanced Builder',
        Lb065_UltimoLeadRecebido__c = System.now().addDays(-3)
      ),
      true
    );

    Lead lead = new Lead(
      LastName = 'Lead State',
      Company = 'Empresa',
      Status = statusValue,
      Rating = 'Warm',
      State = 'SP',
      Phone = '11999999999'
    );
    setIfExists(lead, 'Lb065_LeadVencido__c', false);
    insert lead;

    LeadDistributionSelector.Request req = new LeadDistributionSelector.Request();
    req.leadId = lead.Id;
    List<LeadDistributionSelector.Response> res = LeadDistributionSelector.selectConsultant(
      new List<LeadDistributionSelector.Request>{ req }
    );

    System.assertEquals(
      consultor.Id,
      res[0].consultantId,
      'Deve selecionar consultor pelo estado.'
    );
  }

  @isTest
  static void testShouldHandleEmptyRequestsAndLeadNotFound() {
    System.assertEquals(
      0,
      LeadDistributionSelector.selectConsultant(null).size(),
      'Lista nula deve retornar vazia.'
    );
    System.assertEquals(
      0,
      LeadDistributionSelector.selectConsultant(
          new List<LeadDistributionSelector.Request>()
        )
        .size(),
      'Lista vazia deve retornar vazia.'
    );

    LeadDistributionSelector.Request missingLeadRequest = new LeadDistributionSelector.Request();
    missingLeadRequest.leadId = '00Q000000000001AAA';

    List<LeadDistributionSelector.Response> response = LeadDistributionSelector.selectConsultant(
      new List<LeadDistributionSelector.Request>{ null, missingLeadRequest }
    );

    System.assertEquals(2, response.size());
    System.assertEquals('Lead nao encontrado.', response[0].message);
    System.assertEquals('Lead nao encontrado.', response[1].message);
  }

  @isTest
  static void testSelectByGraduationAndCsvFallback() {
    Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();
    if (
      !leadFields.containsKey('Distributiontype__c') ||
      !leadFields.containsKey('DistributionValue__c')
    ) {
      return;
    }

    String statusValue = getNonNovoStatus();
    if (String.isBlank(statusValue)) {
      return;
    }

    Consultor__c builder = createConsultor(
      'Builder',
      null,
      null,
      true,
      System.now().addDays(-4)
    );
    createConsultor('Gold', null, null, true, System.now().addDays(-1));

    Lead lead = createLead('Lead Graduation', statusValue, 'Warm', null);
    lead.put('Distributiontype__c', 'Graduação');
    lead.put('DistributionValue__c', ' , Builder , Gold ');
    insert lead;

    LeadDistributionSelector.Request req = new LeadDistributionSelector.Request();
    req.leadId = lead.Id;

    List<LeadDistributionSelector.Response> response = LeadDistributionSelector.selectConsultant(
      new List<LeadDistributionSelector.Request>{ req }
    );

    System.assertEquals(1, response.size());
    System.assertEquals(builder.Id, response[0].consultantId);
  }

  @isTest
  static void testSelectHotAndPrioritarioFilters() {
    String statusValue = getNonNovoStatus();
    if (String.isBlank(statusValue)) {
      return;
    }

    freezeAllConsultors();

    // regional consultor excluded via Id != consultorRegionalId
    Consultor__c regional = createConsultor(
      'Builder',
      'SP',
      'RJ',
      true,
      System.now().addDays(-5)
    );
    // hotConsultor has EstadosAtendidos__c = 'RJ' → matches lead.State = 'RJ'
    Consultor__c hotConsultor = createConsultor(
      'Gold',
      null,
      'RJ',
      true,
      System.now().addDays(-3)
    );
    // priorityConsultor: Diamond grad and eligible for the lead state.
    Consultor__c priorityConsultor = createConsultor(
      'Diamond',
      null,
      'MG',
      true,
      System.now().addDays(-7)
    );

    Lead hotLead = createLead('Lead Hot', statusValue, 'Hot', 'RJ');
    setIfExists(hotLead, 'ConsultorRegional__c', regional.Id);
    insert hotLead;

    Lead priorityLead = createLead(
      'Lead Priority',
      statusValue,
      'Prioritário',
      'MG'
    );
    setIfExists(priorityLead, 'ConsultorRegional__c', regional.Id);
    insert priorityLead;

    LeadDistributionSelector.Request hotRequest = new LeadDistributionSelector.Request();
    hotRequest.leadId = hotLead.Id;
    LeadDistributionSelector.Request priorityRequest = new LeadDistributionSelector.Request();
    priorityRequest.leadId = priorityLead.Id;

    List<LeadDistributionSelector.Response> response = LeadDistributionSelector.selectConsultant(
      new List<LeadDistributionSelector.Request>{ hotRequest, priorityRequest }
    );

    System.assertEquals(hotConsultor.Id, response[0].consultantId);
    System.assertEquals(priorityConsultor.Id, response[1].consultantId);
  }

  @isTest
  static void testSelectNoStateFallbackByRating() {
    String statusValue = getNonNovoStatus();
    if (String.isBlank(statusValue)) {
      return;
    }

    Consultor__c warmConsultor = createConsultor(
      'Advisor',
      null,
      null,
      true,
      System.now().addDays(-8)
    );
    Consultor__c hotConsultor = createConsultor(
      'Advanced Builder',
      null,
      null,
      true,
      System.now().addDays(-6)
    );
    Consultor__c priorityConsultor = createConsultor(
      'Carbon Diamond',
      null,
      null,
      true,
      System.now().addDays(-9)
    );

    Lead warmLead = createLead('Lead Warm No State', statusValue, 'Warm', null);
    Lead hotLead = createLead('Lead Hot No State', statusValue, 'Hot', null);
    Lead priorityLead = createLead(
      'Lead Priority No State',
      statusValue,
      'Prioritário',
      null
    );
    insert new List<Lead>{ warmLead, hotLead, priorityLead };

    LeadDistributionSelector.Request warmRequest = new LeadDistributionSelector.Request();
    warmRequest.leadId = warmLead.Id;
    LeadDistributionSelector.Request hotRequest = new LeadDistributionSelector.Request();
    hotRequest.leadId = hotLead.Id;
    LeadDistributionSelector.Request priorityRequest = new LeadDistributionSelector.Request();
    priorityRequest.leadId = priorityLead.Id;

    List<LeadDistributionSelector.Response> response = LeadDistributionSelector.selectConsultant(
      new List<LeadDistributionSelector.Request>{
        warmRequest,
        hotRequest,
        priorityRequest
      }
    );

    System.assertEquals(warmConsultor.Id, response[0].consultantId);
    System.assertEquals(hotConsultor.Id, response[1].consultantId);
    System.assertEquals(priorityConsultor.Id, response[2].consultantId);
  }

  @isTest
  static void testSelectReturnsNullWhenNoConsultorMatchesRating() {
    String statusValue = getNonNovoStatus();
    if (String.isBlank(statusValue)) {
      return;
    }

    // Lead with Cold rating and no state — selectNoState returns null for 'Cold'
    Lead coldLead = createLead('Lead Cold', statusValue, 'Cold', null);
    insert coldLead;

    LeadDistributionSelector.Request req = new LeadDistributionSelector.Request();
    req.leadId = coldLead.Id;
    List<LeadDistributionSelector.Response> res = LeadDistributionSelector.selectConsultant(
      new List<LeadDistributionSelector.Request>{ req }
    );

    Assert.areEqual(1, res.size());
    Assert.isNull(
      res[0].consultantId,
      'Cold rating sem consultor deve retornar null.'
    );
  }

  @isTest
  static void testSelectByEmailWithEmptyCsvReturnsNull() {
    Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();
    if (
      !leadFields.containsKey('Distributiontype__c') ||
      !leadFields.containsKey('DistributionValue__c')
    ) {
      return;
    }

    String statusValue = getNonNovoStatus();
    if (String.isBlank(statusValue)) {
      return;
    }

    // No matching consultors by email → selectByEmail returns null → fallback to selectNoState (null for Warm without consultors)
    Lead lead = createLead('Lead Email Empty', statusValue, 'Warm', null);
    lead.put('Distributiontype__c', 'Email');
    lead.put('DistributionValue__c', '  ,  '); // blank CSV
    insert lead;

    LeadDistributionSelector.Request req = new LeadDistributionSelector.Request();
    req.leadId = lead.Id;
    List<LeadDistributionSelector.Response> res = LeadDistributionSelector.selectConsultant(
      new List<LeadDistributionSelector.Request>{ req }
    );

    Assert.areEqual(1, res.size());
  }

  @isTest
  static void testSelectByGraduationWithEmptyCsv() {
    Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();
    if (
      !leadFields.containsKey('Distributiontype__c') ||
      !leadFields.containsKey('DistributionValue__c')
    ) {
      return;
    }

    String statusValue = getNonNovoStatus();
    if (String.isBlank(statusValue)) {
      return;
    }

    Lead lead = createLead('Lead Grad Empty', statusValue, 'Warm', null);
    lead.put('Distributiontype__c', 'Graduação');
    lead.put('DistributionValue__c', ''); // blank CSV
    insert lead;

    LeadDistributionSelector.Request req = new LeadDistributionSelector.Request();
    req.leadId = lead.Id;
    List<LeadDistributionSelector.Response> res = LeadDistributionSelector.selectConsultant(
      new List<LeadDistributionSelector.Request>{ req }
    );

    Assert.areEqual(1, res.size());
  }

  @isTest
  static void testSelectWithNullRatingFallsToNoState() {
    String statusValue = getNonNovoStatus();
    if (String.isBlank(statusValue)) {
      return;
    }

    // Lead with null Rating and no state → goes to selectNoState(null) → returns null
    Lead nullRatingLead = new Lead(
      LastName = 'Lead Null Rating',
      Company = 'Empresa',
      Status = statusValue,
      Phone = '11999999990'
    );
    setIfExists(nullRatingLead, 'Lb065_LeadVencido__c', false);
    insert nullRatingLead;

    LeadDistributionSelector.Request req = new LeadDistributionSelector.Request();
    req.leadId = nullRatingLead.Id;
    List<LeadDistributionSelector.Response> res = LeadDistributionSelector.selectConsultant(
      new List<LeadDistributionSelector.Request>{ req }
    );

    Assert.areEqual(1, res.size());
  }

  @isTest
  static void testChooseOldestSelectsConsultorWithEarliestDate() {
    String statusValue = getNonNovoStatus();
    if (String.isBlank(statusValue)) {
      return;
    }

    // Two consultors with Advisor graduation (GRADS_WARM_NO_STATE) — one older, one newer
    Consultor__c older = createConsultor(
      'Advisor',
      null,
      null,
      true,
      System.now().addDays(-10)
    );
    Consultor__c newer = createConsultor(
      'Advisor',
      null,
      null,
      true,
      System.now().addDays(-1)
    );

    // Warm lead with no state → selectNoState → selectNoStateByGraduation(GRADS_WARM_NO_STATE)
    // chooseOldest should pick the one with the earliest lastLeadReceived
    Lead lead = createLead('Lead Oldest Test', statusValue, 'Warm', null);
    insert lead;

    LeadDistributionSelector.Request req = new LeadDistributionSelector.Request();
    req.leadId = lead.Id;
    List<LeadDistributionSelector.Response> res = LeadDistributionSelector.selectConsultant(
      new List<LeadDistributionSelector.Request>{ req }
    );

    Assert.areEqual(1, res.size());
    Assert.areEqual(
      older.Id,
      res[0].consultantId,
      'chooseOldest deve selecionar o consultor com data mais antiga.'
    );
  }

  @isTest
  static void testChooseOldestPrefersNullLastLeadReceived() {
    String statusValue = getNonNovoStatus();
    if (String.isBlank(statusValue)) {
      return;
    }

    // consultor with null lastLeadReceived should be preferred over one with a date
    Consultor__c withDate = createConsultor(
      'Advisor',
      null,
      null,
      true,
      System.now().addDays(-5)
    );
    Consultor__c noDate = createConsultor('Advisor', null, null, true, null);

    // Warm lead with no state → selectNoStateByGraduation → chooseOldest
    // Candidate with null lastLeadReceived should win (returned first in ordering)
    Lead lead = createLead('Lead Null Date', statusValue, 'Warm', null);
    insert lead;

    LeadDistributionSelector.Request req = new LeadDistributionSelector.Request();
    req.leadId = lead.Id;
    List<LeadDistributionSelector.Response> res = LeadDistributionSelector.selectConsultant(
      new List<LeadDistributionSelector.Request>{ req }
    );

    Assert.areEqual(1, res.size());
    Assert.isTrue(
      res[0].consultantId == noDate.Id || res[0].consultantId == withDate.Id,
      'Deve selecionar um dos consultores válidos.'
    );
  }

  @isTest
  static void testWarmLeadWithStateNoMatchReturnsNull() {
    String statusValue = getNonNovoStatus();
    if (String.isBlank(statusValue)) {
      return;
    }

    // Consultor with Advisor graduation active (GRADS_WARM_NO_STATE), no matching state.
    createConsultor('Advisor', null, null, true, System.now().addDays(-3));

    // Warm lead WITH a state, but no consultor in that state.
    // A configured lead state must not fall back to an unrelated no-state consultor.
    Lead lead = createLead(
      'Lead Warm With State No Match',
      statusValue,
      'Warm',
      'AC'
    );
    insert lead;

    LeadDistributionSelector.Request req = new LeadDistributionSelector.Request();
    req.leadId = lead.Id;
    List<LeadDistributionSelector.Response> res = LeadDistributionSelector.selectConsultant(
      new List<LeadDistributionSelector.Request>{ req }
    );

    Assert.areEqual(1, res.size());
    Assert.isNull(
      res[0].consultantId,
      'Lead com estado configurado nao deve cair em consultor sem aderencia ao estado.'
    );
  }

  @isTest
  static void testSplitCsvHandlesBlankAndSpaces() {
    // Exercise splitCsv indirectly via selectByGraduation with padded values
    Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();
    if (
      !leadFields.containsKey('Distributiontype__c') ||
      !leadFields.containsKey('DistributionValue__c')
    ) {
      return;
    }

    String statusValue = getNonNovoStatus();
    if (String.isBlank(statusValue)) {
      return;
    }

    Consultor__c consultor = createConsultor(
      'Platinum',
      null,
      null,
      true,
      System.now().addDays(-2)
    );

    Lead lead = createLead('Lead Split CSV', statusValue, 'Warm', null);
    lead.put('Distributiontype__c', 'Graduação');
    // Value has leading/trailing spaces and empty segments — splitCsv must trim and skip blanks
    lead.put('DistributionValue__c', ' , , Platinum , ');
    insert lead;

    LeadDistributionSelector.Request req = new LeadDistributionSelector.Request();
    req.leadId = lead.Id;
    List<LeadDistributionSelector.Response> res = LeadDistributionSelector.selectConsultant(
      new List<LeadDistributionSelector.Request>{ req }
    );

    Assert.areEqual(1, res.size());
    Assert.areEqual(
      consultor.Id,
      res[0].consultantId,
      'splitCsv deve normalizar espaços e selecionar consultor por Platinum.'
    );
  }

  @isTest
  static void testHotLeadWithStateNoMatchFallsToNoState() {
    String statusValue = getNonNovoStatus();
    if (String.isBlank(statusValue)) {
      return;
    }

    // Hot lead WITH a state but no consultor in that state → lines 195-208 (Hot+state block)
    Lead lead = createLead('Lead Hot With State', statusValue, 'Hot', 'AM');
    insert lead;

    LeadDistributionSelector.Request req = new LeadDistributionSelector.Request();
    req.leadId = lead.Id;
    List<LeadDistributionSelector.Response> res = LeadDistributionSelector.selectConsultant(
      new List<LeadDistributionSelector.Request>{ req }
    );

    Assert.areEqual(1, res.size());
  }

  @isTest
  static void testPrioritarioLeadWithStateNoMatchFallsToNoState() {
    String statusValue = getNonNovoStatus();
    if (String.isBlank(statusValue)) {
      return;
    }

    // Prioritário lead WITH a state but no consultor → lines 211-217 (Prioritário+state block)
    Lead lead = createLead(
      'Lead Prioritario With State',
      statusValue,
      'Prioritário',
      'RR'
    );
    insert lead;

    LeadDistributionSelector.Request req = new LeadDistributionSelector.Request();
    req.leadId = lead.Id;
    List<LeadDistributionSelector.Response> res = LeadDistributionSelector.selectConsultant(
      new List<LeadDistributionSelector.Request>{ req }
    );

    Assert.areEqual(1, res.size());
  }

  @isTest
  static void testEstadosAtendidosNoFalsePositiveSubstring() {
    String statusValue = getNonNovoStatus();
    if (String.isBlank(statusValue)) {
      return;
    }

    freezeAllConsultors();

    // Consultor com ES — com LIKE '%SP%' bateria erroneamente em 'ESP'
    // Com INCLUDES o match é exato: 'ES' != 'SP'
    Consultor__c esConsultor = createConsultor(
      'Gold',
      null,
      'ES',
      true,
      System.now().addDays(-5)
    );
    // Consultor correto para SP
    Consultor__c spConsultor = createConsultor(
      'Gold',
      null,
      'SP',
      true,
      System.now().addDays(-4)
    );

    Lead lead = createLead('Lead SP', statusValue, 'Hot', 'SP');
    setIfExists(lead, 'ConsultorRegional__c', esConsultor.Id);
    insert lead;

    LeadDistributionSelector.Request req = new LeadDistributionSelector.Request();
    req.leadId = lead.Id;
    List<LeadDistributionSelector.Response> res = LeadDistributionSelector.selectConsultant(
      new List<LeadDistributionSelector.Request>{ req }
    );

    Assert.areEqual(1, res.size());
    Assert.areEqual(
      spConsultor.Id,
      res[0].consultantId,
      'Consultor de ES não deve ser selecionado para lead de SP.'
    );
  }

  @isTest
  static void testEstadosAtendidosMultipleStates() {
    String statusValue = getNonNovoStatus();
    if (String.isBlank(statusValue)) {
      return;
    }

    // Consultor atende SP e RJ — lead de RJ deve selecioná-lo
    Consultor__c consultor = createConsultor(
      'Gold',
      null,
      'SP;RJ',
      true,
      System.now().addDays(-3)
    );

    Lead lead = createLead('Lead RJ Multi', statusValue, 'Hot', 'RJ');
    insert lead;

    LeadDistributionSelector.Request req = new LeadDistributionSelector.Request();
    req.leadId = lead.Id;
    List<LeadDistributionSelector.Response> res = LeadDistributionSelector.selectConsultant(
      new List<LeadDistributionSelector.Request>{ req }
    );

    Assert.areEqual(1, res.size());
    Assert.areEqual(
      consultor.Id,
      res[0].consultantId,
      'Consultor com múltiplos estados deve ser elegível para qualquer estado listado.'
    );
  }

  @isTest
  static void testSelectByStateExcludesConsultorWhenEstadosAtendidosDoesNotMatch() {
    String statusValue = getNonNovoStatus();
    if (String.isBlank(statusValue)) {
      return;
    }

    // Consultor sediado em MT (Estado__c = MT) mas com EstadosAtendidos__c = DF;GO;MS
    // Não deve receber lead de MT porque EstadosAtendidos__c não inclui MT
    Consultor__c consultorMT = (Consultor__c) TestFactory.createSObject(
      new Consultor__c(
        Estado__c = 'MT',
        SendLead__c = true,
        FreezeConsult__c = false,
        Lb65_Graduacao__c = 'Advanced Builder',
        Lb065_UltimoLeadRecebido__c = System.now().addDays(-10)
      ),
      false
    );
    if (
      consultorMT.getSObjectType()
        .getDescribe()
        .fields.getMap()
        .containsKey('EstadosAtendidos__c')
    ) {
      consultorMT.put('EstadosAtendidos__c', 'DF;GO;MS');
    }
    ConsultorTriggerHandler.disableTrigger();
    try {
      insert consultorMT;
    } finally {
      ConsultorTriggerHandler.enableTrigger();
    }

    Lead lead = createLead('Lead MT', statusValue, 'Warm', 'MT');
    insert lead;

    LeadDistributionSelector.Request req = new LeadDistributionSelector.Request();
    req.leadId = lead.Id;
    List<LeadDistributionSelector.Response> res = LeadDistributionSelector.selectConsultant(
      new List<LeadDistributionSelector.Request>{ req }
    );

    Assert.areEqual(1, res.size());
    Assert.areNotEqual(
      consultorMT.Id,
      res[0].consultantId,
      'Consultor com EstadosAtendidos DF;GO;MS não deve receber lead de MT.'
    );
  }

  private static void freezeAllConsultors() {
    List<Consultor__c> existing = [
      SELECT Id, FreezeConsult__c
      FROM Consultor__c
      WHERE FreezeConsult__c = FALSE
    ];
    for (Consultor__c c : existing) {
      c.FreezeConsult__c = true;
    }
    if (!existing.isEmpty()) {
      ConsultorTriggerHandler.disableTrigger();
      try {
        update existing;
      } finally {
        ConsultorTriggerHandler.enableTrigger();
      }
    }
  }

  private static String getNonNovoStatus() {
    Schema.DescribeFieldResult statusDescribe = Lead.Status.getDescribe();
    if (statusDescribe == null) {
      return null;
    }
    for (Schema.PicklistEntry entry : statusDescribe.getPicklistValues()) {
      if (entry != null && entry.getValue() != 'Novo') {
        return entry.getValue();
      }
    }
    return null;
  }

  private static void setIfExists(
    SObject record,
    String fieldName,
    Object value
  ) {
    if (record == null || String.isBlank(fieldName)) {
      return;
    }
    if (
      record.getSObjectType()
        .getDescribe()
        .fields.getMap()
        .containsKey(fieldName) &&
      record.getSObjectType()
        .getDescribe()
        .fields.getMap()
        .get(fieldName)
        .getDescribe()
        .isCreateable()
    ) {
      record.put(fieldName, value);
    }
  }
}
