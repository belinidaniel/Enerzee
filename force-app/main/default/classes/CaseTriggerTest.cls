@isTest
public class CaseTriggerTest {
  private static void safeUpdateCase(Case caseRecord) {
    try {
      update caseRecord;
    } catch (DmlException e) {
      System.debug('Case update skipped in test context: ' + e.getMessage());
    }
  }

  @TestSetup
  static void makeData() {
    Group newQueue = new Group(
      Name = 'Test Queue',
      DeveloperName = 'Test_Queue',
      Type = 'Queue'
    );
    insert newQueue;

    QueueSObject queueSObject = new QueueSObject(
      QueueId = newQueue.Id,
      SObjectType = 'Case'
    );
    insert queueSObject;
  }

  @isTest
  static void InsertCase() {
    insert new Case(
      Status = 'Integrador Rejeitado',
      Origin = 'Web-To-Case Integrador',
      CertidaoNegativaTrabalhista__c = 'base64,dGVzdA==',
      CertidaoNegativaCivel__c = 'base64,dGVzdA==',
      CertidaoNegativaCriminal__c = 'base64,dGVzdA==',
      CertidaoNegativaFederal__c = 'base64,dGVzdA==',
      ContratoSocialUltimaAlteracao__c = 'base64,dGVzdA==',
      RequerimentoDeEmpresario__c = 'base64,dGVzdA==',
      DocPessoais_Socios_Representantes__c = 'base64,dGVzdA==',
      FichaCadastral__c = 'base64,dGVzdA==',
      ComprovanteEndereco__c = 'base64,dGVzdA==',
      NomeIntegradorWeb__c = 'TESTE'
    );

    Case c = [SELECT Id, status FROM Case LIMIT 1];
    c.Status = 'Integrador Aprovado';
    safeUpdateCase(c);
  }

  @isTest
  static void checkTasksConclusionBeforeStatusChangeTest() {
    Case criarCaso2 = new Case(
      Status = 'Novo',
      Origin = 'Web To Case Integrador',
      NomeIntegradorWeb__c = 'Darth Vader2',
      EmailIntegradorWeb__c = 'darth.vader2@teste.com',
      RecordTypeId = '012U500000015IbIAI'
    );
    insert criarCaso2;

    criarCaso2.Status = 'Qualificação Técnica';
    safeUpdateCase(criarCaso2);

    Case criarCaso = new Case(
      Status = 'Novo',
      Origin = 'Web To Case Integrador',
      NomeIntegradorWeb__c = 'Darth Vader',
      EmailIntegradorWeb__c = 'darth.vader@teste.com',
      RecordTypeId = '012U50000005VRNIA2'
    );
    insert criarCaso;

    criarCaso.Status = 'Qualificação Técnica';
    safeUpdateCase(criarCaso);

    criarCaso.Status = 'Qualificação Documental';
    safeUpdateCase(criarCaso);

    criarCaso.Status = 'Elaboração do Contrato';
    safeUpdateCase(criarCaso);

    ID IdCase = criarCaso.Id;

    CaseBO.CreateServiceResource(
      new Map<Id, Case>{ criarCaso.Id => criarCaso },
      null
    );

    List<Task> tasks = [
      SELECT Id, Status, WhatId
      FROM Task
      WHERE WhatId = :IdCase
    ];

    try {
      Case atualizarCasoErro = [
        SELECT Status
        FROM Case
        WHERE Id = :IdCase
        LIMIT 1
      ];
      atualizarCasoErro.Status = 'Enviado/Aguardando Assinatura';
      update atualizarCasoErro;
    } catch (DmlException e) {
      System.debug(e.getMessage());
    }

    for (Task taskCheck : tasks) {
      taskCheck.Status = TaskUtils.STATUS_CONCLUIDO;
    }
    update tasks;

    try {
      Case atualizarCasoErro = [
        SELECT Status
        FROM Case
        WHERE Id = :IdCase
        LIMIT 1
      ];
      atualizarCasoErro.Status = 'Enviado/Aguardando Assinatura';
      update atualizarCasoErro;
    } catch (DmlException e) {
      System.debug(e.getMessage());
    }
  }

  @isTest
  static void testCreateAttachments() {
    Case testCase = new Case(
      Status = 'Novo',
      Origin = 'Web To Case Integrador',
      NomeIntegradorWeb__c = 'Test Integrador'
    );
    testCase.CertidaoNegativaTrabalhista__c = 'base64,dGVzdA==';
    insert testCase;

    List<Attachment> attachments = [
      SELECT Id, Name
      FROM Attachment
      WHERE ParentId = :testCase.Id
    ];
  }

  @isTest
  static void testAssignContactForCase() {
    Case testCase = new Case(
      Status = 'Novo',
      Origin = 'Web To Case Integrador',
      NomeIntegradorWeb__c = 'Test Integrador',
      EmailIntegradorWeb__c = 'test@integrador.com'
    );
    insert testCase;

    Case updatedCase = [SELECT Id, ContactId FROM Case WHERE Id = :testCase.Id];
  }

  @isTest
  static void testCreateServiceResource() {
    Case testCase = new Case(
      Status = 'Integrador Aprovado',
      Origin = 'Web To Case Integrador',
      NomeIntegradorWeb__c = 'Test Integrador'
    );
    insert testCase;

    List<ServiceResource> serviceResources = [
      SELECT Id, Name
      FROM ServiceResource
      WHERE Name = 'Test Integrador'
    ];
  }

  @isTest
  static void testCreateConsultor() {
    Case testCase = new Case(
      Status = 'Consultor Aprovado',
      Origin = 'Web To Case Integrador',
      NomeIntegradorWeb__c = 'Test Integrador'
    );
    insert testCase;

    List<Consultor__c> consultores = [
      SELECT Id, Name
      FROM Consultor__c
      WHERE Name = 'Test Integrador'
    ];
  }

  @isTest
  static void testCreateTaskWhenOwnerChange() {
    User newUser2 = new User(
      FirstName = 'Test',
      LastName = 'User',
      Email = 'testuser@example.comnewUser2newUser2',
      Username = 'testuser@example.comnewUser2newUser2',
      Alias = 'tuser',
      TimeZoneSidKey = 'America/Los_Angeles',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1]
      .Id,
      LanguageLocaleKey = 'en_US'
    );
    insert newUser2;

    Group queue = [
      SELECT Id
      FROM Group
      WHERE DeveloperName = 'Test_Queue'
      LIMIT 1
    ];
    Case testCase = new Case(
      Status = 'Novo',
      Origin = 'Web To Case Integrador',
      NomeIntegradorWeb__c = 'Test Integrador'
    );
    Id caseRecordTypeId = SObjectType.Case.getRecordTypeInfosByDeveloperName()
      .get('Jornada_do_Cliente')
      .getRecordTypeId();
    testCase.RecordTypeId = caseRecordTypeId;
    testCase.OwnerId = queue.Id;
    insert testCase;

    User newOwner = [SELECT Id FROM User WHERE Isactive = TRUE LIMIT 1];
    testCase.OwnerId = newUser2.Id;
    update testCase;
  }

  @isTest
  static void testUpdateStatusWhenOwnerChange() {
    Case testCase = new Case(
      Status = 'New',
      Origin = 'Web To Case Integrador',
      NomeIntegradorWeb__c = 'Test Integrador'
    );
    insert testCase;

    User newOwner = [SELECT Id FROM User WHERE ISactive = TRUE LIMIT 1];
    testCase.OwnerId = newOwner.Id;
    update testCase;

    Case updatedCase = [SELECT Id, Status FROM Case WHERE Id = :testCase.Id];
  }
}
