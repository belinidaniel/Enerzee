/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : ActivityDocumentControllerTest, AdditionalCoverageNewClassesTest, InstalacaoTriggerHandlerTest,
 *                       InstallCompletionNotifyServiceTest, OppClosedLostFlowActionTest, OpportunityBOHighCoverageTest,
 *                       WorkDeliveryReportPdfControllerTest
 **/
public class InstalacaoTriggerHandler extends TriggerHandler {
  public InstalacaoTriggerHandler() {
    super(
      Trigger.operationType,
      Trigger.new,
      Trigger.old,
      Trigger.newMap,
      Trigger.oldMap
    );
  }

  public static Boolean enabled = true;
  public static Boolean isTriggerEnabled() {
    return enabled;
  }

  public static void enableTrigger() {
    enabled = true;
  }

  public static void disableTrigger() {
    enabled = false;
  }

  public override void beforeInsert() {
  }
  public override void afterInsert() {
    InstalacaoTaskBO.createTasks(
      (List<Instalacao__c>) newRecordList,
      new Map<Id, Instalacao__c>()
    );
  }
  public override void beforeUpdate() {
    InstalacaoBO.checkTasksConclusionBeforeStatusChange(
      (List<Instalacao__c>) newRecordList,
      (Map<Id, Instalacao__c>) oldMap
    );
    // SAL-402: bloqueia avanço para Obra Concluída sem campos obrigatórios
    InstalacaoBO.validateRequiredFieldsOnObraConluida(
      (List<Instalacao__c>) newRecordList,
      (Map<Id, Instalacao__c>) oldMap
    );
  }
  public override void afterUpdate() {
    InstalacaoTaskBO.createTasks(
      (List<Instalacao__c>) newRecordList,
      (Map<Id, Instalacao__c>) oldMap
    );
    InstallCompletionNotifyService.notifyOnCompletion(
      (List<Instalacao__c>) newRecordList,
      (Map<Id, Instalacao__c>) oldMap
    );
    InstalacaoFinalReportService.enqueueIfNeeded(
      (List<Instalacao__c>) newRecordList,
      (Map<Id, Instalacao__c>) oldMap
    );
  }
  public override void beforeDelete() {
  }
  public override void afterDelete() {
  }
}
