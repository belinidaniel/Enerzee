/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 02-16-2026
 * @last modified by  : Daniel Belini
**/
public with sharing class ClickSignVisibilityRuleService {
    private static final String LOGIC_OR = 'OR';
    private static final String LOGIC_AND = 'AND';
    private static final String OP_IN = 'IN';
    private static final String CONDITION_PICKLIST = 'picklist';
    private static final String CONDITION_RECORD_TYPE = 'recordType';
    public class PicklistFieldOption implements Comparable {
        @AuraEnabled public String label;
        @AuraEnabled public String apiName;

        public PicklistFieldOption(String label, String apiName) {
            this.label = label;
            this.apiName = apiName;
        }

        public Integer compareTo(Object other) {
            PicklistFieldOption value = (PicklistFieldOption) other;
            return String.valueOf(label).toLowerCase().compareTo(String.valueOf(value.label).toLowerCase());
        }
    }

    public class RecordTypeOption implements Comparable {
        @AuraEnabled public String recordTypeId;
        @AuraEnabled public String name;

        public RecordTypeOption(String recordTypeId, String name) {
            this.recordTypeId = recordTypeId;
            this.name = name;
        }

        public Integer compareTo(Object other) {
            RecordTypeOption value = (RecordTypeOption) other;
            return String.valueOf(name).toLowerCase().compareTo(String.valueOf(value.name).toLowerCase());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistFieldOption> listPicklistFields(String sObjectApiName) {
        List<PicklistFieldOption> options = new List<PicklistFieldOption>();
        Schema.SObjectType sObjectType = getSObjectType(sObjectApiName);
        if (sObjectType == null) {
            return options;
        }

        Map<String, Schema.SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();
        for (Schema.SObjectField fieldRef : fieldMap.values()) {
            Schema.DescribeFieldResult describe = fieldRef.getDescribe();
            if (describe.getType() == Schema.DisplayType.PICKLIST) {
                options.add(new PicklistFieldOption(describe.getLabel(), describe.getName()));
            }
        }
        options.sort();
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<RecordTypeOption> listRecordTypes(String sObjectApiName) {
        List<RecordTypeOption> options = new List<RecordTypeOption>();
        Schema.SObjectType sObjectType = getSObjectType(sObjectApiName);
        if (sObjectType == null) {
            return options;
        }

        for (Schema.RecordTypeInfo info : sObjectType.getDescribe().getRecordTypeInfos()) {
            Id recordTypeId = info.getRecordTypeId();
            if (recordTypeId != null) {
                options.add(new RecordTypeOption(String.valueOf(recordTypeId), info.getName()));
            }
        }
        options.sort();
        return options;
    }

    public static Boolean evaluate(String ruleJson, Map<String, Object> recordMap) {
        if (String.isBlank(ruleJson)) {
            return true;
        }
        if (recordMap == null) {
            return false;
        }

        try {
            Map<String, Object> rule = deserializeRule(ruleJson, true);
            if (rule == null) {
                return false;
            }

            List<Object> groups = asObjectList(rule.get('groups'));
            if (groups == null || groups.isEmpty()) {
                return false;
            }

            String logic = normalizeLogic((String) rule.get('logic'), LOGIC_OR);
            if (logic == LOGIC_AND) {
                for (Object groupObj : groups) {
                    if (!evaluateGroup(groupObj, recordMap)) {
                        return false;
                    }
                }
                return true;
            }

            for (Object groupObj : groups) {
                if (evaluateGroup(groupObj, recordMap)) {
                    return true;
                }
            }
            return false;
        } catch (Exception ex) {
            logRuleError('Unexpected error while evaluating visibility rule.', ex, ruleJson);
            return false;
        }
    }

    public static String buildRecordQuery(String sObjectApiName, List<String> fields) {
        Schema.SObjectType sObjectType = getSObjectType(sObjectApiName);
        if (sObjectType == null) {
            return null;
        }

        Map<String, Schema.SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();
        Set<String> selectedFields = new Set<String>{ 'Id' };

        if (fields != null) {
            for (String fieldName : fields) {
                if (!isValidFieldApiName(fieldName) || fieldName == 'Id') {
                    continue;
                }
                if (fieldMap.containsKey(fieldName) || fieldName == 'RecordTypeId') {
                    selectedFields.add(fieldName);
                }
            }
        }

        List<String> fieldList = new List<String>();
        fieldList.addAll(selectedFields);
        fieldList.sort();
        return 'SELECT ' + String.join(fieldList, ', ') + ' FROM ' + sObjectType.getDescribe().getName() + ' WHERE Id = :recordId LIMIT 1';
    }

    public static Set<String> collectRequiredFields(String ruleJson) {
        Set<String> fields = new Set<String>();
        if (String.isBlank(ruleJson)) {
            return fields;
        }

        Map<String, Object> rule = deserializeRule(ruleJson, false);
        if (rule == null) {
            return fields;
        }

        List<Object> groups = asObjectList(rule.get('groups'));
        if (groups == null) {
            return fields;
        }

        for (Object groupObj : groups) {
            Map<String, Object> ruleGroup = asObjectMap(groupObj);
            if (ruleGroup == null) {
                continue;
            }

            List<Object> conditions = asObjectList(ruleGroup.get('conditions'));
            if (conditions == null) {
                continue;
            }

            for (Object conditionObj : conditions) {
                Map<String, Object> condition = asObjectMap(conditionObj);
                if (condition == null) {
                    continue;
                }

                String type = normalizeConditionType((String) condition.get('type'));
                if (type == CONDITION_PICKLIST) {
                    String fieldName = (String) condition.get('field');
                    if (isValidFieldApiName(fieldName)) {
                        fields.add(fieldName);
                    }
                } else if (type == CONDITION_RECORD_TYPE) {
                    fields.add('RecordTypeId');
                }
            }
        }

        return fields;
    }

    private static Boolean evaluateGroup(Object groupObj, Map<String, Object> recordMap) {
        Map<String, Object> ruleGroup = asObjectMap(groupObj);
        if (ruleGroup == null) {
            return false;
        }

        List<Object> conditions = asObjectList(ruleGroup.get('conditions'));
        if (conditions == null || conditions.isEmpty()) {
            return false;
        }

        String logic = normalizeLogic((String) ruleGroup.get('logic'), LOGIC_AND);
        if (logic == LOGIC_OR) {
            for (Object conditionObj : conditions) {
                if (evaluateCondition(conditionObj, recordMap)) {
                    return true;
                }
            }
            return false;
        }

        for (Object conditionObj : conditions) {
            if (!evaluateCondition(conditionObj, recordMap)) {
                return false;
            }
        }
        return true;
    }

    private static Boolean evaluateCondition(Object conditionObj, Map<String, Object> recordMap) {
        Map<String, Object> condition = asObjectMap(conditionObj);
        if (condition == null) {
            return false;
        }

        String op = normalizeText((String) condition.get('op'));
        if (op != OP_IN) {
            return false;
        }

        String type = normalizeConditionType((String) condition.get('type'));
        if (type == CONDITION_PICKLIST) {
            String fieldApiName = (String) condition.get('field');
            if (!isValidFieldApiName(fieldApiName)) {
                return false;
            }

            Set<String> allowedValues = asStringSet(condition.get('values'));
            if (allowedValues.isEmpty()) {
                return false;
            }

            String recordValue = toStringValue(recordMap.get(fieldApiName));
            return !String.isBlank(recordValue) && allowedValues.contains(recordValue);
        }

        if (type == CONDITION_RECORD_TYPE) {
            Set<String> recordTypeIds = asStringSet(condition.get('recordTypeIds'));
            if (recordTypeIds.isEmpty()) {
                return false;
            }

            String recordTypeId = toStringValue(recordMap.get('RecordTypeId'));
            return !String.isBlank(recordTypeId) && recordTypeIds.contains(recordTypeId);
        }

        return false;
    }

    private static Schema.SObjectType getSObjectType(String sObjectApiName) {
        if (String.isBlank(sObjectApiName)) {
            return null;
        }
        return Schema.getGlobalDescribe().get(sObjectApiName);
    }

    private static Map<String, Object> deserializeRule(String ruleJson, Boolean shouldLog) {
        try {
            Object parsedRule = JSON.deserializeUntyped(ruleJson);
            if (parsedRule instanceof Map<String, Object>) {
                return (Map<String, Object>) parsedRule;
            }
            if (shouldLog) {
                System.debug(LoggingLevel.WARN, 'ClickSign visibility rule must be a JSON object.');
            }
            return null;
        } catch (Exception ex) {
            if (shouldLog) {
                logRuleError('Failed to parse visibility rule JSON.', ex, ruleJson);
            }
            return null;
        }
    }

    private static void logRuleError(String message, Exception ex, String ruleJson) {
        System.debug(LoggingLevel.ERROR, message + ' Rule=' + ruleJson + ', Error=' + ex.getMessage());
    }

    private static String normalizeLogic(String logic, String defaultLogic) {
        String normalized = normalizeText(logic);
        if (normalized == LOGIC_AND || normalized == LOGIC_OR) {
            return normalized;
        }
        return defaultLogic;
    }

    private static String normalizeText(String value) {
        return String.isBlank(value) ? null : value.trim().toUpperCase();
    }

    private static String normalizeConditionType(String value) {
        return String.isBlank(value) ? null : value.trim();
    }

    private static Map<String, Object> asObjectMap(Object value) {
        return (value instanceof Map<String, Object>) ? (Map<String, Object>) value : null;
    }

    private static List<Object> asObjectList(Object value) {
        return (value instanceof List<Object>) ? (List<Object>) value : null;
    }

    private static Set<String> asStringSet(Object value) {
        Set<String> result = new Set<String>();
        List<Object> values = asObjectList(value);
        if (values == null) {
            return result;
        }

        for (Object item : values) {
            String text = toStringValue(item);
            if (!String.isBlank(text)) {
                result.add(text);
            }
        }
        return result;
    }

    private static String toStringValue(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private static Boolean isValidFieldApiName(String fieldName) {
        if (String.isBlank(fieldName)) {
            return false;
        }
        return Pattern.matches('^[A-Za-z_][A-Za-z0-9_]*$', fieldName);
    }
}