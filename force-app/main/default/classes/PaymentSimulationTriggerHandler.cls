/**
 * @description       : Encapsula os eventos de trigger da simulação de pagamento
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-02-2026
 * @last modified by  : OpenAI Codex
 * @test              : PaymentSimulationBOTest, PaymentSimulationCardControllerTest
 **/
public class PaymentSimulationTriggerHandler extends TriggerHandler {
  public static Boolean isRunning = false;

  public PaymentSimulationTriggerHandler() {
    super(
      Trigger.operationType,
      Trigger.new,
      Trigger.old,
      Trigger.newMap,
      Trigger.oldMap
    );
  }

  public override void beforeInsert() {
    if (isRunning) {
      return;
    }

    PaymentSimulationBO.normalizeSelectionDetails(
      (List<PaymentSimulation__c>) Trigger.new,
      null
    );
    PaymentSimulationBO.enforceSelectedToggle(
      (List<PaymentSimulation__c>) Trigger.new,
      null
    );
  }

  public override void afterInsert() {
    if (isRunning) {
      return;
    }

    PaymentSimulationBO.syncSelectedToOpportunity(
      (List<PaymentSimulation__c>) Trigger.new,
      null
    );
  }

  public override void beforeUpdate() {
    if (isRunning) {
      return;
    }

    PaymentSimulationBO.normalizeSelectionDetails(
      (List<PaymentSimulation__c>) Trigger.new,
      (Map<Id, PaymentSimulation__c>) Trigger.oldMap
    );
    PaymentSimulationBO.enforceSelectedToggle(
      (List<PaymentSimulation__c>) Trigger.new,
      (Map<Id, PaymentSimulation__c>) Trigger.oldMap
    );
  }

  public override void afterUpdate() {
    if (isRunning) {
      return;
    }

    PaymentSimulationBO.syncSelectedToOpportunity(
      (List<PaymentSimulation__c>) Trigger.new,
      (Map<Id, PaymentSimulation__c>) Trigger.oldMap
    );
  }

  public override void beforeDelete() {
  }

  public override void afterDelete() {
  }
}
