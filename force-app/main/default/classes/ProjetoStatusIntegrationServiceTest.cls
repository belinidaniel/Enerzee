@IsTest
private class ProjetoStatusIntegrationServiceTest implements HttpCalloutMock {
  public HTTPResponse respond(HTTPRequest req) {
    HttpResponse res = new HttpResponse();
    res.setStatusCode(200);
    res.setBody('{"success":true}');
    return res;
  }

  @IsTest(SeeAllData=true)
  static void shouldSendWhenStatusChanges() {
    // Fila necessária para validações de tarefas disparadas por projeto
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
    try {
      insert new QueueSobject(QueueId = analistaQueue.Id, SobjectType = 'Task');
    } catch (DmlException e) {
      System.debug(
        'QueueSobject already exists for test queue: ' + e.getMessage()
      );
    }

    // Preparar dados mínimos
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
    Test.setMock(
      HttpCalloutMock.class,
      new ProjetoStatusIntegrationServiceTest()
    );
    ProjetoStatusIntegrationService.sendStatusUpdates(
      new List<Projeto__c>{ projNew },
      oldMap
    );
    Test.stopTest();
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
  }
}
