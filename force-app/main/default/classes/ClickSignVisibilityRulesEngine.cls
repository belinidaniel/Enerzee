/**
 * @description						 : ClickSign visibility rules engine supporting legacy groups and expression mode.
 * @author											 : Daniel Belini
 * @last modified on	 : 02-17-2026
 * @last modified by	 : Codex
 **/
public with sharing class ClickSignVisibilityRulesEngine {
  private static final String LOGIC_AND = 'AND';
  private static final String LOGIC_OR = 'OR';

  private static final String MODE_ALL = 'ALL';
  private static final String MODE_ANY = 'ANY';
  private static final String MODE_CUSTOM = 'CUSTOM';

  private static final String OP_IN = 'IN';
  private static final String OP_EQ = 'EQ';
  private static final String OP_NEQ = 'NEQ';

  private static final String TYPE_PICKLIST = 'picklist';
  private static final String TYPE_RECORD_TYPE = 'recordType';

  @AuraEnabled
  public static List<String> validateRules(String visibilityRulesJson) {
    List<String> errors = new List<String>();

    if (String.isBlank(visibilityRulesJson)) {
      return errors;
    }

    Map<String, Object> rule = parseRule(visibilityRulesJson, errors);
    if (rule == null) {
      return errors;
    }

    if (isExpressionRule(rule)) {
      errors.addAll(validateExpressionRule(rule));
    } else {
      errors.addAll(validateLegacyRule(rule, visibilityRulesJson));
    }

    return errors;
  }

  public static Boolean evaluateRules(String visibilityRulesJson, Id recordId) {
    if (String.isBlank(visibilityRulesJson)) {
      return true;
    }
    if (recordId == null) {
      return false;
    }

    try {
      List<String> errors = new List<String>();
      Map<String, Object> rule = parseRule(visibilityRulesJson, errors);
      if (rule == null || !errors.isEmpty()) {
        return false;
      }

      if (isRuleEffectivelyEmpty(rule)) {
        // No visibility filters configured means button is always visible.
        return true;
      }

      if (isExpressionRule(rule)) {
        errors.addAll(validateExpressionRule(rule));
        if (!errors.isEmpty()) {
          return false;
        }
        return evaluateExpressionRule(rule, recordId);
      }

      errors.addAll(validateLegacyRule(rule, visibilityRulesJson));
      if (!errors.isEmpty()) {
        return false;
      }
      return evaluateLegacyRule(visibilityRulesJson, recordId);
    } catch (Exception ex) {
      System.debug(
        LoggingLevel.ERROR,
        'Error evaluating ClickSign visibility rules: ' + ex.getMessage()
      );
      return false;
    }
  }

  private static Boolean evaluateLegacyRule(String ruleJson, Id recordId) {
    Set<String> requiredFields = ClickSignVisibilityRuleService.collectRequiredFields(
      ruleJson
    );
    Map<String, Object> recordMap = loadRecordData(recordId, requiredFields);
    return ClickSignVisibilityRuleService.evaluate(ruleJson, recordMap);
  }

  private static Boolean evaluateExpressionRule(
    Map<String, Object> rule,
    Id recordId
  ) {
    List<Object> conditionObjects = asObjectList(rule.get('conditions'));
    if (conditionObjects == null || conditionObjects.isEmpty()) {
      return false;
    }

    Set<String> conditionIds = new Set<String>();
    Set<String> requiredFields = new Set<String>();

    for (Object conditionObj : conditionObjects) {
      Map<String, Object> condition = asObjectMap(conditionObj);
      if (condition == null) {
        continue;
      }

      String conditionId = toStringValue(condition.get('id'));
      if (String.isBlank(conditionId)) {
        continue;
      }
      conditionIds.add(conditionId);

      String type = normalizeConditionType(
        toStringValue(condition.get('type'))
      );
      if (type == TYPE_PICKLIST) {
        String fieldApiName = toStringValue(condition.get('field'));
        if (isValidFieldApiName(fieldApiName)) {
          requiredFields.add(fieldApiName);
        }
      } else if (type == TYPE_RECORD_TYPE) {
        requiredFields.add('RecordTypeId');
      }
    }

    Map<String, Object> recordMap = loadRecordData(recordId, requiredFields);
    if (recordMap == null) {
      return false;
    }

    Map<String, Boolean> conditionResults = new Map<String, Boolean>();
    for (Object conditionObj : conditionObjects) {
      Map<String, Object> condition = asObjectMap(conditionObj);
      if (condition == null) {
        continue;
      }

      String conditionId = toStringValue(condition.get('id'));
      if (String.isBlank(conditionId)) {
        continue;
      }

      conditionResults.put(
        conditionId,
        evaluateCondition(condition, recordMap)
      );
    }

    String logicMode = normalizeLogicMode(
      toStringValue(rule.get('logicMode')),
      toStringValue(rule.get('logicExpression'))
    );

    if (logicMode == MODE_ALL) {
      for (Boolean result : conditionResults.values()) {
        if (result != true) {
          return false;
        }
      }
      return !conditionResults.isEmpty();
    }

    if (logicMode == MODE_ANY) {
      for (Boolean result : conditionResults.values()) {
        if (result == true) {
          return true;
        }
      }
      return false;
    }

    String logicExpression = toStringValue(rule.get('logicExpression'));
    List<String> compileErrors = new List<String>();
    Set<String> referencedIds = new Set<String>();
    List<String> rpnExpression = compileExpressionToRpn(
      logicExpression,
      conditionIds,
      compileErrors,
      referencedIds
    );
    if (rpnExpression == null || !compileErrors.isEmpty()) {
      return false;
    }

    return evaluateRpnExpression(rpnExpression, conditionResults);
  }

  private static List<String> validateExpressionRule(Map<String, Object> rule) {
    List<String> errors = new List<String>();

    List<Object> conditionObjects = asObjectList(rule.get('conditions'));
    if (conditionObjects == null || conditionObjects.isEmpty()) {
      errors.add('At least one condition is required.');
      return errors;
    }

    Set<String> conditionIds = new Set<String>();
    for (Object conditionObj : conditionObjects) {
      Map<String, Object> condition = asObjectMap(conditionObj);
      if (condition == null) {
        errors.add('Each condition must be a JSON object.');
        continue;
      }

      String conditionId = toStringValue(condition.get('id'));
      if (String.isBlank(conditionId) || !isNumericToken(conditionId)) {
        errors.add('Condition id must be numeric.');
        continue;
      }

      if (conditionIds.contains(conditionId)) {
        errors.add('Condition id duplicated: ' + conditionId);
        continue;
      }
      conditionIds.add(conditionId);

      String type = normalizeConditionType(
        toStringValue(condition.get('type'))
      );
      if (String.isBlank(type)) {
        errors.add('Unsupported condition type for id ' + conditionId + '.');
        continue;
      }

      String op = normalizeConditionOperator(
        toStringValue(condition.get('op'))
      );
      if (String.isBlank(op)) {
        op = inferDefaultOperator(condition);
      }

      if (String.isBlank(op)) {
        errors.add('Unsupported operator for condition ' + conditionId + '.');
        continue;
      }

      if (type == TYPE_PICKLIST) {
        String fieldApiName = toStringValue(condition.get('field'));
        if (!isValidFieldApiName(fieldApiName)) {
          errors.add(
            'Invalid picklist field on condition ' + conditionId + '.'
          );
        }

        if (op == OP_IN) {
          if (
            asStringSetWithSingle(
                condition.get('values'),
                condition.get('value')
              )
              .isEmpty()
          ) {
            errors.add(
              'Picklist condition ' +
                conditionId +
                ' must contain at least one value.'
            );
          }
        } else {
          if (
            String.isBlank(
              toSingleString(condition.get('value'), condition.get('values'))
            )
          ) {
            errors.add(
              'Picklist condition ' + conditionId + ' must contain a value.'
            );
          }
        }
      }

      if (type == TYPE_RECORD_TYPE) {
        if (op == OP_IN) {
          if (
            asStringSetWithSingle(
                condition.get('recordTypeIds'),
                condition.get('recordTypeId')
              )
              .isEmpty()
          ) {
            errors.add(
              'RecordType condition ' +
                conditionId +
                ' must contain at least one record type id.'
            );
          }
        } else {
          if (
            String.isBlank(
              toSingleString(
                condition.get('recordTypeId'),
                condition.get('recordTypeIds')
              )
            )
          ) {
            errors.add(
              'RecordType condition ' +
                conditionId +
                ' must contain a record type id.'
            );
          }
        }
      }
    }

    if (!errors.isEmpty()) {
      return errors;
    }

    String logicMode = normalizeLogicMode(
      toStringValue(rule.get('logicMode')),
      toStringValue(rule.get('logicExpression'))
    );

    if (logicMode == MODE_CUSTOM) {
      String logicExpression = toStringValue(rule.get('logicExpression'));
      if (String.isBlank(logicExpression)) {
        errors.add('logicExpression is required when logicMode is CUSTOM.');
        return errors;
      }

      Set<String> referencedIds = new Set<String>();
      List<String> syntaxErrors = new List<String>();
      List<String> rpnExpression = compileExpressionToRpn(
        logicExpression,
        conditionIds,
        syntaxErrors,
        referencedIds
      );

      if (rpnExpression == null || !syntaxErrors.isEmpty()) {
        errors.addAll(syntaxErrors);
        return errors;
      }

      if (referencedIds.isEmpty()) {
        errors.add('logicExpression must reference at least one condition id.');
      }
    }

    return errors;
  }

  private static List<String> validateLegacyRule(
    Map<String, Object> rule,
    String ruleJson
  ) {
    List<String> errors = new List<String>();

    List<Object> groups = asObjectList(rule.get('groups'));
    if (groups == null || groups.isEmpty()) {
      errors.add('Legacy rule must include at least one group.');
      return errors;
    }

    Set<String> requiredFields = ClickSignVisibilityRuleService.collectRequiredFields(
      ruleJson
    );
    if (requiredFields.isEmpty()) {
      errors.add('Legacy rule must include at least one valid condition.');
    }

    return errors;
  }

  private static Boolean evaluateCondition(
    Map<String, Object> condition,
    Map<String, Object> recordMap
  ) {
    if (condition == null || recordMap == null) {
      return false;
    }

    String type = normalizeConditionType(toStringValue(condition.get('type')));
    String op = normalizeConditionOperator(toStringValue(condition.get('op')));
    if (String.isBlank(op)) {
      op = inferDefaultOperator(condition);
    }
    if (String.isBlank(op)) {
      return false;
    }

    if (type == TYPE_PICKLIST) {
      String fieldApiName = toStringValue(condition.get('field'));
      if (!isValidFieldApiName(fieldApiName)) {
        return false;
      }

      String recordValue = toStringValue(recordMap.get(fieldApiName));

      if (op == OP_IN) {
        Set<String> allowedValues = asStringSetWithSingle(
          condition.get('values'),
          condition.get('value')
        );
        return !String.isBlank(recordValue) &&
          allowedValues.contains(recordValue);
      }

      String conditionValue = toSingleString(
        condition.get('value'),
        condition.get('values')
      );
      if (String.isBlank(conditionValue)) {
        return false;
      }

      if (op == OP_EQ) {
        return !String.isBlank(recordValue) && recordValue == conditionValue;
      }

      if (op == OP_NEQ) {
        return String.isBlank(recordValue) || recordValue != conditionValue;
      }

      return false;
    }

    if (type == TYPE_RECORD_TYPE) {
      String recordTypeId = toStringValue(recordMap.get('RecordTypeId'));

      if (op == OP_IN) {
        Set<String> recordTypeIds = asStringSetWithSingle(
          condition.get('recordTypeIds'),
          condition.get('recordTypeId')
        );
        return !String.isBlank(recordTypeId) &&
          recordTypeIds.contains(recordTypeId);
      }

      String conditionRecordTypeId = toSingleString(
        condition.get('recordTypeId'),
        condition.get('recordTypeIds')
      );
      if (String.isBlank(conditionRecordTypeId)) {
        return false;
      }

      if (op == OP_EQ) {
        return !String.isBlank(recordTypeId) &&
          recordTypeId == conditionRecordTypeId;
      }

      if (op == OP_NEQ) {
        return String.isBlank(recordTypeId) ||
          recordTypeId != conditionRecordTypeId;
      }

      return false;
    }

    return false;
  }

  private static Map<String, Object> loadRecordData(
    Id recordId,
    Set<String> fields
  ) {
    if (recordId == null) {
      return null;
    }

    Set<String> requiredFields = new Set<String>();
    if (fields != null) {
      requiredFields.addAll(fields);
    }

    String objectApiName = recordId.getSObjectType().getDescribe().getName();
    String query = ClickSignVisibilityRuleService.buildRecordQuery(
      objectApiName,
      new List<String>(requiredFields)
    );
    if (String.isBlank(query)) {
      return null;
    }

    SObject recordData = Database.query(query);
    if (recordData == null) {
      return null;
    }

    return recordData.getPopulatedFieldsAsMap();
  }

  private static List<String> compileExpressionToRpn(
    String logicExpression,
    Set<String> validConditionIds,
    List<String> errors,
    Set<String> referencedIds
  ) {
    List<String> tokens = tokenizeExpression(logicExpression);
    if (tokens.isEmpty()) {
      errors.add('logicExpression cannot be empty.');
      return null;
    }

    List<String> output = new List<String>();
    List<String> operatorStack = new List<String>();

    Integer openParentheses = 0;
    Boolean expectedOperand = true;

    for (String token : tokens) {
      if (expectedOperand) {
        if (token == '(') {
          operatorStack.add(token);
          openParentheses++;
          continue;
        }

        if (!isNumericToken(token)) {
          errors.add('Expected condition id but found: ' + token);
          return null;
        }

        if (validConditionIds != null && !validConditionIds.contains(token)) {
          errors.add(
            'logicExpression references unknown condition id: ' + token
          );
          return null;
        }

        output.add(token);
        if (referencedIds != null) {
          referencedIds.add(token);
        }
        expectedOperand = false;
        continue;
      }

      if (token == ')') {
        openParentheses--;
        if (openParentheses < 0) {
          errors.add('Parentheses are not balanced in logicExpression.');
          return null;
        }

        Boolean foundOpen = false;
        while (!operatorStack.isEmpty()) {
          String top = operatorStack.remove(operatorStack.size() - 1);
          if (top == '(') {
            foundOpen = true;
            break;
          }
          output.add(top);
        }

        if (!foundOpen) {
          errors.add('Parentheses are not balanced in logicExpression.');
          return null;
        }
        continue;
      }

      if (token != LOGIC_AND && token != LOGIC_OR) {
        errors.add('Expected logical operator but found: ' + token);
        return null;
      }

      while (!operatorStack.isEmpty()) {
        String topOperator = operatorStack.get(operatorStack.size() - 1);
        if (topOperator == '(') {
          break;
        }
        if (operatorPrecedence(topOperator) < operatorPrecedence(token)) {
          break;
        }
        output.add(operatorStack.remove(operatorStack.size() - 1));
      }

      operatorStack.add(token);
      expectedOperand = true;
    }

    if (expectedOperand) {
      errors.add('logicExpression cannot end with a logical operator.');
      return null;
    }

    if (openParentheses != 0) {
      errors.add('Parentheses are not balanced in logicExpression.');
      return null;
    }

    while (!operatorStack.isEmpty()) {
      String operatorToken = operatorStack.remove(operatorStack.size() - 1);
      if (operatorToken == '(') {
        errors.add('Parentheses are not balanced in logicExpression.');
        return null;
      }
      output.add(operatorToken);
    }

    return output;
  }

  private static Boolean evaluateRpnExpression(
    List<String> rpnExpression,
    Map<String, Boolean> conditionResults
  ) {
    if (rpnExpression == null || rpnExpression.isEmpty()) {
      return false;
    }

    List<Boolean> stack = new List<Boolean>();

    for (String token : rpnExpression) {
      if (isNumericToken(token)) {
        stack.add(
          conditionResults != null && conditionResults.get(token) == true
        );
        continue;
      }

      if (stack.size() < 2) {
        return false;
      }

      Boolean rightOperand = stack.remove(stack.size() - 1);
      Boolean leftOperand = stack.remove(stack.size() - 1);

      if (token == LOGIC_AND) {
        stack.add(leftOperand && rightOperand);
      } else if (token == LOGIC_OR) {
        stack.add(leftOperand || rightOperand);
      } else {
        return false;
      }
    }

    return stack.size() == 1 && stack[0] == true;
  }

  private static Integer operatorPrecedence(String operatorToken) {
    if (operatorToken == LOGIC_AND) {
      return 2;
    }
    if (operatorToken == LOGIC_OR) {
      return 1;
    }
    return 0;
  }

  private static List<String> tokenizeExpression(String logicExpression) {
    if (String.isBlank(logicExpression)) {
      return new List<String>();
    }

    String normalized = logicExpression
      .replace('&&', ' ' + LOGIC_AND + ' ')
      .replace('||', ' ' + LOGIC_OR + ' ')
      .replace('(', ' ( ')
      .replace(')', ' ) ');

    List<String> tokens = new List<String>();
    for (String token : normalized.split('\\s+')) {
      if (String.isBlank(token)) {
        continue;
      }

      String normalizedLogical = normalizeLogicalToken(token);
      tokens.add(normalizedLogical != null ? normalizedLogical : token);
    }

    return tokens;
  }

  private static Boolean isExpressionRule(Map<String, Object> rule) {
    if (rule == null) {
      return false;
    }

    return rule.containsKey('conditions') ||
      rule.containsKey('logicExpression') ||
      rule.containsKey('logicMode') ||
      String.valueOf(rule.get('mode')) == 'expression';
  }

  private static Boolean isRuleEffectivelyEmpty(Map<String, Object> rule) {
    if (rule == null) {
      return true;
    }

    if (isExpressionRule(rule)) {
      List<Object> conditions = asObjectList(rule.get('conditions'));
      return conditions == null || conditions.isEmpty();
    }

    List<Object> groups = asObjectList(rule.get('groups'));
    return groups == null || groups.isEmpty();
  }

  private static Map<String, Object> parseRule(
    String jsonRule,
    List<String> errors
  ) {
    try {
      Object parsed = JSON.deserializeUntyped(jsonRule);
      if (parsed instanceof Map<String, Object>) {
        return (Map<String, Object>) parsed;
      }

      errors.add('Visibility rules JSON must be an object.');
      return null;
    } catch (Exception ex) {
      errors.add('Invalid visibility rules JSON: ' + ex.getMessage());
      return null;
    }
  }

  private static String normalizeConditionType(String typeValue) {
    if (String.isBlank(typeValue)) {
      return null;
    }

    String normalized = typeValue.trim();
    if (normalized.equalsIgnoreCase(TYPE_PICKLIST)) {
      return TYPE_PICKLIST;
    }
    if (normalized.equalsIgnoreCase(TYPE_RECORD_TYPE)) {
      return TYPE_RECORD_TYPE;
    }

    return null;
  }

  private static String normalizeLogicMode(
    String logicMode,
    String logicExpression
  ) {
    if (!String.isBlank(logicMode)) {
      String normalized = logicMode.trim().toUpperCase();
      if (
        normalized == MODE_ALL ||
        normalized == MODE_ANY ||
        normalized == MODE_CUSTOM
      ) {
        return normalized;
      }
    }

    return String.isBlank(logicExpression) ? MODE_ALL : MODE_CUSTOM;
  }

  private static String normalizeConditionOperator(String operatorToken) {
    if (String.isBlank(operatorToken)) {
      return null;
    }

    String normalized = operatorToken.trim().toUpperCase();

    if (normalized == 'EQUAL' || normalized == 'EQUALS' || normalized == '=') {
      return OP_EQ;
    }
    if (
      normalized == 'NOT_EQUAL' ||
      normalized == 'NOT_EQUALS' ||
      normalized == '!=' ||
      normalized == '<>'
    ) {
      return OP_NEQ;
    }
    if (normalized == OP_EQ || normalized == OP_NEQ || normalized == OP_IN) {
      return normalized;
    }

    return null;
  }

  private static String inferDefaultOperator(Map<String, Object> condition) {
    if (condition == null) {
      return null;
    }

    if (
      condition.containsKey('values') || condition.containsKey('recordTypeIds')
    ) {
      return OP_IN;
    }

    return OP_EQ;
  }

  private static String normalizeLogicalToken(String token) {
    if (String.isBlank(token)) {
      return null;
    }

    String normalized = token.trim().toUpperCase();
    if (normalized == LOGIC_AND || normalized == LOGIC_OR) {
      return normalized;
    }

    return null;
  }

  private static Map<String, Object> asObjectMap(Object value) {
    return (value instanceof Map<String, Object>)
      ? (Map<String, Object>) value
      : null;
  }

  private static List<Object> asObjectList(Object value) {
    return (value instanceof List<Object>) ? (List<Object>) value : null;
  }

  private static Set<String> asStringSet(Object value) {
    Set<String> output = new Set<String>();
    List<Object> listValues = asObjectList(value);
    if (listValues == null) {
      return output;
    }

    for (Object listValue : listValues) {
      String textValue = toStringValue(listValue);
      if (!String.isBlank(textValue)) {
        output.add(textValue);
      }
    }

    return output;
  }

  private static Set<String> asStringSetWithSingle(
    Object listValue,
    Object singleValue
  ) {
    Set<String> values = asStringSet(listValue);
    if (!values.isEmpty()) {
      return values;
    }

    Set<String> output = new Set<String>();
    String single = toStringValue(singleValue);
    if (!String.isBlank(single)) {
      output.add(single);
    }
    return output;
  }

  private static String toSingleString(Object singleValue, Object listValue) {
    String value = toStringValue(singleValue);
    if (!String.isBlank(value)) {
      return value;
    }

    List<Object> values = asObjectList(listValue);
    if (values == null || values.isEmpty()) {
      return null;
    }

    return toStringValue(values[0]);
  }

  private static String toStringValue(Object value) {
    return value == null ? null : String.valueOf(value);
  }

  private static Boolean isValidFieldApiName(String fieldApiName) {
    if (String.isBlank(fieldApiName)) {
      return false;
    }

    return Pattern.matches('^[A-Za-z_][A-Za-z0-9_]*$', fieldApiName);
  }

  private static Boolean isNumericToken(String token) {
    return !String.isBlank(token) && Pattern.matches('^\\d+$', token);
  }
}
