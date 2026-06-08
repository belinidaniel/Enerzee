/**
 * @description       : Testes da distribuição de Leads por estado, rating e elegibilidade do consultor.
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 06-08-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@isTest
private class LeadDistributionSelectorTest {
  private static Integer consultantCounter = 0;

  private static Consultor__c createConsultor(
    String graduation,
    String attendedStates,
    Boolean active,
    Boolean sendLead,
    Boolean frozen,
    String specialRange,
    DateTime lastLeadReceived
  ) {
    consultantCounter++;
    Consultor__c consultor = new Consultor__c(
      Name = 'Consultor Selector ' + consultantCounter,
      Ativo__c = active,
      SendLead__c = sendLead,
      FreezeConsult__c = frozen,
      Lb65_Graduacao__c = graduation,
      EstadosAtendidos__c = attendedStates,
      SpecialRange__c = specialRange,
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

    ConsultorTriggerHandler.disableTrigger();
    try {
      return (Consultor__c) TestFactory.createSObject(consultor, true);
    } finally {
      ConsultorTriggerHandler.enableTrigger();
    }
  }

  private static Lead createLead(String rating, String state) {
    Lead lead = new Lead(
      LastName = 'Lead Selector ' + rating,
      Company = 'Empresa',
      Status = getNonNovoStatus(),
      Rating = rating,
      State = state,
      Phone = '11999999999'
    );
    setIfExists(lead, 'Lb065_LeadVencido__c', false);
    return lead;
  }

  private static LeadDistributionSelector.Response selectConsultant(Lead lead) {
    LeadDistributionSelector.Request request = new LeadDistributionSelector.Request();
    request.leadId = lead.Id;

    List<LeadDistributionSelector.Response> responses = LeadDistributionSelector.selectConsultant(
      new List<LeadDistributionSelector.Request>{ request }
    );

    Assert.areEqual(
      1,
      responses.size(),
      'Deve retornar uma resposta por Lead.'
    );
    return responses[0];
  }

  @isTest
  static void shouldApplyGraduationMatrixByRating() {
    Consultor__c advanced = createConsultor(
      'Advanced Builder',
      'SP',
      true,
      true,
      false,
      null,
      System.now().addDays(-10)
    );
    Consultor__c gold = createConsultor(
      'Gold',
      'RJ',
      true,
      true,
      false,
      null,
      System.now().addDays(-8)
    );
    Consultor__c platinum = createConsultor(
      'Platinum',
      'RJ',
      true,
      true,
      false,
      null,
      System.now().addDays(-6)
    );
    Consultor__c diamond = createConsultor(
      'Diamond',
      'MG',
      true,
      true,
      false,
      null,
      System.now().addDays(-9)
    );
    Consultor__c carbonDiamond = createConsultor(
      'Carbon Diamond',
      'MG',
      true,
      true,
      false,
      null,
      System.now().addDays(-7)
    );

    Lead coldLead = createLead('Cold', 'SP');
    Lead warmLead = createLead('Warm', 'SP');
    Lead firstHotLead = createLead('Hot', 'RJ');
    Lead secondHotLead = createLead('Hot', 'RJ');
    Lead firstPriorityLead = createLead('Prioritário', 'MG');
    Lead secondPriorityLead = createLead('Prioritário', 'MG');
    insert new List<Lead>{
      coldLead,
      warmLead,
      firstHotLead,
      secondHotLead,
      firstPriorityLead,
      secondPriorityLead
    };

    Assert.areEqual(advanced.Id, selectConsultant(coldLead).consultantId);
    Assert.areEqual(advanced.Id, selectConsultant(warmLead).consultantId);
    Assert.areEqual(gold.Id, selectConsultant(firstHotLead).consultantId);
    Assert.areEqual(platinum.Id, selectConsultant(secondHotLead).consultantId);
    Assert.areEqual(
      diamond.Id,
      selectConsultant(firstPriorityLead).consultantId
    );
    Assert.areEqual(
      carbonDiamond.Id,
      selectConsultant(secondPriorityLead).consultantId
    );
  }

  @isTest
  static void shouldFallbackToHigherGraduation() {
    Consultor__c gold = createConsultor(
      'Gold',
      'SP',
      true,
      true,
      false,
      null,
      System.now().addDays(-5)
    );
    Consultor__c diamond = createConsultor(
      'Diamond',
      'RJ',
      true,
      true,
      false,
      null,
      System.now().addDays(-4)
    );

    Lead warmLead = createLead('Warm', 'SP');
    Lead hotLead = createLead('Hot', 'RJ');
    insert new List<Lead>{ warmLead, hotLead };

    Assert.areEqual(
      gold.Id,
      selectConsultant(warmLead).consultantId,
      'Warm deve subir para Gold ou Platinum quando não houver Advanced Builder.'
    );
    Assert.areEqual(
      diamond.Id,
      selectConsultant(hotLead).consultantId,
      'Hot deve subir para Diamond ou Carbon Diamond quando não houver Gold ou Platinum.'
    );
  }

  @isTest
  static void shouldNotFallbackToLowerGraduation() {
    createConsultor(
      'Advanced Builder',
      'SP',
      true,
      true,
      false,
      null,
      System.now().addDays(-5)
    );
    createConsultor(
      'Gold',
      'RJ',
      true,
      true,
      false,
      null,
      System.now().addDays(-4)
    );

    Lead hotLead = createLead('Hot', 'SP');
    Lead priorityLead = createLead('Prioritário', 'RJ');
    insert new List<Lead>{ hotLead, priorityLead };

    Assert.isNull(
      selectConsultant(hotLead).consultantId,
      'Hot não pode descer para Advanced Builder.'
    );
    Assert.isNull(
      selectConsultant(priorityLead).consultantId,
      'Prioritário não pode descer para Gold.'
    );
  }

  @isTest
  static void shouldAllowSpecialRangeAndBlockAdvisorWithoutIt() {
    Consultor__c advisorWithoutSpecialRange = createConsultor(
      'Advisor',
      'RJ',
      true,
      true,
      false,
      null,
      System.now().addDays(-20)
    );
    Consultor__c advisorWithWarmRange = createConsultor(
      'Advisor',
      'RJ',
      true,
      true,
      false,
      'Warm',
      System.now().addDays(-10)
    );
    Consultor__c advancedWithHotRange = createConsultor(
      'Advanced Builder',
      'SP',
      true,
      true,
      false,
      'Hot',
      System.now().addDays(-15)
    );
    Consultor__c gold = createConsultor(
      'Gold',
      'SP',
      true,
      true,
      false,
      null,
      System.now().addDays(-5)
    );

    Lead warmLead = createLead('Warm', 'RJ');
    Lead hotLead = createLead('Hot', 'SP');
    insert new List<Lead>{ warmLead, hotLead };

    Assert.areEqual(
      advisorWithWarmRange.Id,
      selectConsultant(warmLead).consultantId,
      'Advisor só pode receber Lead quando possuir a faixa especial correspondente.'
    );
    LeadDistributionSelector.Response hotResponse = selectConsultant(hotLead);
    Assert.areEqual(
      advancedWithHotRange.Id,
      hotResponse.consultantId,
      'A faixa especial deve tornar o consultor elegível para o rating.'
    );
    Assert.areNotEqual(
      gold.Id,
      hotResponse.consultantId,
      'O consultor elegível há mais tempo deve ser priorizado.'
    );
    Assert.areNotEqual(advisorWithoutSpecialRange.Id, hotResponse.consultantId);
  }

  @isTest
  static void shouldPrioritizeAttendedState() {
    createConsultor(
      'Gold',
      'ES',
      true,
      true,
      false,
      null,
      System.now().addDays(-20)
    );
    Consultor__c spConsultor = createConsultor(
      'Gold',
      'SP;RJ',
      true,
      true,
      false,
      null,
      System.now().addDays(-2)
    );

    Lead lead = createLead('Hot', 'SP');
    insert lead;

    Assert.areEqual(spConsultor.Id, selectConsultant(lead).consultantId);
  }

  @isTest
  static void shouldRequireOperationalEligibility() {
    createConsultor(
      'Gold',
      'SP',
      false,
      true,
      false,
      null,
      System.now().addDays(-20)
    );
    createConsultor(
      'Gold',
      'SP',
      true,
      false,
      false,
      null,
      System.now().addDays(-19)
    );
    createConsultor(
      'Gold',
      'SP',
      true,
      true,
      true,
      null,
      System.now().addDays(-18)
    );
    Consultor__c eligible = createConsultor(
      'Gold',
      'SP',
      true,
      true,
      false,
      null,
      System.now().addDays(-1)
    );

    Lead lead = createLead('Hot', 'SP');
    insert lead;

    Assert.areEqual(eligible.Id, selectConsultant(lead).consultantId);
  }

  @isTest
  static void shouldApplyStateAndRatingToDirectedDistribution() {
    Consultor__c emailConsultor = createConsultor(
      'Advisor',
      'SP',
      true,
      true,
      false,
      'Hot',
      System.now().addDays(-5)
    );
    Consultor__c graduationConsultor = createConsultor(
      'Platinum',
      'RJ',
      true,
      true,
      false,
      null,
      System.now().addDays(-4)
    );

    Lead emailLead = createLead('Hot', 'SP');
    emailLead.Distributiontype__c = 'Email';
    emailLead.DistributionValue__c = emailConsultor.Email__c;

    Lead graduationLead = createLead('Hot', 'RJ');
    graduationLead.Distributiontype__c = 'Graduação';
    graduationLead.DistributionValue__c = ' , Platinum , Gold ';
    insert new List<Lead>{ emailLead, graduationLead };

    Assert.areEqual(
      emailConsultor.Id,
      selectConsultant(emailLead).consultantId
    );
    Assert.areEqual(
      graduationConsultor.Id,
      selectConsultant(graduationLead).consultantId
    );
  }

  @isTest
  static void shouldSelectConsultantWaitingLongest() {
    Consultor__c oldest = createConsultor(
      'Gold',
      'SP',
      true,
      true,
      false,
      null,
      System.now().addDays(-10)
    );
    createConsultor(
      'Gold',
      'SP',
      true,
      true,
      false,
      null,
      System.now().addDays(-1)
    );

    Lead lead = createLead('Hot', 'SP');
    insert lead;

    Assert.areEqual(oldest.Id, selectConsultant(lead).consultantId);

    Consultor__c updated = [
      SELECT Lb065_UltimoLeadRecebido__c
      FROM Consultor__c
      WHERE Id = :oldest.Id
    ];
    Assert.isTrue(
      updated.Lb065_UltimoLeadRecebido__c > System.now().addMinutes(-1),
      'A data do último Lead recebido deve ser atualizada.'
    );
  }

  @isTest
  static void shouldReturnNullWithoutStateOrSupportedRating() {
    Lead noStateLead = createLead('Hot', null);
    Lead noRatingLead = createLead(null, 'SP');
    insert new List<Lead>{ noStateLead, noRatingLead };

    Assert.isNull(selectConsultant(noStateLead).consultantId);
    Assert.isNull(selectConsultant(noRatingLead).consultantId);
  }

  @isTest
  static void shouldHandleEmptyRequestsAndMissingLead() {
    Assert.areEqual(0, LeadDistributionSelector.selectConsultant(null).size());
    Assert.areEqual(
      0,
      LeadDistributionSelector.selectConsultant(
          new List<LeadDistributionSelector.Request>()
        )
        .size()
    );

    LeadDistributionSelector.Request request = new LeadDistributionSelector.Request();
    request.leadId = '00Q000000000001AAA';

    List<LeadDistributionSelector.Response> responses = LeadDistributionSelector.selectConsultant(
      new List<LeadDistributionSelector.Request>{ null, request }
    );

    Assert.areEqual(2, responses.size());
    Assert.areEqual('Lead nao encontrado.', responses[0].message);
    Assert.areEqual('Lead nao encontrado.', responses[1].message);
  }

  private static String getNonNovoStatus() {
    for (
      Schema.PicklistEntry entry : Lead.Status.getDescribe().getPicklistValues()
    ) {
      if (entry.getValue() != 'Novo') {
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
    if (
      record.getSObjectType()
        .getDescribe()
        .fields.getMap()
        .containsKey(fieldName)
    ) {
      record.put(fieldName, value);
    }
  }
}
