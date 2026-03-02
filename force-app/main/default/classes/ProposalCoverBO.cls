public with sharing class ProposalCoverBO {
  public static void updateDefaultStatus(
    List<ProposalCover__c> proposalCovers
  ) {
    Map<String, Boolean> isDefaultSetByGroup = new Map<String, Boolean>();

    // Identificar se uma capa padrão foi definida para cada grupo tarifário
    for (ProposalCover__c cover : proposalCovers) {
      if (cover.IsDefault__c == true) {
        isDefaultSetByGroup.put(cover.GrupoTarifario__c, true);
      }
    }

    // Se uma capa padrão foi definida, atualizar as demais para cada grupo tarifário
    if (!isDefaultSetByGroup.isEmpty()) {
      List<ProposalCover__c> otherDefaults = [
        SELECT Id, GrupoTarifario__c
        FROM ProposalCover__c
        WHERE IsDefault__c = TRUE AND Id NOT IN :proposalCovers
      ];
      for (ProposalCover__c otherCover : otherDefaults) {
        if (isDefaultSetByGroup.containsKey(otherCover.GrupoTarifario__c)) {
          otherCover.IsDefault__c = false;
        }
      }
      update otherDefaults;
    }
  }
}
