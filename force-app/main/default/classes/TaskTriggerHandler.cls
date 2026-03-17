/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : AdditionalCoverageNewClassesTest, OpportunityBOCoverageTest, OpportunityBOHighCoverageTest,
 *                       OpportunityBOPaymentReminderTaskTest, ProjetoBOCoverageTest, ProjetoTriggerTest,
 *                       TaskStateServiceTest, TaskTriggerTest, WorkDeliveryReportPdfControllerTest
 **/
public class TaskTriggerHandler extends TriggerHandler {
  public TaskTriggerHandler() {
    super(
      Trigger.operationType,
      Trigger.new,
      Trigger.old,
      Trigger.newMap,
      Trigger.oldMap
    );
  }

  public static boolean enabled = true;
  public static boolean isTriggerEnabled() {
    return enabled;
  }

  public static void enableTrigger() {
    enabled = true;
  }

  public static void disableTrigger() {
    enabled = false;
  }

  public override void beforeInsert() {
    // SAL-403: marca tasks avulsas (não mapeadas nas tabelas de config) como IgnorarValidacao__c = true
    TaskBO.markManualTasksAsIgnoreValidation((List<Task>) newRecordList);
    TaskBO.preventDuplicateOpenTasks((List<Task>) newRecordList);
  }

  public override void afterInsert() {
  }

  public override void beforeUpdate() {
    TaskBO.validateRequiredFieldSetsOnCompletion(
      (List<Task>) Trigger.new,
      (Map<Id, Task>) Trigger.oldMap
    );
  }

  public override void afterUpdate() {
    TaskBO.createWorkOrderContractingIntegrator(
      (List<Task>) newRecordList,
      (Map<Id, Task>) oldMap
    );
    TaskBO.createWorkOrderRequestMaterialBuy(
      (List<Task>) newRecordList,
      (Map<Id, Task>) oldMap
    );
    TaskBO.notifyAfterTaskConclusion(
      (List<Task>) newRecordList,
      (Map<Id, Task>) oldMap
    );
    TaskBO.updateProjectPhase(
      (List<Task>) newRecordList,
      (Map<Id, Task>) oldMap
    );
    TaskBO.handleAprovacaoProjetoUfv(
      (List<Task>) newRecordList,
      (Map<Id, Task>) oldMap
    );
    TaskBO.checkTaskCloser((List<Task>) newRecordList, (Map<Id, Task>) oldMap);
    TaskBO.updateViabilityStatusOnTaskCompletion(
      (List<Task>) newRecordList,
      (Map<Id, Task>) oldMap
    );
    TaskBO.createNFConfirmationTask(
      (List<Task>) newRecordList,
      (Map<Id, Task>) oldMap
    );
  }

  public override void beforeDelete() {
  }
  public override void afterDelete() {
  }
}
