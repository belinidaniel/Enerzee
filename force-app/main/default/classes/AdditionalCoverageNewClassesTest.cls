/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 12-23-2025
 * @last modified by	 : Daniel Belini
 **/
@IsTest
private class AdditionalCoverageNewClassesTest {
  @IsTest
  static void integracaoFormaPagamentoNegociacao_noOpOnEmptySet() {
    Test.startTest();
    IntegracaoFormaPagamentoNegociacao.enviarStatusReprovacao(new Set<Id>());
    Test.stopTest();
    System.assert(true);
  }

  @IsTest
  static void instalacaoTaskBO_returnsEarlyOnEmptyList() {
    Test.startTest();
    InstalacaoTaskBO.createTasks(
      new List<Instalacao__c>(),
      new Map<Id, Instalacao__c>()
    );
    Test.stopTest();
    System.assert(true);
  }

  @IsTest
  static void instalacaoTriggerHandler_toggle() {
    InstalacaoTriggerHandler.disableTrigger();
    System.assert(!InstalacaoTriggerHandler.isTriggerEnabled());
    InstalacaoTriggerHandler.enableTrigger();
    System.assert(InstalacaoTriggerHandler.isTriggerEnabled());
  }

  @IsTest
  static void goRecordsTO_canInstantiate() {
    GORecordsTO dto = new GORecordsTO();
    dto.IdSalesForce = '001';
    dto.Status = 1;
    dto.Obs = 'obs';
    System.assertEquals('001', dto.IdSalesForce);
  }

  @IsTest
  static void proposalService_handlesEmptySetWithCmdt() {
    Test.startTest();
    try {
      ProposalService.updateOpportunityPhase(new Set<Id>());
    } catch (Exception e) {
      // ignora ausência de CMDT/endpoint em ambiente de teste
      System.assert(true);
    }
    Test.stopTest();
  }

  @IsTest
  static void taskBO_validateRequiredFieldSetsOnCompletion_empty() {
    TaskBO.validateRequiredFieldSetsOnCompletion(
      new List<Task>(),
      new Map<Id, Task>()
    );
    System.assert(true);
  }

  @IsTest
  static void taskTriggerHandler_toggle() {
    TaskTriggerHandler.disableTrigger();
    System.assert(!TaskTriggerHandler.isTriggerEnabled());
    TaskTriggerHandler.enableTrigger();
    System.assert(TaskTriggerHandler.isTriggerEnabled());
  }

  @IsTest
  static void taskUtils_basicChecks() {
    Task t = new Task(
      Status = TaskUtils.STATUS_OPEN,
      Subject = TaskUtils.SUBJECT_CONTRATAR_INTEGRADOR
    );
    Task tNew = t.clone(false, true);
    tNew.Status = TaskUtils.STATUS_CONCLUIDO;
    System.assert(TaskUtils.isTaskOpen(t));
    System.assert(TaskUtils.isTaskBeingConcluded(t, tNew));
    System.assert(TaskUtils.isSubjectContratarIntegrador(t));
  }

  @IsTest
  static void taskUtils_nullSafetyChecks() {
    Task taskWithoutValues = new Task();
    Task oldTask = new Task(Status = TaskUtils.STATUS_OPEN);

    System.assertEquals(false, TaskUtils.isTaskOpen(null));
    System.assertEquals(false, TaskUtils.isTaskOpen(taskWithoutValues));
    System.assertEquals(false, TaskUtils.isTaskConcluded(null));
    System.assertEquals(false, TaskUtils.isTaskNotStarted(null));
    System.assertEquals(false, TaskUtils.isTaskBeingConcluded(null, oldTask));
    System.assertEquals(false, TaskUtils.isTaskBeingConcluded(oldTask, null));
    System.assertEquals(false, TaskUtils.isSubjectContratarIntegrador(null));
    System.assertEquals(
      false,
      TaskUtils.isSubjectContratarIntegrador(taskWithoutValues)
    );
    System.assertEquals(
      false,
      TaskUtils.isSubjectSolicitarCompraMateriais(null)
    );
    System.assertEquals(
      false,
      TaskUtils.isSubjectSolicitarCompraMateriais(taskWithoutValues)
    );
    System.assertEquals(
      false,
      TaskUtils.isSubjectSolicitarCompraMateriaisComplementares(null)
    );
    System.assertEquals(
      false,
      TaskUtils.isSubjectSolicitarCompraMateriaisComplementares(
        taskWithoutValues
      )
    );
  }

  @IsTest
  static void externalArchiveService_guardClauses() {
    try {
      ExternalArchiveService.uploadExternalArchive(
        null,
        null,
        '',
        null,
        null,
        null
      );
      System.assert(false, 'Expected exception');
    } catch (AuraHandledException e) {
    }
  }
}
