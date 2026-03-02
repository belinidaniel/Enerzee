@IsTest
private class ClickSignVisibilityRuleServiceTest {
  @IsTest
  static void shouldEvaluateSimpleAndRule() {
    String ruleJson = '{"version":1,"logic":"OR","groups":[{"logic":"AND","conditions":[{"type":"picklist","field":"Fase__c","op":"IN","values":["Contrato"]},{"type":"recordType","op":"IN","recordTypeIds":["012000000000001AAA"]}]}]}';
    Map<String, Object> recordMap = new Map<String, Object>{
      'Fase__c' => 'Contrato',
      'RecordTypeId' => '012000000000001AAA'
    };

    Boolean result = ClickSignVisibilityRuleService.evaluate(
      ruleJson,
      recordMap
    );

    System.assertEquals(true, result);
  }

  @IsTest
  static void shouldEvaluatePicklistWithTwoAllowedValues() {
    String ruleJson = '{"version":1,"logic":"OR","groups":[{"logic":"AND","conditions":[{"type":"picklist","field":"Fase__c","op":"IN","values":["Contrato","Assinatura"]}]}]}';
    Map<String, Object> recordMap = new Map<String, Object>{
      'Fase__c' => 'Assinatura'
    };

    Boolean result = ClickSignVisibilityRuleService.evaluate(
      ruleJson,
      recordMap
    );

    System.assertEquals(true, result);
  }

  @IsTest
  static void shouldEvaluateRuleWithTwoOrGroups() {
    String ruleJson = '{"version":1,"logic":"OR","groups":[{"logic":"AND","conditions":[{"type":"picklist","field":"Fase__c","op":"IN","values":["Revisao"]}]},{"logic":"AND","conditions":[{"type":"picklist","field":"Fase__c","op":"IN","values":["Assinatura"]}]}]}';
    Map<String, Object> recordMap = new Map<String, Object>{
      'Fase__c' => 'Assinatura'
    };

    Boolean result = ClickSignVisibilityRuleService.evaluate(
      ruleJson,
      recordMap
    );

    System.assertEquals(true, result);
  }

  @IsTest
  static void shouldReturnFalseForInvalidRuleJson() {
    Map<String, Object> recordMap = new Map<String, Object>{
      'Fase__c' => 'Contrato'
    };

    Test.startTest();
    Boolean result = ClickSignVisibilityRuleService.evaluate(
      '{invalid-json',
      recordMap
    );
    Test.stopTest();

    System.assertEquals(false, result);
  }

  @IsTest
  static void shouldListFieldsRecordTypesAndBuildQuery() {
    List<ClickSignVisibilityRuleService.PicklistFieldOption> picklistFields = ClickSignVisibilityRuleService.listPicklistFields(
      'Opportunity'
    );
    List<ClickSignVisibilityRuleService.RecordTypeOption> recordTypes = ClickSignVisibilityRuleService.listRecordTypes(
      'Opportunity'
    );

    String query = ClickSignVisibilityRuleService.buildRecordQuery(
      'Opportunity',
      new List<String>{ 'StageName', 'RecordTypeId', 'NotAField__c' }
    );

    System.assert(
      !picklistFields.isEmpty(),
      'Picklist fields should be returned for Opportunity.'
    );
    System.assert(
      !recordTypes.isEmpty(),
      'Record types should be returned for Opportunity.'
    );
    System.assert(query.contains('FROM Opportunity'));
    System.assert(query.contains('StageName'));
    System.assert(!query.contains('NotAField__c'));
  }

  @IsTest
  static void shouldCollectFieldsAndHandleInvalidObjects() {
    String ruleJson = '{"version":1,"logic":"OR","groups":[{"logic":"AND","conditions":[{"type":"picklist","field":"StageName","op":"IN","values":["Prospecting"]},{"type":"recordType","op":"IN","recordTypeIds":["012000000000000AAA"]}]}]}';

    Set<String> requiredFields = ClickSignVisibilityRuleService.collectRequiredFields(
      ruleJson
    );
    String invalidObjectQuery = ClickSignVisibilityRuleService.buildRecordQuery(
      'Invalid_Object__c',
      new List<String>{ 'StageName' }
    );
    List<ClickSignVisibilityRuleService.PicklistFieldOption> invalidObjectFields = ClickSignVisibilityRuleService.listPicklistFields(
      'Invalid_Object__c'
    );
    List<ClickSignVisibilityRuleService.RecordTypeOption> invalidObjectRecordTypes = ClickSignVisibilityRuleService.listRecordTypes(
      'Invalid_Object__c'
    );

    System.assert(requiredFields.contains('StageName'));
    System.assert(requiredFields.contains('RecordTypeId'));
    System.assertEquals(null, invalidObjectQuery);
    System.assertEquals(0, invalidObjectFields.size());
    System.assertEquals(0, invalidObjectRecordTypes.size());
  }

  @IsTest
  static void shouldHandleAdditionalEvaluationScenarios() {
    Map<String, Object> recordMap = new Map<String, Object>{
      'StageName' => 'Negotiation/Review',
      'RecordTypeId' => '012000000000000AAA'
    };

    String andRootRule = '{"version":1,"logic":"AND","groups":[{"logic":"AND","conditions":[{"type":"picklist","field":"StageName","op":"IN","values":["Negotiation/Review"]}]},{"logic":"AND","conditions":[{"type":"recordType","op":"IN","recordTypeIds":["012000000000000AAA"]}]}]}';
    String nonMatchingRule = '{"version":1,"logic":"OR","groups":[{"logic":"AND","conditions":[{"type":"picklist","field":"StageName","op":"IN","values":["Closed Won"]}]}]}';
    String unsupportedConditionRule = '{"version":1,"logic":"OR","groups":[{"logic":"AND","conditions":[{"type":"customType","op":"IN","values":["A"]}]}]}';

    System.assertEquals(
      true,
      ClickSignVisibilityRuleService.evaluate(andRootRule, recordMap)
    );
    System.assertEquals(
      false,
      ClickSignVisibilityRuleService.evaluate(nonMatchingRule, recordMap)
    );
    System.assertEquals(
      false,
      ClickSignVisibilityRuleService.evaluate(
        unsupportedConditionRule,
        recordMap
      )
    );
    System.assertEquals(
      true,
      ClickSignVisibilityRuleService.evaluate(null, recordMap)
    );
    System.assertEquals(
      false,
      ClickSignVisibilityRuleService.evaluate(nonMatchingRule, null)
    );
  }
}
