// Execute via Developer Console (Execute Anonymous) or `sf apex run --file scripts/backfillInstalacaoRelations.apex`
List<Instalacao__c> installations = [
  SELECT
    Id,
    Projeto__c,
    Projeto__r.Oportunidade__c,
    Projeto__r.Conta__c,
    Oportunidade__c,
    OportunidadeConcluida__c,
    ClienteConta__c,
    ConsultorInstalacao__c
  FROM Instalacao__c
  WHERE Projeto__c != null
];

Set<Id> opportunityIds = new Set<Id>();
Map<Id, Id> installationToPrimaryOpportunityId = new Map<Id, Id>();

for (Instalacao__c inst : installations) {
  Id primaryOpportunityId = inst.Projeto__r != null &&
      inst.Projeto__r.Oportunidade__c != null
    ? inst.Projeto__r.Oportunidade__c
    : (inst.Oportunidade__c != null
      ? inst.Oportunidade__c
      : inst.OportunidadeConcluida__c);

  installationToPrimaryOpportunityId.put(inst.Id, primaryOpportunityId);
  if (primaryOpportunityId != null) {
    opportunityIds.add(primaryOpportunityId);
  }
}

Map<Id, Opportunity> opportunityById = new Map<Id, Opportunity>();
if (!opportunityIds.isEmpty()) {
  opportunityById = new Map<Id, Opportunity>([
    SELECT Id, AccountId, ConsultorOportunidade__c
    FROM Opportunity
    WHERE Id IN :opportunityIds
  ]);
}

List<Instalacao__c> toUpdate = new List<Instalacao__c>();
for (Instalacao__c inst : installations) {
  Id primaryOpportunityId = installationToPrimaryOpportunityId.get(inst.Id);
  Opportunity opp = primaryOpportunityId != null
    ? opportunityById.get(primaryOpportunityId)
    : null;
  Id expectedClientId = inst.Projeto__r != null && inst.Projeto__r.Conta__c != null
    ? inst.Projeto__r.Conta__c
    : (opp != null ? opp.AccountId : null);
  Id expectedConsultorId = opp != null ? opp.ConsultorOportunidade__c : null;

  Instalacao__c updateInst = new Instalacao__c(Id = inst.Id);
  Boolean hasChanges = false;

  if (primaryOpportunityId != null && inst.Oportunidade__c != primaryOpportunityId) {
    updateInst.Oportunidade__c = primaryOpportunityId;
    hasChanges = true;
  }
  if (inst.ClienteConta__c != expectedClientId) {
    updateInst.ClienteConta__c = expectedClientId;
    hasChanges = true;
  }
  if (inst.ConsultorInstalacao__c != expectedConsultorId) {
    updateInst.ConsultorInstalacao__c = expectedConsultorId;
    hasChanges = true;
  }

  if (hasChanges) {
    toUpdate.add(updateInst);
  }
}

if (!toUpdate.isEmpty()) {
  InstalacaoTriggerHandler.disableTrigger();
  try {
    update toUpdate;
  } finally {
    InstalacaoTriggerHandler.enableTrigger();
  }
}

System.debug('Instalações atualizadas no backfill: ' + toUpdate.size());
