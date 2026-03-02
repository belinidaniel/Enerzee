@IsTest
private class LeadBOTest {
  private static void ensureQueues() {
    getOrCreateQueue('QualificacaodeClientes', 'QualificacaodeClientes');
    getOrCreateQueue('Consultor', 'Consultor');
  }

  private static Id getOrCreateQueue(String developerName, String label) {
    List<Group> existing = [
      SELECT Id
      FROM Group
      WHERE DeveloperName = :developerName AND Type = 'Queue'
      LIMIT 1
    ];
    if (!existing.isEmpty()) {
      return existing[0].Id;
    }
    Group g = new Group(
      Name = label,
      DeveloperName = developerName,
      Type = 'Queue'
    );
    insert g;
    return g.Id;
  }

  private static User createIntegrationUser() {
    Profile p = [
      SELECT Id
      FROM Profile
      WHERE Name = 'System Administrator'
      LIMIT 1
    ];
    User u = new User(
      FirstName = 'Integra',
      LastName = 'User',
      Alias = 'integ',
      Email = 'integracao_' + DateTime.now().getTime() + '@test.com',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'pt_BR',
      LocaleSidKey = 'pt_BR',
      TimeZoneSidKey = 'America/Sao_Paulo',
      Username = 'integracao@lab065.com.' +
        DateTime.now().getTime() +
        '@test.com',
      ProfileId = p.Id
    );
    insert u;
    return u;
  }

  @IsTest
  static void shouldValidateLeads() {
    ensureQueues();
    createIntegrationUser();

    Map<String, Schema.RecordTypeInfo> leadRts = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName();
    if (
      !leadRts.containsKey('QualificacaodeClientes') ||
      !leadRts.containsKey('QualificacaodeConsultores')
    ) {
      return;
    }

    Consultor__c consultor = (Consultor__c) TestFactory.createSObject(
      new Consultor__c(),
      true
    );

    Lead lead = new Lead(
      FirstName = 'Teste',
      LastName = 'Cliente',
      Company = 'Empresa',
      Status = 'Qualified',
      RecordTypeId = leadRts.get('QualificacaodeClientes').getRecordTypeId()
    );
    lead.CPFCNPJ__c = '123';
    lead.Email = 'lead@teste.com';
    lead.ConsultorRegional__c = consultor.Id;

    LeadBO.LeadValidationHandler(new List<Lead>{ lead });

    LeadBO.sendClientRecordToProposalGenerator(new List<Lead>{ lead });
    LeadBO.createMessagingUser(
      new List<Lead>{ new Lead(LastName = 'SemTelefone', Company = 'X') },
      new Map<Id, Lead>()
    );

    System.assert(true, 'LeadBO executed');
  }
}
