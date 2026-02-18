@IsTest
private class ClickSignVisibilityRulesEngineTest {
    private static Opportunity createOpportunity(String name, String stageName, Integer closeInDays) {
        Opportunity opp = new Opportunity(
            Name = name,
            StageName = stageName,
            CloseDate = Date.today().addDays(closeInDays),
            IdVirtualOffice__c = 'vo-' + String.valueOf(System.now().getTime())
        );
        insert opp;
        return opp;
    }

    @IsTest
    static void shouldEvaluateExpressionRuleWithPicklistAndRecordType() {
        Opportunity opp = createOpportunity('Rule Eval Opportunity', 'Prospecting', 10);

        Opportunity insertedOpp = [
            SELECT Id, StageName, RecordTypeId
            FROM Opportunity
            WHERE Id = :opp.Id
            LIMIT 1
        ];

        String ruleJson = JSON.serialize(new Map<String, Object>{
            'version' => 2,
            'mode' => 'expression',
            'logicExpression' => '(1 OR 2) AND 3',
            'conditions' => new List<Object>{
                new Map<String, Object>{
                    'id' => '1',
                    'type' => 'picklist',
                    'field' => 'StageName',
                    'op' => 'IN',
                    'values' => new List<Object>{ 'Prospecting' }
                },
                new Map<String, Object>{
                    'id' => '2',
                    'type' => 'picklist',
                    'field' => 'StageName',
                    'op' => 'IN',
                    'values' => new List<Object>{ 'Qualification' }
                },
                new Map<String, Object>{
                    'id' => '3',
                    'type' => 'recordType',
                    'op' => 'IN',
                    'recordTypeIds' => new List<Object>{ String.valueOf(insertedOpp.RecordTypeId) }
                }
            }
        });

        Boolean initialResult = ClickSignVisibilityRulesEngine.evaluateRules(ruleJson, insertedOpp.Id);
        System.assertEquals(true, initialResult, 'Rule should match Prospecting + record type.');

        insertedOpp.StageName = 'Closed Lost';
        update insertedOpp;

        Boolean updatedResult = ClickSignVisibilityRulesEngine.evaluateRules(ruleJson, insertedOpp.Id);
        System.assertEquals(false, updatedResult, 'Rule should fail when stage no longer matches.');
    }

    @IsTest
    static void shouldValidateExpressionErrors() {
        String invalidRuleJson = JSON.serialize(new Map<String, Object>{
            'version' => 2,
            'mode' => 'expression',
            'logicExpression' => '(1 OR 2',
            'conditions' => new List<Object>{
                new Map<String, Object>{
                    'id' => '1',
                    'type' => 'picklist',
                    'field' => 'StageName',
                    'op' => 'IN',
                    'values' => new List<Object>{ 'Prospecting' }
                }
            }
        });

        List<String> errors = ClickSignVisibilityRulesEngine.validateRules(invalidRuleJson);

        System.assert(!errors.isEmpty(), 'Invalid expression should produce errors.');
    }

    @IsTest
    static void shouldEvaluateLegacyGroupRule() {
        Opportunity opp = createOpportunity('Legacy Rule Opportunity', 'Prospecting', 7);

        String legacyRuleJson = '{"version":1,"logic":"OR","groups":[{"logic":"AND","conditions":[{"type":"picklist","field":"StageName","op":"IN","values":["Prospecting"]}]}]}';

        List<String> validation = ClickSignVisibilityRulesEngine.validateRules(legacyRuleJson);
        Boolean evalResult = ClickSignVisibilityRulesEngine.evaluateRules(legacyRuleJson, opp.Id);

        System.assertEquals(0, validation.size(), 'Legacy rule should validate.');
        System.assertEquals(true, evalResult, 'Legacy rule should still evaluate correctly.');
    }

    @IsTest
    static void shouldEvaluateAllModeAndAnyModeWithoutCustomExpression() {
        Opportunity opp = createOpportunity('Mode Rule Opportunity', 'Prospecting', 5);

        Opportunity insertedOpp = [
            SELECT Id, StageName, RecordTypeId
            FROM Opportunity
            WHERE Id = :opp.Id
            LIMIT 1
        ];

        String allModeRuleJson = JSON.serialize(new Map<String, Object>{
            'version' => 2,
            'mode' => 'expression',
            'logicMode' => 'ALL',
            'conditions' => new List<Object>{
                new Map<String, Object>{
                    'id' => '1',
                    'type' => 'picklist',
                    'field' => 'StageName',
                    'op' => 'EQ',
                    'value' => 'Prospecting'
                },
                new Map<String, Object>{
                    'id' => '2',
                    'type' => 'recordType',
                    'op' => 'EQ',
                    'recordTypeId' => String.valueOf(insertedOpp.RecordTypeId)
                }
            }
        });

        String anyModeRuleJson = JSON.serialize(new Map<String, Object>{
            'version' => 2,
            'mode' => 'expression',
            'logicMode' => 'ANY',
            'conditions' => new List<Object>{
                new Map<String, Object>{
                    'id' => '1',
                    'type' => 'picklist',
                    'field' => 'StageName',
                    'op' => 'EQ',
                    'value' => 'Closed Won'
                },
                new Map<String, Object>{
                    'id' => '2',
                    'type' => 'recordType',
                    'op' => 'EQ',
                    'recordTypeId' => String.valueOf(insertedOpp.RecordTypeId)
                }
            }
        });

        System.assertEquals(true, ClickSignVisibilityRulesEngine.evaluateRules(allModeRuleJson, insertedOpp.Id));
        System.assertEquals(true, ClickSignVisibilityRulesEngine.evaluateRules(anyModeRuleJson, insertedOpp.Id));
    }

    @IsTest
    static void shouldEvaluateNotEqualOperator() {
        Opportunity opp = createOpportunity('Not Equal Rule Opportunity', 'Prospecting', 5);

        String neqRuleJson = JSON.serialize(new Map<String, Object>{
            'version' => 2,
            'mode' => 'expression',
            'logicMode' => 'ALL',
            'conditions' => new List<Object>{
                new Map<String, Object>{
                    'id' => '1',
                    'type' => 'picklist',
                    'field' => 'StageName',
                    'op' => 'NEQ',
                    'value' => 'Closed Won'
                }
            }
        });

        System.assertEquals(true, ClickSignVisibilityRulesEngine.evaluateRules(neqRuleJson, opp.Id));
    }

    @IsTest
    static void shouldReturnTrueWhenRuleHasNoConditions() {
        Opportunity opp = createOpportunity('No Condition Opportunity', 'Prospecting', 5);

        String emptyExpressionRule = '{"version":2,"mode":"expression","logicMode":"ALL","conditions":[]}';
        String emptyLegacyRule = '{"version":1,"logic":"OR","groups":[]}';

        System.assertEquals(true, ClickSignVisibilityRulesEngine.evaluateRules(emptyExpressionRule, opp.Id));
        System.assertEquals(true, ClickSignVisibilityRulesEngine.evaluateRules(emptyLegacyRule, opp.Id));
    }
}