/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-23-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class OppClosedLostFlowActionTest {
  @IsTest
  static void run_shouldCloseOpenTasksForAutoClosedLostOpportunity() {
    TaskTriggerHandler.disableTrigger();
    OpportunityTriggerHandler.disableTrigger();
    ProjetoTriggerHandler.disableTrigger();
    InstalacaoTriggerHandler.disableTrigger();

    try {
      Account accountRecord = (Account) TestFactory.createSObject(
        new Account(Name = 'ACC-CLOSED-LOST-FLOW'),
        true
      );

      Opportunity opportunityRecord = (Opportunity) TestFactory.createSObject(
        new Opportunity(
          Name = 'Opp Closed Lost Flow',
          AccountId = accountRecord.Id,
          StageName = OpportunityUtils.STATUS_FECHADO_PERDIDO,
          CloseDate = Date.today(),
          DescricaoMotivoPerda__c = 'Fechado por inatividade',
          Loss_Reason__c = 'Parado por 30 dias'
        ),
        true
      );

      Task openTask = (Task) TestFactory.createSObject(
        new Task(
          Subject = 'Task auto close',
          Status = TaskUtils.STATUS_OPEN,
          WhatId = opportunityRecord.Id,
          ActivityDate = Date.today()
        ),
        true
      );

      OppClosedLostFlowAction.Request request = new OppClosedLostFlowAction.Request();
      request.run = true;

      Test.startTest();
      List<OppClosedLostFlowAction.Response> responses = OppClosedLostFlowAction.run(
        new List<OppClosedLostFlowAction.Request>{ request }
      );
      Test.stopTest();

      Task refreshedTask = [
        SELECT Status, Description
        FROM Task
        WHERE Id = :openTask.Id
      ];

      System.assertEquals(1, responses.size());
      System.assertEquals(1, responses[0].processedCount);
      System.assertEquals(TaskUtils.STATUS_CONCLUIDO, refreshedTask.Status);
      System.assert(
        refreshedTask.Description != null &&
        refreshedTask.Description.contains('Encerrado automaticamente'),
        'A tarefa deve receber a nota de automacao.'
      );
    } finally {
      TaskTriggerHandler.enableTrigger();
      OpportunityTriggerHandler.enableTrigger();
      ProjetoTriggerHandler.enableTrigger();
      InstalacaoTriggerHandler.enableTrigger();
    }
  }
}
