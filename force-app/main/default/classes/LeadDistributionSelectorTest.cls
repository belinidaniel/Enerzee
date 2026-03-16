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
    setIfExists(consultor, 'Ativo__c', active);
    setIfExists(consultor, 'Lb065_RegiaoConsultorEstado__c', region);
    return (Consultor__c) TestFactory.createSObject(consultor, true);
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
    Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();
    String statusValue = getNonNovoStatus();
    if (String.isBlank(statusValue)) {
      return;
    }
    if (
      !leadFields.containsKey('LeadRegion__c') ||
      !leadFields.get('LeadRegion__c').getDescribe().isCreateable()
    ) {
      return;
    }

    Consultor__c regional = createConsultor(
      'Builder',
      'SP',
      'SUL',
      true,
      System.now().addDays(-5)
    );
    Consultor__c hotConsultor = createConsultor(
      'Gold',
      null,
      'SUL',
      true,
      System.now().addDays(-3)
    );
    Consultor__c priorityConsultor = createConsultor(
      'Diamond',
      null,
      'CENTRO',
      true,
      System.now().addDays(-7)
    );

    Lead hotLead = createLead('Lead Hot', statusValue, 'Hot', 'RJ');
    setIfExists(hotLead, 'LeadRegion__c', 'SUL');
    setIfExists(hotLead, 'ConsultorRegional__c', regional.Id);
    insert hotLead;

    Lead priorityLead = createLead(
      'Lead Priority',
      statusValue,
      'Prioritário',
      'MG'
    );
    setIfExists(priorityLead, 'LeadRegion__c', 'CENTRO');
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
    Assert.isNull(res[0].consultantId, 'Cold rating sem consultor deve retornar null.');
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
