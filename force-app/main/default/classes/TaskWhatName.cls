public class TaskWhatName {
  @InvocableMethod(label='Get What Name')
  public static List<String> getWhatName(List<Task> tasks) {
    List<String> whatNames = new List<String>();

    for (Task task : tasks) {
      if (task.WhatId != null) {
        Id accId = task.whatId;

        String whatIdsObjectType = task.whatId.getSObjectType()
          .getDescribe()
          .getName();

        Map<String, List<String>> objectFieldMap = new Map<String, List<String>>{
          'Opportunity' => new List<String>{ 'NumeroProposta__c', 'Name' },
          'Case' => new List<String>{ 'CaseNumber', 'Subject' },
          'Account' => new List<String>{ 'Name' },
          'Consultor__c' => new List<String>{ 'Name' },
          'Integradores__c' => new List<String>{ 'Name' },
          'ViabilityStudy__c' => new List<String>{ 'Name' },
          'Projeto__c' => new List<String>{ 'NumeroProjeto__c', 'Name' }
        };

        List<String> fieldsToQuery = objectFieldMap.containsKey(
            whatIdsObjectType
          )
          ? objectFieldMap.get(whatIdsObjectType)
          : new List<String>{ 'Id' };

        String query =
          'SELECT ' +
          String.join(fieldsToQuery, ', ') +
          ' FROM ' +
          whatIdsObjectType +
          ' WHERE Id =: accId';
        List<SObject> relatedRecords = Database.query(query);

        if (!relatedRecords.isEmpty()) {
          SObject relatedRecord = relatedRecords[0];
          String displayValue = '';

          for (String field : fieldsToQuery) {
            if (relatedRecord.get(field) != null) {
              displayValue +=
                (displayValue != '' ? ' - ' : '') +
                String.valueOf(relatedRecord.get(field));
            }
          }

          whatNames.add(displayValue);
        }
      } else {
        whatNames.add(null);
      }
    }

    return whatNames;
  }
}
