/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class ProjetoStatusIntegrationServiceTest implements HttpCalloutMock {
  private static User createRunAsUser() {
    Id profileId = [SELECT ProfileId FROM User WHERE Id = :UserInfo.getUserId()]
    .ProfileId;
    String uniqueToken =
      String.valueOf(DateTime.now().getTime()) +
      String.valueOf(Math.abs(Crypto.getRandomInteger()));

    User userRecord = new User(
      Alias = ('pst' + uniqueToken).left(8),
      Email = 'projeto.status.' + uniqueToken + '@test.com',
      Username = 'projeto.status.' + uniqueToken + '@test.com',
      LastName = 'ProjetoStatus',
      TimeZoneSidKey = 'America/Sao_Paulo',
      LocaleSidKey = 'pt_BR',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'pt_BR',
      ProfileId = profileId
    );
    insert userRecord;
    return userRecord;
  }

  private static void ensureTaskQueue() {
    List<Group> analistaQueues = [
      SELECT Id
      FROM Group
      WHERE DeveloperName = 'AnalistaViabilidade' AND Type = 'Queue'
      LIMIT 1
    ];
    Group analistaQueue;
    if (analistaQueues.isEmpty()) {
      analistaQueue = new Group(
        Type = 'Queue',
        Name = 'AnalistaViabilidade',
        DeveloperName = 'AnalistaViabilidade'
      );
      insert analistaQueue;
    } else {
      analistaQueue = analistaQueues[0];
    }

    List<QueueSobject> queueLinks = [
      SELECT Id
      FROM QueueSobject
      WHERE QueueId = :analistaQueue.Id AND SobjectType = 'Task'
      LIMIT 1
    ];
    if (queueLinks.isEmpty()) {
      insert new QueueSobject(QueueId = analistaQueue.Id, SobjectType = 'Task');
    }
  }

  public HTTPResponse respond(HTTPRequest req) {
    HttpResponse res = new HttpResponse();
    res.setStatusCode(200);
    res.setBody('{"success":true}');
    return res;
  }

  @IsTest(SeeAllData=true)
  static void shouldSendWhenStatusChanges() {
    ensureTaskQueue();

    System.runAs(createRunAsUser()) {
      Account acc = new Account(Name = 'Teste');
      insert acc;

      Opportunity opp = new Opportunity(
        Name = 'Opp Teste',
        StageName = 'Prospecting',
        CloseDate = Date.today().addDays(10),
        AccountId = acc.Id,
        IdVirtualOffice__c = 'd7f85a48-0e1e-46c8-8143-f4c15db60000'
      );
      insert opp;

      ViabilityStudy__c viability = new ViabilityStudy__c(
        Opportunity__c = opp.Id,
        TypeWorkProjectFeasibility__c = 'UFV Micro'
      );
      insert viability;

      Projeto__c projOld = new Projeto__c(
        Name = 'Projeto Teste',
        Oportunidade__c = opp.Id,
        Viabilidade__c = viability.Id,
        Status__c = ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO,
        Conta__c = acc.Id
      );
      insert projOld;

      Projeto__c projNew = [
        SELECT Id, Status__c, SubStatus__c, MotivoSubStatus__c
        FROM Projeto__c
        WHERE Id = :projOld.Id
      ];
      Map<Id, Projeto__c> oldMap = new Map<Id, Projeto__c>{
        projNew.Id => projNew.clone(false, true, false, false)
      };
      projNew.Status__c = ProjetoUtils.STATUS_PROJETO_APROVADO;
      projNew.SubStatus__c = 'Aprovado Parcialmente';
      projNew.MotivoSubStatus__c = 'motivo teste';
      update projNew;

      Test.startTest();
      ProjetoStatusIntegrationService.endpointOverride = 'https://example.com/project-status';
      Test.setMock(
        HttpCalloutMock.class,
        new ProjetoStatusIntegrationServiceTest()
      );
      ProjetoStatusIntegrationService.sendStatusUpdates(
        new List<Projeto__c>{ projNew },
        oldMap
      );
      Test.stopTest();
      ProjetoStatusIntegrationService.endpointOverride = null;
    }
  }

  @IsTest
  static void shouldMapStatuses() {
    System.assertEquals(
      1,
      ProjetoStatusIntegrationService.mapStatus(
        ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO
      )
    );
    System.assertEquals(
      2,
      ProjetoStatusIntegrationService.mapStatus(
        ProjetoUtils.STATUS_PROJETOS_EM_ELABORACAO
      )
    );
    System.assertEquals(
      3,
      ProjetoStatusIntegrationService.mapStatus(
        ProjetoUtils.STATUS_PROJETO_EM_ANALISE
      )
    );
    System.assertEquals(
      4,
      ProjetoStatusIntegrationService.mapStatus(
        ProjetoUtils.STATUS_PROJETO_APROVADO
      )
    );
    System.assertEquals(
      5,
      ProjetoStatusIntegrationService.mapStatus('Projeto cancelado')
    );
    System.assertEquals(null, ProjetoStatusIntegrationService.mapStatus(null));
    System.assertEquals(
      null,
      ProjetoStatusIntegrationService.mapStatus('Status inexistente')
    );

    System.assertEquals(
      1,
      ProjetoStatusIntegrationService.mapSubStatus('Aprovado')
    );
    System.assertEquals(
      2,
      ProjetoStatusIntegrationService.mapSubStatus('Aprovado Parcialmente')
    );
    System.assertEquals(
      3,
      ProjetoStatusIntegrationService.mapSubStatus('Cancelado')
    );
    System.assertEquals(
      null,
      ProjetoStatusIntegrationService.mapSubStatus(null)
    );
    System.assertEquals(
      null,
      ProjetoStatusIntegrationService.mapSubStatus('Outro valor')
    );
  }

  @IsTest
  static void shouldIgnoreGuardClausesWithoutErrors() {
    Test.startTest();
    ProjetoStatusIntegrationService.sendStatusUpdates(null, null);
    ProjetoStatusIntegrationService.sendStatusUpdates(
      new List<Projeto__c>(),
      new Map<Id, Projeto__c>()
    );
    ProjetoStatusIntegrationService.sendStatusUpdates(
      new List<Projeto__c>{ new Projeto__c() },
      new Map<Id, Projeto__c>()
    );
    Test.stopTest();
  }
}
