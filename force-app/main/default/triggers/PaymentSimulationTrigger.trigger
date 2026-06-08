trigger PaymentSimulationTrigger on PaymentSimulation__c(
  before insert,
  before update,
  after insert,
  after update,
  after delete
) {
  new PaymentSimulationTriggerHandler().execute();
}
