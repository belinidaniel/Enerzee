trigger PaymentSimulationTrigger on PaymentSimulation__c(
  before insert,
  before update,
  after insert,
  after update
) {
  new PaymentSimulationTriggerHandler().execute();
}
