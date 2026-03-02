public with sharing class ViabilityStudyController {
  @AuraEnabled
  public static Map<String, Object> getLocation(Id recordId) {
    ViabilityStudy__c viabilityRecord = [
      SELECT Name, LocalizacaoFixa__Latitude__s, LocalizacaoFixa__Longitude__s
      FROM ViabilityStudy__c
      WHERE Id = :recordId
      LIMIT 1
    ];

    return new Map<String, Object>{
      'Name' => viabilityRecord.Name,
      'Latitude' => viabilityRecord.LocalizacaoFixa__Latitude__s,
      'Longitude' => viabilityRecord.LocalizacaoFixa__Longitude__s
    };
  }
}
