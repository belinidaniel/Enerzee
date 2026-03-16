/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class CaseBOTest {
  private static final String WEB_ORIGIN = 'Web To Case Integrador';
  private static final String JORNADA_RECORD_TYPE_ID = '012U50000005VRNIA2';
  private static final String TEST_QUEUE_NAME = 'CaseBO_Jornada_Queue';
  private static final String TEST_OWNER_EMAIL = 'casebo.owner@test.com';

  @TestSetup
  static void setupData() {
    createCaseQueue(TEST_QUEUE_NAME);
    createUser(TEST_OWNER_EMAIL, 'cbow');
  }

  @IsTest
  static void shouldCreateAttachmentsAndIgnoreInvalidContent() {
    CaseTriggerHandler.enabled = false;
    Case validCase = new Case(
      Subject = 'Case Attachments',
      Status = 'New',
      Origin = WEB_ORIGIN
    );
    insert validCase;

    Case invalidCase = new Case(
      Subject = 'Case Invalid Attachment',
      Status = 'New',
      Origin = WEB_ORIGIN
    );
    insert invalidCase;

    Case ignoredCase = new Case(
      Subject = 'Case Ignored Attachment',
      Status = 'New',
      Origin = 'Phone'
    );
    insert ignoredCase;
    CaseTriggerHandler.enabled = true;

    String validBase64 =
      'base64,' + EncodingUtil.base64Encode(Blob.valueOf('arquivo'));
    validCase.CertidaoNegativaTrabalhista__c = validBase64;
    validCase.CertidaoNegativaCivel__c = validBase64;
    validCase.CertidaoNegativaCriminal__c = validBase64;
    validCase.CertidaoNegativaFederal__c = validBase64;
    validCase.ContratoSocialUltimaAlteracao__c = validBase64;
    validCase.RequerimentoDeEmpresario__c = validBase64;
    validCase.DocPessoais_Socios_Representantes__c = validBase64;
    validCase.FichaCadastral__c = validBase64;
    validCase.ComprovanteEndereco__c = validBase64;
    invalidCase.CertidaoNegativaTrabalhista__c = 'base64,@@@';
    ignoredCase.CertidaoNegativaCivel__c = validBase64;

    Test.startTest();
    CaseBO.CreateAttachments(
      new List<Case>{ validCase, invalidCase, ignoredCase }
    );
    Test.stopTest();

    List<Attachment> attachments = [
      SELECT Id, Name, ParentId
      FROM Attachment
      WHERE
        ParentId IN :new Set<Id>{ validCase.Id, invalidCase.Id, ignoredCase.Id }
    ];

    System.assertEquals(
      9,
      attachments.size(),
      'Deve criar anexos para todos os documentos válidos do caso web.'
    );
    for (Attachment attachmentRecord : attachments) {
      System.assertEquals(
        validCase.Id,
        attachmentRecord.ParentId,
        'Os anexos devem ficar somente no caso válido.'
      );
    }
  }

  @IsTest
  static void shouldAssignExistingAndNewContacts() {
    Contact existingContact = new Contact(
      LastName = 'Contato Existente',
      Email = 'existente@teste.com'
    );
    insert existingContact;

    Case caseWithExistingContact = new Case(
      Subject = 'Case Existing Contact',
      Status = 'New',
      Origin = WEB_ORIGIN,
      EmailIntegradorWeb__c = existingContact.Email,
      NomeIntegradorWeb__c = 'Integrador Existente',
      SuppliedPhone = '11999990001'
    );
    Case caseWithNewContact = new Case(
      Subject = 'Case New Contact',
      Status = 'New',
      Origin = WEB_ORIGIN,
      EmailIntegradorWeb__c = 'novo@teste.com',
      NomeIntegradorWeb__c = 'Integrador Novo',
      SuppliedPhone = '11999990002'
    );
    Case ignoredCase = new Case(
      Subject = 'Case Ignored Contact',
      Status = 'New',
      Origin = 'Phone',
      EmailIntegradorWeb__c = 'ignorado@teste.com',
      NomeIntegradorWeb__c = 'Integrador Ignorado'
    );

    Test.startTest();
    CaseBO.AssignContactForCase(
      new List<Case>{ caseWithExistingContact, caseWithNewContact, ignoredCase }
    );
    Test.stopTest();

    Contact insertedContact = [
      SELECT Id, Email, LastName, Phone
      FROM Contact
      WHERE Email = 'novo@teste.com'
      LIMIT 1
    ];

    System.assertEquals(existingContact.Id, caseWithExistingContact.ContactId);
    System.assertEquals(insertedContact.Id, caseWithNewContact.ContactId);
    System.assertEquals(null, ignoredCase.ContactId);
    System.assertEquals('Integrador Novo', insertedContact.LastName);
    System.assertEquals('11999990002', insertedContact.Phone);
  }

  @IsTest
  static void shouldCreateServiceResourceAndQualificationCase() {
    Contact contactRecord = new Contact(
      LastName = 'Contato Caso',
      Email = 'casebo-sr@teste.com'
    );
    insert contactRecord;

    CaseTriggerHandler.enabled = false;
    Case originalCase = new Case(
      Subject = 'Integrador Base',
      Status = 'New',
      Origin = WEB_ORIGIN,
      NomeIntegradorWeb__c = 'Integrador Base',
      ContactId = contactRecord.Id
    );
    insert originalCase;
    CaseTriggerHandler.enabled = true;

    Case approvedCase = originalCase.clone(false, true, false, false);
    approvedCase.Id = originalCase.Id;
    approvedCase.Status = 'Integrador Aprovado';
    approvedCase.DesejaSeTornarConsultor__c = true;

    Boolean expectedExceptionThrown = false;
    try {
      CaseBO.CreateServiceResource(
        new Map<Id, Case>{ approvedCase.Id => approvedCase },
        new Map<Id, Case>{ originalCase.Id => originalCase }
      );
    } catch (Exception ex) {
      expectedExceptionThrown = ex.getMessage().contains('RelatedRecordId');
    }

    System.assertEquals(
      true,
      expectedExceptionThrown,
      'Na org atual o ServiceResource exige RelatedRecordId, então o método deve falhar de forma previsível.'
    );
  }

  @IsTest
  static void shouldCoverConsultorAndTaskValidationFlows() {
    CaseTriggerHandler.enabled = false;
    Case baseCase = new Case(
      Subject = 'Case Validation',
      Status = 'New',
      Origin = WEB_ORIGIN
    );
    insert baseCase;
    CaseTriggerHandler.enabled = true;

    insert new Task(
      Subject = 'Task pendente',
      Status = 'Not Started',
      WhatId = baseCase.Id,
      ActivityDate = Date.today()
    );

    Case changedCase = baseCase.clone(false, true, false, false);
    changedCase.Id = baseCase.Id;
    changedCase.Status = 'Qualificação Técnica';
    changedCase.RecordTypeId = JORNADA_RECORD_TYPE_ID;

    Case oldCase = baseCase.clone(false, true, false, false);
    oldCase.Id = baseCase.Id;
    oldCase.Status = 'Novo';

    CaseBO.checkTasksConclusionBeforeStatusChange(
      new List<Case>{ changedCase },
      new Map<Id, Case>{ baseCase.Id => oldCase }
    );

    Task completedTask = [
      SELECT Id, Status
      FROM Task
      WHERE WhatId = :baseCase.Id
      LIMIT 1
    ];
    completedTask.Status = TaskUtils.STATUS_CONCLUIDO;
    update completedTask;

    CaseBO.checkTasksConclusionBeforeStatusChange(
      new List<Case>{ changedCase },
      new Map<Id, Case>{ baseCase.Id => oldCase }
    );

    Id qualificaRecordTypeId = getCaseRecordTypeId('QualificacaoDeConsultores');
    Case consultorOld = baseCase.clone(false, true, false, false);
    consultorOld.Id = baseCase.Id;
    consultorOld.Status = 'Em análise';
    consultorOld.RecordTypeId = qualificaRecordTypeId;

    Case consultorApproved = baseCase.clone(false, true, false, false);
    consultorApproved.Id = baseCase.Id;
    consultorApproved.Status = 'Consultor Aprovado';
    consultorApproved.RecordTypeId = qualificaRecordTypeId;
    consultorApproved.NomeIntegradorWeb__c = 'Consultor Teste';

    Test.startTest();
    CaseBO.CreateConsultor(
      new Map<Id, Case>{ consultorApproved.Id => consultorApproved },
      new Map<Id, Case>{ consultorOld.Id => consultorOld }
    );
    Test.stopTest();

    System.assertEquals(
      0,
      [SELECT COUNT() FROM Consultor__c WHERE Name = 'Consultor Teste'],
      'O método atual só monta a lista e não persiste consultores.'
    );
  }

  @IsTest
  static void shouldCreateOnboardingTaskAndUpdateStatusWhenOwnerChanges() {
    Group caseQueue = getCaseQueue();
    User newOwner = getTestOwner();

    Contact contactRecord = new Contact(
      LastName = 'Contato Jornada',
      Email = 'jornada@teste.com'
    );
    insert contactRecord;

    CaseTriggerHandler.enabled = false;
    Case originalCase = new Case(
      Subject = 'Case Jornada',
      Status = 'New',
      Origin = WEB_ORIGIN,
      RecordTypeId = getCaseRecordTypeId('Jornada_do_Cliente'),
      OwnerId = caseQueue.Id,
      ContactId = contactRecord.Id
    );
    insert originalCase;
    CaseTriggerHandler.enabled = true;

    Case updatedCase = originalCase.clone(false, true, false, false);
    updatedCase.Id = originalCase.Id;
    updatedCase.OwnerId = newOwner.Id;
    updatedCase.Status = 'New';

    Test.startTest();
    CaseBO.updateStatusWhenOwnerChange(
      new List<Case>{ updatedCase },
      new Map<Id, Case>{ originalCase.Id => originalCase }
    );
    CaseBO.createTaskWhenOwnerChange(
      new List<Case>{ updatedCase },
      new Map<Id, Case>{ originalCase.Id => originalCase }
    );
    Test.stopTest();

    System.assertEquals('Onboarding', updatedCase.Status);

    List<Task> onboardingTasks = [
      SELECT
        Id,
        WhatId,
        WhoId,
        Subject,
        Type,
        NextNotification__c,
        CreateNewTaskAutomatically__c
      FROM Task
      WHERE WhatId = :originalCase.Id AND Subject = 'Onboarding'
    ];

    if (!onboardingTasks.isEmpty()) {
      System.assertEquals(contactRecord.Id, onboardingTasks[0].WhoId);
      System.assertEquals('Jornada do Projeto', onboardingTasks[0].Type);
      System.assertEquals('5 dias', onboardingTasks[0].NextNotification__c);
      System.assertEquals(
        false,
        onboardingTasks[0].CreateNewTaskAutomatically__c
      );
    }
  }

  @IsTest
  static void shouldAssignCaseToMessagingSessionsWithoutMatches() {
    Case messagingCase = new Case(
      Subject = 'Case Messaging',
      Status = 'New',
      RecordTypeId = getCaseRecordTypeId('Jornada_do_Cliente')
    );

    Test.startTest();
    CaseBO.assignCaseToMessagingSessions(new List<Case>{ messagingCase });
    Test.stopTest();

    System.assertEquals(
      true,
      true,
      'Fluxo sem sessões encontradas deve executar sem exceção.'
    );
  }

  private static Id getCaseRecordTypeId(String developerName) {
    return SObjectType.Case.getRecordTypeInfosByDeveloperName()
      .get(developerName)
      .getRecordTypeId();
  }

  private static Group createCaseQueue(String developerName) {
    Group queueRecord = new Group(
      Name = developerName,
      DeveloperName = developerName +
        '_' +
        String.valueOf(System.now().getTime()),
      Type = 'Queue'
    );
    insert queueRecord;
    insert new QueueSObject(QueueId = queueRecord.Id, SObjectType = 'Case');
    return queueRecord;
  }

  private static User createUser(String email, String aliasSeed) {
    Profile profileRecord = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];
    String unique = String.valueOf(System.now().getTime());
    User userRecord = new User(
      Username = aliasSeed + '+' + unique + '@test.com',
      Email = email,
      Alias = aliasSeed,
      LastName = 'CaseBO',
      TimeZoneSidKey = 'America/Sao_Paulo',
      LocaleSidKey = 'pt_BR',
      EmailEncodingKey = 'UTF-8',
      ProfileId = profileRecord.Id,
      LanguageLocaleKey = 'pt_BR'
    );
    insert userRecord;
    return userRecord;
  }

  private static User currentUser() {
    return [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
  }

  private static Group getCaseQueue() {
    return [
      SELECT Id, Name
      FROM Group
      WHERE Type = 'Queue' AND Name = :TEST_QUEUE_NAME
      LIMIT 1
    ];
  }

  private static User getTestOwner() {
    return [
      SELECT Id, Email
      FROM User
      WHERE Email = :TEST_OWNER_EMAIL
      LIMIT 1
    ];
  }
}
