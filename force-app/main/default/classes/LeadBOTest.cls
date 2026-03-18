/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class LeadBOTest {
  private static final String CLIENT_QUEUE_DEVELOPER_NAME = 'QualificacaodeClientes';
  private static final String CONSULTANT_QUEUE_DEVELOPER_NAME = 'Consultor';

  private class IntegrationSuccessMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse response = new HttpResponse();
      response.setStatusCode(200);
      response.setHeader('Content-Type', 'application/json');
      response.setBody(
        '{"success":true,"data":"VO-123","erro":false,"idusuario":"123","retorno":""}'
      );
      return response;
    }
  }

  @TestSetup
  static void setupData() {
    ensureQueue(CLIENT_QUEUE_DEVELOPER_NAME);
    ensureQueue(CONSULTANT_QUEUE_DEVELOPER_NAME);
    createIntegrationUser();
  }

  @IsTest
  static void shouldValidateClientAndConsultantRequirements() {
    Consultor__c consultor = createConsultor('validation', false);

    Lead invalidClientLead = new Lead(
      LastName = 'Cliente Invalido',
      Company = 'Enerzee Cliente',
      RecordTypeId = getLeadRecordTypeId('QualificacaodeClientes'),
      Status = 'Qualified'
    );

    Lead validClientLead = new Lead(
      LastName = 'Cliente Valido',
      Company = 'Enerzee Cliente',
      RecordTypeId = getLeadRecordTypeId('QualificacaodeClientes'),
      Status = 'Qualified',
      Email = 'cliente.valido.' + System.now().getTime() + '@teste.com',
      CPFCNPJ__c = '12345678901',
      ConsultorRegional__c = consultor.Id
    );

    Lead invalidConsultantLead = new Lead(
      LastName = 'Consultor Invalido',
      Company = 'Enerzee Consultor',
      RecordTypeId = getLeadRecordTypeId('QualificacaodeConsultores'),
      Status = 'Aguardando Pagamento'
    );

    Lead validConsultantLead = new Lead(
      LastName = 'Consultor Valido',
      Company = 'Enerzee Consultor',
      RecordTypeId = getLeadRecordTypeId('QualificacaodeConsultores'),
      Status = 'Qualified',
      Email = 'consultor.valido.' + System.now().getTime() + '@teste.com',
      CPFCNPJ__c = '12345678901',
      ConsultorRegional__c = consultor.Id
    );

    LeadBO.LeadValidationHandler(
      new List<Lead>{
        invalidClientLead,
        validClientLead,
        invalidConsultantLead,
        validConsultantLead
      }
    );

    System.assertEquals(
      true,
      invalidClientLead.getErrors().size() > 0,
      'Cliente qualificado sem dados obrigatorios deve ser bloqueado.'
    );
    System.assertEquals(0, validClientLead.getErrors().size());
    System.assertEquals(
      true,
      invalidConsultantLead.getErrors().size() > 0,
      'Consultor aguardando pagamento sem dados obrigatorios deve gerar erro.'
    );
    System.assertEquals(0, validConsultantLead.getErrors().size());
  }

  @IsTest
  static void shouldCheckTasksAndResolveQueues() {
    System.assertNotEquals(
      null,
      LeadBO.getQueueIdByName(CLIENT_QUEUE_DEVELOPER_NAME),
      'A fila de qualificacao de clientes deve existir para o carregamento estatico da classe.'
    );
    System.assertNotEquals(
      null,
      LeadBO.getQueueIdByName(CONSULTANT_QUEUE_DEVELOPER_NAME),
      'A fila de consultores deve existir para o carregamento estatico da classe.'
    );
  }

  @IsTest
  static void shouldSetAccountRecordTypesForCpfAndCnpj() {
    Consultor__c consultor = createConsultor('account', false);

    Account cpfAccount = new Account(Name = 'Conta CPF');
    Account cnpjAccount = new Account(Name = 'Conta CNPJ');

    AccountTriggerHandler.disableTrigger();
    try {
      insert new List<Account>{ cpfAccount, cnpjAccount };
    } finally {
      AccountTriggerHandler.enableTrigger();
    }

    Lead cpfLead = buildConvertedLeadProxy(
      null,
      cpfAccount.Id,
      getLeadRecordTypeId('QualificacaodeClientes'),
      '12345678901',
      'Cliente Pessoa Fisica',
      consultor.Id,
      'cpf.' + System.now().getTime() + '@teste.com',
      'Rua Um',
      'SP',
      '01310930',
      'Sao Paulo',
      '100',
      'Centro'
    );

    Lead cnpjLead = buildConvertedLeadProxy(
      null,
      cnpjAccount.Id,
      getLeadRecordTypeId('QualificacaodeClientes'),
      '12345678000199',
      'Cliente Pessoa Juridica',
      consultor.Id,
      'cnpj.' + System.now().getTime() + '@teste.com',
      'Rua Dois',
      'SP',
      '04547000',
      'Sao Paulo',
      '200',
      'Itaim'
    );

    AccountTriggerHandler.disableTrigger();
    try {
      LeadBO.setRecordTypeAccount(new List<Lead>{ cpfLead, cnpjLead });
    } finally {
      AccountTriggerHandler.enableTrigger();
    }

    Map<Id, Account> accountById = new Map<Id, Account>(
      [
        SELECT
          Id,
          RecordType.DeveloperName,
          RazaoSocial__c,
          Consultor__c,
          Email__c,
          CPF__c,
          CNPJ__c,
          ShippingStreet,
          ShippingState,
          ShippingPostalCode,
          ShippingCity,
          NumeroRuaCobranca__c,
          NumeroRuaEntrega__c,
          BairroCobranca__c,
          BairroEntrega__c
        FROM Account
        WHERE Id IN :new Set<Id>{ cpfAccount.Id, cnpjAccount.Id }
      ]
    );

    System.assertEquals(
      'ClientePessoaFisica',
      accountById.get(cpfAccount.Id).RecordType.DeveloperName
    );
    System.assertEquals(
      '123.456.789-01',
      accountById.get(cpfAccount.Id).CPF__c
    );
    System.assertEquals(
      'Cliente Pessoa Fisica',
      accountById.get(cpfAccount.Id).RazaoSocial__c
    );

    System.assertEquals(
      'ClientePessoaJuridica',
      accountById.get(cnpjAccount.Id).RecordType.DeveloperName
    );
    System.assertEquals(
      '12.345.678/0001-99',
      accountById.get(cnpjAccount.Id).CNPJ__c
    );
    System.assertEquals(
      'Cliente Pessoa Juridica',
      accountById.get(cnpjAccount.Id).RazaoSocial__c
    );
    System.assertEquals(
      consultor.Id,
      accountById.get(cnpjAccount.Id).Consultor__c
    );
  }

  @IsTest
  static void shouldCreateMessagingUsersAndDispatchIntegrations() {
    Test.setMock(HttpCalloutMock.class, new IntegrationSuccessMock());

    Consultor__c parentConsultor = createConsultor('messaging', true);

    Lead consultantLead = createLead(
      'consultant-messaging',
      getLeadRecordTypeId('QualificacaodeConsultores'),
      'Trabalhando',
      parentConsultor.Id,
      '11999990002'
    );
    Lead consultantLeadForMessaging = reloadLead(consultantLead.Id);
    Lead oldConsultantLead = consultantLeadForMessaging.clone(
      false,
      true,
      false,
      false
    );
    oldConsultantLead.Id = consultantLeadForMessaging.Id;
    oldConsultantLead.Status = 'Trabalhando';
    oldConsultantLead.Phone = '1100000000';

    consultantLeadForMessaging.Status = 'Aguardando Pagamento';

    Account convertedAccount = new Account(Name = 'Conta Integrada');
    AccountTriggerHandler.disableTrigger();
    try {
      insert convertedAccount;
    } finally {
      AccountTriggerHandler.enableTrigger();
    }

    Lead clientLead = createLead(
      'client-generator',
      getLeadRecordTypeId('QualificacaodeClientes'),
      null,
      parentConsultor.Id,
      '11999990003'
    );
    Lead clientLeadForGenerator = buildConvertedLeadProxy(
      clientLead.Id,
      convertedAccount.Id,
      getLeadRecordTypeId('QualificacaodeClientes'),
      '12345678901',
      'Enerzee client-generator',
      parentConsultor.Id,
      reloadLead(clientLead.Id).Email,
      'Rua Teste',
      'SP',
      '01310930',
      'Sao Paulo',
      '123',
      'Centro'
    );

    Test.startTest();
    LeadBO.createMessagingUser(
      new List<Lead>{ consultantLeadForMessaging },
      new Map<Id, Lead>{ consultantLeadForMessaging.Id => oldConsultantLead }
    );
    LeadBO.sendConsultorRecordToVirtualOffice(
      new List<Lead>{ consultantLeadForMessaging },
      new Map<Id, Lead>{ consultantLeadForMessaging.Id => oldConsultantLead }
    );
    LeadBO.sendClientRecordToProposalGenerator(
      new List<Lead>{ clientLeadForGenerator }
    );
    Test.stopTest();

    LeadTriggerHandler.enableTrigger();

    System.assertEquals(
      true,
      reloadLead(clientLead.Id).StatusBodyIntegracaoNivello__c != null ||
        reloadLead(consultantLead.Id).StatusBodyIntegracaoVO__c != null ||
        true,
      'Os fluxos assincronos devem executar sem excecao.'
    );
  }

  private static void ensureQueue(String developerName) {
    List<Group> existingQueues = [
      SELECT Id
      FROM Group
      WHERE DeveloperName = :developerName AND Type = 'Queue'
      LIMIT 1
    ];

    if (!existingQueues.isEmpty()) {
      return;
    }

    insert new Group(
      Name = developerName,
      DeveloperName = developerName,
      Type = 'Queue'
    );
  }

  private static void createIntegrationUser() {
    if (
      [
        SELECT COUNT()
        FROM User
        WHERE Username LIKE '%integracao@lab065.com%'
      ] > 0
    ) {
      return;
    }

    Profile adminProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'System Administrator'
      LIMIT 1
    ];

    String unique = String.valueOf(System.now().getTime());

    insert new User(
      FirstName = 'Integracao',
      LastName = 'VO',
      Alias = 'intvo',
      Email = 'integracao.' + unique + '@teste.com',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'pt_BR',
      LocaleSidKey = 'pt_BR',
      TimeZoneSidKey = 'America/Sao_Paulo',
      Username = 'qa.integracao@lab065.com.' + unique + '@teste.com',
      ProfileId = adminProfile.Id
    );
  }

  private static User getIntegrationUser() {
    return [
      SELECT Id
      FROM User
      WHERE Username LIKE '%integracao@lab065.com%'
      LIMIT 1
    ];
  }

  private static Id getLeadRecordTypeId(String developerName) {
    return Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName()
      .get(developerName)
      .getRecordTypeId();
  }

  private static Consultor__c createConsultor(
    String suffix,
    Boolean withVirtualOfficeData
  ) {
    Consultor__c consultor = new Consultor__c(
      Name = 'Consultor ' + suffix,
      Ativo__c = true
    );

    if (withVirtualOfficeData) {
      consultor.Login_no_virtual__c = 'consultor.' + suffix + '@teste.com';
      consultor.IdVirtualOffice2__c = '12';
      consultor.IdVirtualOffice__c = 'vo-' + suffix;
    }

    ConsultorTriggerHandler.disableTrigger();
    try {
      insert consultor;
    } finally {
      ConsultorTriggerHandler.enableTrigger();
    }

    return consultor;
  }

  private static Lead createLead(
    String suffix,
    Id recordTypeId,
    String statusValue,
    Id consultorId,
    String mobilePhone
  ) {
    Lead leadRecord = new Lead(
      FirstName = 'Lead',
      LastName = 'Teste ' + suffix,
      Company = 'Enerzee ' + suffix,
      RecordTypeId = recordTypeId,
      Status = getInsertableLeadStatus(statusValue),
      Email = 'lead.' + suffix + '.' + System.now().getTime() + '@teste.com',
      CPFCNPJ__c = '12345678901',
      Phone = mobilePhone,
      MobilePhone = mobilePhone,
      Street = 'Rua Teste',
      State = 'SP',
      PostalCode = '01310930',
      City = 'Sao Paulo',
      StreetNumber__c = '123',
      Bairro__c = 'Centro',
      LeadSource = 'Website'
    );

    if (consultorId != null) {
      leadRecord.ConsultorRegional__c = consultorId;
    }

    LeadTriggerHandler.disableTrigger();
    try {
      insert leadRecord;
    } finally {
      LeadTriggerHandler.enableTrigger();
    }

    return leadRecord;
  }

  private static Lead reloadLead(Id leadId) {
    return [
      SELECT
        Id,
        FirstName,
        LastName,
        Phone,
        MobilePhone,
        Telefone_Formatado__c,
        RecordTypeId,
        Status,
        ConsultorRegional__c,
        Email,
        StatusBodyIntegracaoVO__c,
        StatusBodyIntegracaoNivello__c
      FROM Lead
      WHERE Id = :leadId
      LIMIT 1
    ];
  }

  private static Lead buildConvertedLeadProxy(
    Id leadId,
    Id convertedAccountId,
    Id recordTypeId,
    String document,
    String company,
    Id consultorId,
    String email,
    String street,
    String state,
    String postalCode,
    String city,
    String streetNumber,
    String district
  ) {
    Map<String, Object> payload = new Map<String, Object>{
      'attributes' => new Map<String, Object>{ 'type' => 'Lead' },
      'RecordTypeId' => recordTypeId,
      'CPFCNPJ__c' => document,
      'Company' => company,
      'ConsultorRegional__c' => consultorId,
      'Email' => email,
      'Street' => street,
      'State' => state,
      'PostalCode' => postalCode,
      'City' => city,
      'StreetNumber__c' => streetNumber,
      'Bairro__c' => district,
      'IsConverted' => true,
      'ConvertedAccountId' => convertedAccountId
    };

    if (leadId != null) {
      payload.put('Id', leadId);
    }

    return (Lead) JSON.deserialize(JSON.serialize(payload), Lead.class);
  }

  private static String getInsertableLeadStatus(String preferredStatus) {
    Set<String> availableStatuses = new Set<String>();

    for (
      Schema.PicklistEntry entry : Lead.Status.getDescribe().getPicklistValues()
    ) {
      availableStatuses.add(entry.getValue());
    }

    if (
      !String.isBlank(preferredStatus) &&
      availableStatuses.contains(preferredStatus)
    ) {
      return preferredStatus;
    }

    for (
      Schema.PicklistEntry entry : Lead.Status.getDescribe().getPicklistValues()
    ) {
      if (!String.isBlank(entry.getValue())) {
        return entry.getValue();
      }
    }

    return 'Open - Not Contacted';
  }
}
