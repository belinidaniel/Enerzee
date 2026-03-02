public with sharing class DataSourceController {
  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getObjectList() {
    List<Map<String, String>> objectList = new List<Map<String, String>>();
    Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
    for (String objectName : schemaMap.keySet()) {
      Map<String, String> objectInfo = new Map<String, String>();
      objectInfo.put('apiName', objectName);
      objectInfo.put(
        'label',
        schemaMap.get(objectName).getDescribe().getLabel()
      );
      objectList.add(objectInfo);
    }
    return objectList;
  }

  @AuraEnabled(cacheable=true)
  public static List<SObject> getRecords(String objectName, String searchTerm) {
    String query;
    if (objectName == 'Case') {
      query = 'SELECT Id, CaseNumber FROM Case';
      if (searchTerm != null && searchTerm != '') {
        query +=
          ' WHERE CaseNumber LIKE \'%' +
          String.escapeSingleQuotes(searchTerm) +
          '%\'';
      }
    } else {
      query = 'SELECT Id, Name FROM ' + objectName;
      if (searchTerm != null && searchTerm != '') {
        query +=
          ' WHERE Name LIKE \'%' +
          String.escapeSingleQuotes(searchTerm) +
          '%\'';
      }
    }
    query += ' LIMIT 50';
    return Database.query(query);
  }

  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getObjectFields(String objectName) {
    Map<String, Schema.SObjectField> fieldsMap = Schema.getGlobalDescribe()
      .get(objectName)
      .getDescribe()
      .fields.getMap();
    List<Map<String, String>> fields = new List<Map<String, String>>();
    for (String fieldName : fieldsMap.keySet()) {
      Map<String, String> fieldInfo = new Map<String, String>();
      fieldInfo.put('apiName', fieldName);
      fieldInfo.put('label', fieldsMap.get(fieldName).getDescribe().getLabel());
      fields.add(fieldInfo);
    }
    return fields;
  }

  @AuraEnabled(cacheable=true)
  public static Map<String, List<Map<String, String>>> getObjectFieldsPage(
    String objectName
  ) {
    Map<String, Schema.SObjectField> fieldsMap = Schema.getGlobalDescribe()
      .get(objectName)
      .getDescribe()
      .fields.getMap();
    Map<String, List<Map<String, String>>> categorizedFields = new Map<String, List<Map<String, String>>>();

    List<Map<String, String>> objectFields = new List<Map<String, String>>();
    List<Map<String, String>> relationshipFields = new List<Map<String, String>>();
    List<Map<String, String>> lookupFields = new List<Map<String, String>>();

    for (String fieldName : fieldsMap.keySet()) {
      Schema.DescribeFieldResult fieldDescribe = fieldsMap.get(fieldName)
        .getDescribe();
      Map<String, String> fieldInfo = new Map<String, String>();
      fieldInfo.put('label', fieldDescribe.getLabel());
      fieldInfo.put('apiName', fieldName);

      if (fieldDescribe.getType() == Schema.DisplayType.REFERENCE) {
        fieldInfo.put(
          'relatedObject',
          fieldDescribe.getReferenceTo()[0].getDescribe().getName()
        );
        relationshipFields.add(fieldInfo);
      } else if (fieldDescribe.getType() == Schema.DisplayType.ID) {
        lookupFields.add(fieldInfo);
      } else {
        objectFields.add(fieldInfo);
      }
    }

    categorizedFields.put('objectFields', objectFields);
    categorizedFields.put('relationshipFields', relationshipFields);
    categorizedFields.put('lookupFields', lookupFields);
    return categorizedFields;
  }

  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getRelationshipFields(
    String objectName,
    String relationshipFieldName
  ) {
    Map<String, Schema.SObjectField> fieldsMap = Schema.getGlobalDescribe()
      .get(objectName)
      .getDescribe()
      .fields.getMap();
    if (!fieldsMap.containsKey(relationshipFieldName)) {
      return new List<Map<String, String>>();
    }
    Schema.DescribeFieldResult describeResult = fieldsMap.get(
        relationshipFieldName
      )
      .getDescribe();
    String relatedObjectName = describeResult.getReferenceTo()[0]
      .getDescribe()
      .getName();

    Map<String, Schema.SObjectField> relatedFieldsMap = Schema.getGlobalDescribe()
      .get(relatedObjectName)
      .getDescribe()
      .fields.getMap();
    List<Map<String, String>> relatedFields = new List<Map<String, String>>();
    for (String fieldName : relatedFieldsMap.keySet()) {
      Map<String, String> fieldInfo = new Map<String, String>();
      fieldInfo.put(
        'label',
        relatedFieldsMap.get(fieldName).getDescribe().getLabel()
      );
      fieldInfo.put('apiName', fieldName);
      relatedFields.add(fieldInfo);
    }
    return relatedFields;
  }

  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getRelatedFields(String objectName) {
    Map<String, Schema.SObjectField> fieldsMap = Schema.getGlobalDescribe()
      .get(objectName)
      .getDescribe()
      .fields.getMap();
    List<Map<String, String>> fields = new List<Map<String, String>>();
    for (String fieldName : fieldsMap.keySet()) {
      Map<String, String> fieldInfo = new Map<String, String>();
      fieldInfo.put('apiName', fieldName);
      fieldInfo.put('label', fieldsMap.get(fieldName).getDescribe().getLabel());
      fields.add(fieldInfo);
    }
    return fields;
  }

  @AuraEnabled
  public static List<Map<String, String>> getContactAndAccountFields(
    String objectName
  ) {
    Map<String, Schema.SObjectField> fieldsMap = Schema.getGlobalDescribe()
      .get(objectName)
      .getDescribe()
      .fields.getMap();
    List<Map<String, String>> contactAndAccountFields = new List<Map<String, String>>();

    for (String fieldName : fieldsMap.keySet()) {
      Schema.DescribeFieldResult fieldDescribe = fieldsMap.get(fieldName)
        .getDescribe();
      if (fieldDescribe.getType() == Schema.DisplayType.REFERENCE) {
        List<Schema.SObjectType> referenceTo = fieldDescribe.getReferenceTo();
        for (Schema.SObjectType refType : referenceTo) {
          String refObjectName = refType.getDescribe().getName();
          if (
            refObjectName == 'Contact' ||
            refObjectName == 'Account' ||
            refObjectName == 'User'
          ) {
            Map<String, String> fieldInfo = new Map<String, String>();
            fieldInfo.put('apiName', fieldName);
            fieldInfo.put('label', fieldDescribe.getLabel());
            fieldInfo.put('relatedObject', refObjectName);
            contactAndAccountFields.add(fieldInfo);
          }
        }
      }
    }
    return contactAndAccountFields;
  }

  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getEmailField(String objectName) {
    Map<String, Schema.SObjectField> fieldsMap = Schema.getGlobalDescribe()
      .get(objectName)
      .getDescribe()
      .fields.getMap();
    List<Map<String, String>> emailFields = new List<Map<String, String>>();

    for (String fieldName : fieldsMap.keySet()) {
      Schema.DescribeFieldResult fieldDescribe = fieldsMap.get(fieldName)
        .getDescribe();
      if (fieldDescribe.getType() == Schema.DisplayType.EMAIL) {
        Map<String, String> fieldInfo = new Map<String, String>();
        fieldInfo.put('apiName', fieldName);
        fieldInfo.put('label', fieldDescribe.getLabel());
        emailFields.add(fieldInfo);
      }
    }
    return emailFields;
  }
}
