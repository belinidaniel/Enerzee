/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 12-16-2025
 * @last modified by	 : Daniel Belini
 **/
public class ProjetoTriggerHandler extends TriggerHandler {
  public ProjetoTriggerHandler() {
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
    ProjetoBO.populateFromOpportunity((List<Projeto__c>) newRecordList);
    ProjetoBO.setDefaultStatus((List<Projeto__c>) newRecordList);
    ProjetoBO.initializeStatusStartDate((List<Projeto__c>) newRecordList);
  }

  public override void afterInsert() {
    ProjetoBO.createTasks(
      (List<Projeto__c>) newRecordList,
      new Map<Id, Projeto__c>()
    );
    ProjetoBO.sendProjectToNivello((List<Projeto__c>) newRecordList);
  }

  public override void beforeUpdate() {
    ProjetoBO.checkTasksConclusionBeforeStatusChange(
      (List<Projeto__c>) newRecordList,
      (Map<Id, Projeto__c>) oldMap
    );
    ProjetoBO.populateFromOpportunity((List<Projeto__c>) newRecordList);
    ProjetoBO.updateStatusDurations(
      (List<Projeto__c>) newRecordList,
      (Map<Id, Projeto__c>) oldMap
    );
  }

  public override void afterUpdate() {
    ProjetoBO.createTasks(
      (List<Projeto__c>) newRecordList,
      (Map<Id, Projeto__c>) oldMap
    );
    ProjetoBO.sendProjectToNivello((List<Projeto__c>) newRecordList);
    ProjetoBO.createTaskOnboarding(
      (List<Projeto__c>) newRecordList,
      (Map<Id, Projeto__c>) oldMap
    );
    ProjetoBO.createTaskProjectApproved(
      (List<Projeto__c>) newRecordList,
      (Map<Id, Projeto__c>) oldMap
    );
    ProjetoBO.createTaskFinishProject(
      (List<Projeto__c>) newRecordList,
      (Map<Id, Projeto__c>) oldMap
    );
    ProjetoBO.syncOpportunityStatusFromProject(
      (List<Projeto__c>) newRecordList,
      (Map<Id, Projeto__c>) oldMap
    );
    // Garantir criação de instalação ao aprovar projeto
    InstalacaoBO.ensureInstallationOnProjectApproved(
      (List<Projeto__c>) newRecordList,
      (Map<Id, Projeto__c>) oldMap
    );
    ProjetoStatusIntegrationService.sendStatusUpdates(
      (List<Projeto__c>) newRecordList,
      (Map<Id, Projeto__c>) oldMap
    );
  }

  public override void beforeDelete() {
  }
  public override void afterDelete() {
  }
}
