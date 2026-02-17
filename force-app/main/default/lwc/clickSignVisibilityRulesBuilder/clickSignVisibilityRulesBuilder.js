import { api, LightningElement } from 'lwc';
import LANG from '@salesforce/i18n/lang';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPicklistFields from '@salesforce/apex/ClickSignTemplateController.getPicklistFields';
import getPicklistValues from '@salesforce/apex/ClickSignTemplateController.getPicklistValues';
import getRecordTypes from '@salesforce/apex/ClickSignTemplateController.getRecordTypes';
import saveVisibilityRules from '@salesforce/apex/ClickSignTemplateController.saveVisibilityRules';

const CONDITION_TYPE_PICKLIST = 'picklist';
const CONDITION_TYPE_RECORD_TYPE = 'recordType';

const OPERATOR_EQ = 'EQ';
const OPERATOR_NEQ = 'NEQ';
const OPERATOR_IN = 'IN';

const LOGIC_MODE_ALL = 'ALL';
const LOGIC_MODE_ANY = 'ANY';
const LOGIC_MODE_CUSTOM = 'CUSTOM';

const UI_TEXT = {
    pt: {
        titleVisibilityRules: 'Regras de Visibilidade',
        sourceObjectWarning: 'Selecione primeiro o objeto do template para configurar regras.',
        filtersSectionTitle: 'Filtros',
        noFilters: 'Nenhum filtro adicionado.',
        addFilter: '+ Adicionar filtro',
        remove: 'Remover',
        spinnerLoading: 'Carregando metadados',
        filterTypeLabel: 'Tipo de filtro',
        fieldLabel: 'Campo',
        operatorLabel: 'Operador',
        valueLabel: 'Valor',
        recordTypeValueLabel: 'Valor (Tipo de Registro)',
        cancel: 'Cancelar',
        done: 'Concluir',
        showComponentWhen: 'Mostrar componente quando',
        allFiltersTrue: 'Todos os filtros são verdadeiros',
        anyFiltersTrue: 'Qualquer filtro é verdadeiro',
        customLogicMet: 'A lógica dos filtros é atendida',
        filterLogicLabel: 'Lógica dos filtros',
        filterLogicPlaceholder: 'Ex.: (1 OR 2) AND 3',
        defaultLogicButton: 'Gerar lógica OR padrão',
        jsonPreviewTitle: 'JSON (pré-visualização)',
        saveRules: 'Salvar regras',
        saveSuccess: 'Regras de visibilidade salvas com sucesso!',
        saveSuccessTitle: 'Sucesso',
        invalidRuleTitle: 'Regra inválida',
        warningTitle: 'Aviso',
        recordFieldPicklist: 'Campo de Registro (Picklist)',
        recordType: 'Tipo de Registro',
        operatorEqual: 'Igual',
        operatorNotEqual: 'Diferente de',
        operatorIn: 'Em',
        recordPrefix: 'Registro > ',
        templateMissing: 'Template não identificado.',
        addAtLeastOneFilter: 'Adicione pelo menos um filtro.',
        uniqueIds: 'Os IDs dos filtros precisam ser únicos.',
        logicRequired: 'Informe a lógica usando os números dos filtros.',
        tokenInvalid: 'Token inválido na posição {0}: {1}',
        filterNotExists: 'O filtro {0} não existe.',
        expressionEndsWithOperator: 'A expressão não pode terminar com operador.',
        invalidParentheses: 'Parênteses inválidos na lógica.',
        unbalancedParentheses: 'Parênteses não balanceados na lógica.',
        logicMustReferenceFilter: 'A lógica deve referenciar pelo menos um filtro.',
        loadRulesWarning: 'Não foi possível carregar as regras já salvas.',
        unexpectedError: 'Erro inesperado.'
    },
    en: {
        titleVisibilityRules: 'Regras de Visibilidade',
        sourceObjectWarning: 'Select the template object first to configure rules.',
        filtersSectionTitle: 'Filters',
        noFilters: 'No filters added.',
        addFilter: '+ Add Filter',
        remove: 'Remove',
        spinnerLoading: 'Loading metadata',
        filterTypeLabel: 'Filter Type',
        fieldLabel: 'Field',
        operatorLabel: 'Operator',
        valueLabel: 'Value',
        recordTypeValueLabel: 'Value (Record Type)',
        cancel: 'Cancel',
        done: 'Done',
        showComponentWhen: 'Show component when',
        allFiltersTrue: 'All filters are true',
        anyFiltersTrue: 'Any filters are true',
        customLogicMet: 'The filter logic is met',
        filterLogicLabel: 'Filter logic',
        filterLogicPlaceholder: 'Ex.: (1 OR 2) AND 3',
        defaultLogicButton: 'Generate default OR logic',
        jsonPreviewTitle: 'JSON (preview)',
        saveRules: 'Save rules',
        saveSuccess: 'Visibility rules saved successfully!',
        saveSuccessTitle: 'Success',
        invalidRuleTitle: 'Invalid rule',
        warningTitle: 'Warning',
        recordFieldPicklist: 'Record Field (Picklist)',
        recordType: 'Record Type',
        operatorEqual: 'Equal',
        operatorNotEqual: 'Not Equal',
        operatorIn: 'In',
        recordPrefix: 'Record > ',
        templateMissing: 'Template not identified.',
        addAtLeastOneFilter: 'Add at least one filter.',
        uniqueIds: 'Filter IDs must be unique.',
        logicRequired: 'Provide logic using the filter numbers.',
        tokenInvalid: 'Invalid token at position {0}: {1}',
        filterNotExists: 'Filter {0} does not exist.',
        expressionEndsWithOperator: 'Expression cannot end with an operator.',
        invalidParentheses: 'Invalid parentheses in logic.',
        unbalancedParentheses: 'Unbalanced parentheses in logic.',
        logicMustReferenceFilter: 'Logic must reference at least one filter.',
        loadRulesWarning: 'Could not load saved rules.',
        unexpectedError: 'Unexpected error.'
    }
};

export default class ClickSignVisibilityRulesBuilder extends LightningElement {
    _sourceObjectApiName;
    _initialRulesJson;

    @api templateId;

    labels = UI_TEXT.en;

    isLoadingMetadata = false;
    isLoadingPicklistValues = false;
    isSaving = false;

    picklistFieldOptions = [];
    picklistValueOptions = [];
    recordTypeOptions = [];

    isAddingFilter = false;
    selectedConditionType = CONDITION_TYPE_PICKLIST;
    selectedPicklistField = '';
    selectedOperator = OPERATOR_EQ;
    selectedPicklistValue = '';
    selectedRecordTypeId = '';

    conditions = [];
    logicMode = LOGIC_MODE_ALL;
    logicExpression = '';

    saveMessage = '';
    saveMessageVariant = '';

    connectedCallback() {
        this.labels = this.resolveLabels();
    }

    @api
    get sourceObjectApiName() {
        return this._sourceObjectApiName;
    }

    set sourceObjectApiName(value) {
        const nextValue = value || '';
        if (nextValue === this._sourceObjectApiName) {
            return;
        }

        this._sourceObjectApiName = nextValue;
        this.loadMetadata();
    }

    @api
    get initialRulesJson() {
        return this._initialRulesJson;
    }

    set initialRulesJson(value) {
        if (value === this._initialRulesJson) {
            return;
        }

        this._initialRulesJson = value || '';
        this.hydrateFromJson(this._initialRulesJson);
    }

    get hasSourceObject() {
        return !!this.sourceObjectApiName;
    }

    get hasConditions() {
        return this.conditions.length > 0;
    }

    get showCustomLogicInput() {
        return this.logicMode === LOGIC_MODE_CUSTOM;
    }

    get hasSaveMessage() {
        return !!this.saveMessage;
    }

    get saveMessageClass() {
        if (this.saveMessageVariant === 'success') {
            return 'save-message save-message_success';
        }
        if (this.saveMessageVariant === 'error') {
            return 'save-message save-message_error';
        }
        return 'save-message save-message_info';
    }

    get conditionTypeOptions() {
        return [
            { label: this.labels.recordFieldPicklist, value: CONDITION_TYPE_PICKLIST },
            { label: this.labels.recordType, value: CONDITION_TYPE_RECORD_TYPE }
        ];
    }

    get operatorOptions() {
        return [
            { label: this.labels.operatorEqual, value: OPERATOR_EQ },
            { label: this.labels.operatorNotEqual, value: OPERATOR_NEQ }
        ];
    }

    get logicModeOptions() {
        return [
            { label: this.labels.allFiltersTrue, value: LOGIC_MODE_ALL },
            { label: this.labels.anyFiltersTrue, value: LOGIC_MODE_ANY },
            { label: this.labels.customLogicMet, value: LOGIC_MODE_CUSTOM }
        ];
    }

    get isPicklistConditionSelected() {
        return this.selectedConditionType === CONDITION_TYPE_PICKLIST;
    }

    get isRecordTypeConditionSelected() {
        return this.selectedConditionType === CONDITION_TYPE_RECORD_TYPE;
    }

    get disableStartAddFilter() {
        return !this.hasSourceObject || this.isLoadingMetadata;
    }

    get disableAddCondition() {
        if (!this.hasSourceObject || this.isLoadingMetadata || this.isLoadingPicklistValues) {
            return true;
        }

        if (!this.selectedOperator) {
            return true;
        }

        if (this.isPicklistConditionSelected) {
            return !this.selectedPicklistField || !this.selectedPicklistValue;
        }

        return !this.selectedRecordTypeId;
    }

    get disableSave() {
        if (this.isSaving || !this.templateId || !this.hasConditions) {
            return true;
        }

        if (this.logicMode === LOGIC_MODE_CUSTOM) {
            return !this.logicExpression.trim();
        }

        return false;
    }

    get disableUseDefaultLogic() {
        return !this.hasConditions || this.logicMode !== LOGIC_MODE_CUSTOM;
    }

    get rulesPreview() {
        if (!this.hasConditions) {
            return '';
        }

        return JSON.stringify(this.buildRulesPayload(), null, 2);
    }

    get conditionsView() {
        return this.conditions
            .slice()
            .sort((left, right) => Number.parseInt(left.id, 10) - Number.parseInt(right.id, 10))
            .map((condition) => {
                return {
                    ...condition,
                    summary: this.buildConditionSummary(condition)
                };
            });
    }

    resolveLabels() {
        const language = (LANG || '').toLowerCase();
        return language.startsWith('pt') ? UI_TEXT.pt : UI_TEXT.en;
    }

    async loadMetadata() {
        if (!this.hasSourceObject) {
            this.picklistFieldOptions = [];
            this.picklistValueOptions = [];
            this.recordTypeOptions = [];
            return;
        }

        this.isLoadingMetadata = true;

        try {
            const [picklistFields, recordTypes] = await Promise.all([
                getPicklistFields({ objectApiName: this.sourceObjectApiName }),
                getRecordTypes({ objectApiName: this.sourceObjectApiName })
            ]);

            this.picklistFieldOptions = (picklistFields || []).map((field) => {
                return {
                    label: `${field.label} (${field.apiName})`,
                    value: field.apiName,
                    shortLabel: field.label
                };
            });

            this.recordTypeOptions = (recordTypes || []).map((recordType) => {
                return {
                    label: recordType.name,
                    value: recordType.id
                };
            });

            if (!this.selectedPicklistField && this.picklistFieldOptions.length > 0) {
                this.selectedPicklistField = this.picklistFieldOptions[0].value;
                await this.loadPicklistValues(this.selectedPicklistField);
            }

            this.hydrateConditionDisplayValues();
        } catch (error) {
            this.showToast(this.labels.warningTitle, this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoadingMetadata = false;
        }
    }

    async loadPicklistValues(fieldApiName) {
        if (!fieldApiName || !this.hasSourceObject) {
            this.picklistValueOptions = [];
            this.selectedPicklistValue = '';
            return;
        }

        this.isLoadingPicklistValues = true;

        try {
            const values = await getPicklistValues({
                objectApiName: this.sourceObjectApiName,
                fieldApiName
            });

            this.picklistValueOptions = (values || []).map((value) => {
                return {
                    label: value,
                    value
                };
            });

            const stillExists = this.picklistValueOptions.some((option) => option.value === this.selectedPicklistValue);
            if (!stillExists) {
                this.selectedPicklistValue = '';
            }
        } catch (error) {
            this.picklistValueOptions = [];
            this.selectedPicklistValue = '';
            this.showToast(this.labels.warningTitle, this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoadingPicklistValues = false;
        }
    }

    handleStartAddFilter() {
        this.isAddingFilter = true;
    }

    handleCancelAddFilter() {
        this.isAddingFilter = false;
        this.resetCurrentFilterForm();
    }

    handleConditionTypeChange(event) {
        this.selectedConditionType = event.detail.value;
        this.selectedOperator = OPERATOR_EQ;
        this.selectedPicklistValue = '';
        this.selectedRecordTypeId = '';
    }

    async handlePicklistFieldChange(event) {
        this.selectedPicklistField = event.detail.value;
        this.selectedPicklistValue = '';
        await this.loadPicklistValues(this.selectedPicklistField);
    }

    handleOperatorChange(event) {
        this.selectedOperator = event.detail.value;
    }

    handlePicklistValueChange(event) {
        this.selectedPicklistValue = event.detail.value;
    }

    handleRecordTypeValueChange(event) {
        this.selectedRecordTypeId = event.detail.value;
    }

    handleLogicModeChange(event) {
        this.logicMode = event.detail.value;
    }

    handleLogicExpressionChange(event) {
        this.logicExpression = event.detail.value || '';
    }

    handleUseDefaultLogic() {
        this.logicExpression = this.conditions.map((condition) => condition.id).join(' OR ');
    }

    handleRemoveCondition(event) {
        const conditionId = event.currentTarget.dataset.id;
        this.conditions = this.conditions.filter((condition) => condition.id !== conditionId);

        if (!this.hasConditions) {
            this.logicExpression = '';
            this.logicMode = LOGIC_MODE_ALL;
        }
    }

    async handleAddCondition() {
        if (this.disableAddCondition) {
            return;
        }

        const conditionId = this.nextConditionId;

        if (this.isPicklistConditionSelected) {
            const fieldOption = this.picklistFieldOptions.find((option) => option.value === this.selectedPicklistField);

            this.conditions = [
                ...this.conditions,
                {
                    id: conditionId,
                    type: CONDITION_TYPE_PICKLIST,
                    field: this.selectedPicklistField,
                    fieldLabel: fieldOption ? fieldOption.shortLabel : this.selectedPicklistField,
                    op: this.selectedOperator,
                    value: this.selectedPicklistValue
                }
            ];
        } else {
            const selectedRecordType = this.recordTypeOptions.find((option) => option.value === this.selectedRecordTypeId);

            this.conditions = [
                ...this.conditions,
                {
                    id: conditionId,
                    type: CONDITION_TYPE_RECORD_TYPE,
                    op: this.selectedOperator,
                    recordTypeId: this.selectedRecordTypeId,
                    recordTypeName: selectedRecordType ? selectedRecordType.label : this.selectedRecordTypeId
                }
            ];
        }

        this.isAddingFilter = false;
        this.resetCurrentFilterForm();
    }

    async handleSaveRules() {
        this.clearSaveMessage();

        const localErrors = this.validateLocalState();
        if (localErrors.length > 0) {
            this.setSaveMessage(localErrors[0], 'error');
            this.showToast(this.labels.invalidRuleTitle, localErrors[0], 'error');
            return;
        }

        this.isSaving = true;

        try {
            const payload = this.buildRulesPayload();
            const payloadJson = JSON.stringify(payload);

            await saveVisibilityRules({
                templateId: this.templateId,
                visibilityRulesJson: payloadJson
            });

            this._initialRulesJson = payloadJson;
            this.setSaveMessage(this.labels.saveSuccess, 'success');
            this.showToast(this.labels.saveSuccessTitle, this.labels.saveSuccess, 'success');
            this.notifyParent(this.labels.saveSuccessTitle, this.labels.saveSuccess, 'success');
        } catch (error) {
            const message = this.extractErrorMessage(error);
            this.setSaveMessage(message, 'error');
            this.showToast(this.labels.warningTitle, message, 'error');
        } finally {
            this.isSaving = false;
        }
    }

    hydrateFromJson(rawJson) {
        if (!rawJson) {
            this.conditions = [];
            this.logicMode = LOGIC_MODE_ALL;
            this.logicExpression = '';
            return;
        }

        try {
            const parsed = JSON.parse(rawJson);
            const normalized = this.normalizeExistingRules(parsed);
            this.conditions = normalized.conditions;
            this.logicMode = normalized.logicMode;
            this.logicExpression = normalized.logicExpression;
            this.hydrateConditionDisplayValues();
        } catch (error) {
            this.showToast(this.labels.warningTitle, this.labels.loadRulesWarning, 'warning');
        }
    }

    normalizeExistingRules(parsed) {
        if (parsed && Array.isArray(parsed.conditions)) {
            return this.normalizeExpressionRule(parsed);
        }

        return this.normalizeLegacyGroupRule(parsed);
    }

    normalizeExpressionRule(parsed) {
        const normalizedConditions = [];
        const tokenMap = {};
        let runningId = 1;

        (parsed.conditions || []).forEach((rawCondition, index) => {
            const sourceId = String(rawCondition.id || index + 1);
            const expanded = this.expandCondition(rawCondition, runningId);
            runningId += expanded.length;

            normalizedConditions.push(...expanded);
            tokenMap[sourceId] = expanded.map((condition) => condition.id);
        });

        const logicMode = this.normalizeLogicMode(parsed.logicMode, parsed.logicExpression);
        let logicExpression = (parsed.logicExpression || '').trim();

        if (logicMode === LOGIC_MODE_CUSTOM) {
            logicExpression = this.rewriteLogicExpression(logicExpression, tokenMap);
            if (!logicExpression && normalizedConditions.length > 0) {
                logicExpression = normalizedConditions.map((condition) => condition.id).join(' OR ');
            }
        }

        return {
            conditions: normalizedConditions,
            logicMode,
            logicExpression
        };
    }

    normalizeLegacyGroupRule(parsed) {
        const legacyGroups = parsed && Array.isArray(parsed.groups) ? parsed.groups : [];
        if (legacyGroups.length === 0) {
            return {
                conditions: [],
                logicMode: LOGIC_MODE_ALL,
                logicExpression: ''
            };
        }

        const normalizedConditions = [];
        const groupExpressions = [];
        const rootLogic = this.normalizeLogicalOperator(parsed.logic) || 'OR';

        let runningId = 1;
        legacyGroups.forEach((group) => {
            const conditionExpressions = [];
            const groupLogic = this.normalizeLogicalOperator(group.logic) || 'AND';

            (group.conditions || []).forEach((legacyCondition) => {
                const expanded = this.expandCondition(legacyCondition, runningId);
                runningId += expanded.length;

                normalizedConditions.push(...expanded);

                if (expanded.length === 1) {
                    conditionExpressions.push(expanded[0].id);
                } else if (expanded.length > 1) {
                    conditionExpressions.push(`(${expanded.map((condition) => condition.id).join(' OR ')})`);
                }
            });

            if (conditionExpressions.length === 1) {
                groupExpressions.push(conditionExpressions[0]);
            } else if (conditionExpressions.length > 1) {
                groupExpressions.push(`(${conditionExpressions.join(` ${groupLogic} `)})`);
            }
        });

        return {
            conditions: normalizedConditions,
            logicMode: LOGIC_MODE_CUSTOM,
            logicExpression: groupExpressions.join(` ${rootLogic} `)
        };
    }

    expandCondition(rawCondition, startId) {
        const type = this.normalizeConditionType(rawCondition.type);
        if (!type) {
            return [];
        }

        const operator = this.normalizeLoadedOperator(rawCondition);

        if (type === CONDITION_TYPE_PICKLIST) {
            if (operator === OPERATOR_IN) {
                const values = this.extractStringList(rawCondition.values, rawCondition.value);
                return values.map((value, index) => {
                    return {
                        id: String(startId + index),
                        type: CONDITION_TYPE_PICKLIST,
                        field: rawCondition.field,
                        fieldLabel: rawCondition.fieldLabel || rawCondition.field,
                        op: OPERATOR_EQ,
                        value
                    };
                });
            }

            const picklistValue = this.extractSingleValue(rawCondition.value, rawCondition.values);
            if (!picklistValue) {
                return [];
            }

            return [
                {
                    id: String(startId),
                    type: CONDITION_TYPE_PICKLIST,
                    field: rawCondition.field,
                    fieldLabel: rawCondition.fieldLabel || rawCondition.field,
                    op: operator,
                    value: picklistValue
                }
            ];
        }

        if (operator === OPERATOR_IN) {
            const recordTypeIds = this.extractStringList(rawCondition.recordTypeIds, rawCondition.recordTypeId);
            return recordTypeIds.map((recordTypeId, index) => {
                return {
                    id: String(startId + index),
                    type: CONDITION_TYPE_RECORD_TYPE,
                    op: OPERATOR_EQ,
                    recordTypeId,
                    recordTypeName: rawCondition.recordTypeName
                };
            });
        }

        const singleRecordTypeId = this.extractSingleValue(rawCondition.recordTypeId, rawCondition.recordTypeIds);
        if (!singleRecordTypeId) {
            return [];
        }

        return [
            {
                id: String(startId),
                type: CONDITION_TYPE_RECORD_TYPE,
                op: operator,
                recordTypeId: singleRecordTypeId,
                recordTypeName: rawCondition.recordTypeName
            }
        ];
    }

    rewriteLogicExpression(expression, tokenMap) {
        let output = expression || '';
        Object.keys(tokenMap || {}).forEach((oldToken) => {
            const mappedTokens = tokenMap[oldToken] || [];
            if (mappedTokens.length === 0) {
                return;
            }

            const replacement = mappedTokens.length === 1 ? mappedTokens[0] : `(${mappedTokens.join(' OR ')})`;
            const pattern = new RegExp(`\\b${oldToken}\\b`, 'g');
            output = output.replace(pattern, replacement);
        });

        return output;
    }

    hydrateConditionDisplayValues() {
        this.conditions = this.conditions.map((condition) => {
            if (condition.type === CONDITION_TYPE_PICKLIST) {
                const fieldOption = this.picklistFieldOptions.find((option) => option.value === condition.field);
                return {
                    ...condition,
                    fieldLabel: fieldOption ? fieldOption.shortLabel : condition.fieldLabel || condition.field
                };
            }

            const recordTypeOption = this.recordTypeOptions.find((option) => option.value === condition.recordTypeId);
            return {
                ...condition,
                recordTypeName: recordTypeOption ? recordTypeOption.label : condition.recordTypeName || condition.recordTypeId
            };
        });
    }

    buildRulesPayload() {
        const logicExpression = this.buildPayloadLogicExpression();

        return {
            version: 2,
            mode: 'expression',
            logicMode: this.logicMode,
            logicExpression,
            conditions: this.conditions.map((condition) => {
                if (condition.type === CONDITION_TYPE_PICKLIST) {
                    const legacyCompatibleOp = condition.op === OPERATOR_EQ ? OPERATOR_IN : condition.op;
                    return {
                        id: condition.id,
                        type: CONDITION_TYPE_PICKLIST,
                        field: condition.field,
                        op: legacyCompatibleOp,
                        value: condition.value,
                        values: condition.value ? [condition.value] : []
                    };
                }

                const legacyCompatibleOp = condition.op === OPERATOR_EQ ? OPERATOR_IN : condition.op;
                return {
                    id: condition.id,
                    type: CONDITION_TYPE_RECORD_TYPE,
                    op: legacyCompatibleOp,
                    recordTypeId: condition.recordTypeId,
                    recordTypeIds: condition.recordTypeId ? [condition.recordTypeId] : []
                };
            })
        };
    }

    buildPayloadLogicExpression() {
        if (!this.hasConditions) {
            return null;
        }

        if (this.logicMode === LOGIC_MODE_CUSTOM) {
            return this.logicExpression.trim();
        }

        const joiner = this.logicMode === LOGIC_MODE_ALL ? ' AND ' : ' OR ';
        return this.conditions.map((condition) => condition.id).join(joiner);
    }

    buildConditionSummary(condition) {
        const operatorLabel = this.getOperatorLabel(condition.op);

        if (condition.type === CONDITION_TYPE_PICKLIST) {
            return `${this.labels.recordPrefix}${condition.fieldLabel || condition.field} ${operatorLabel} ${condition.value}`;
        }

        return `${this.labels.recordPrefix}${this.labels.recordType} ${operatorLabel} ${condition.recordTypeName || condition.recordTypeId}`;
    }

    getOperatorLabel(operator) {
        if (operator === OPERATOR_NEQ) {
            return this.labels.operatorNotEqual;
        }
        if (operator === OPERATOR_IN) {
            return this.labels.operatorIn;
        }
        return this.labels.operatorEqual;
    }

    get nextConditionId() {
        const numericIds = this.conditions
            .map((condition) => Number.parseInt(condition.id, 10))
            .filter((value) => !Number.isNaN(value));

        const maxId = numericIds.length > 0 ? Math.max(...numericIds) : 0;
        return String(maxId + 1);
    }

    resetCurrentFilterForm() {
        this.selectedOperator = OPERATOR_EQ;
        this.selectedPicklistValue = '';
        this.selectedRecordTypeId = '';
    }

    validateLocalState() {
        const errors = [];

        if (!this.templateId) {
            errors.push(this.labels.templateMissing);
            return errors;
        }

        if (!this.hasConditions) {
            errors.push(this.labels.addAtLeastOneFilter);
            return errors;
        }

        const conditionIds = new Set(this.conditions.map((condition) => String(condition.id)));
        if (conditionIds.size !== this.conditions.length) {
            errors.push(this.labels.uniqueIds);
            return errors;
        }

        if (this.logicMode === LOGIC_MODE_CUSTOM) {
            const expressionErrors = this.validateLogicExpression(this.logicExpression, conditionIds);
            errors.push(...expressionErrors);
        }

        return errors;
    }

    validateLogicExpression(expression, conditionIds) {
        const errors = [];
        const tokens = this.tokenizeExpression(expression);

        if (tokens.length === 0) {
            errors.push(this.labels.logicRequired);
            return errors;
        }

        const referencedIds = new Set();
        let openParentheses = 0;
        let expectedOperand = true;

        for (let index = 0; index < tokens.length; index += 1) {
            const token = tokens[index];

            if (expectedOperand) {
                if (token === '(') {
                    openParentheses += 1;
                    continue;
                }

                if (/^\d+$/.test(token)) {
                    if (!conditionIds.has(token)) {
                        errors.push(this.format(this.labels.filterNotExists, token));
                        return errors;
                    }
                    referencedIds.add(token);
                    expectedOperand = false;
                    continue;
                }

                errors.push(this.format(this.labels.tokenInvalid, index + 1, token));
                return errors;
            }

            if (token === ')') {
                openParentheses -= 1;
                if (openParentheses < 0) {
                    errors.push(this.labels.invalidParentheses);
                    return errors;
                }
                continue;
            }

            if (token === 'AND' || token === 'OR') {
                expectedOperand = true;
                continue;
            }

            errors.push(this.format(this.labels.tokenInvalid, index + 1, token));
            return errors;
        }

        if (expectedOperand) {
            errors.push(this.labels.expressionEndsWithOperator);
            return errors;
        }

        if (openParentheses !== 0) {
            errors.push(this.labels.unbalancedParentheses);
            return errors;
        }

        if (referencedIds.size === 0) {
            errors.push(this.labels.logicMustReferenceFilter);
            return errors;
        }

        return errors;
    }

    tokenizeExpression(expression) {
        if (!expression || !expression.trim()) {
            return [];
        }

        const normalized = expression
            .replace(/&&/g, ' AND ')
            .replace(/\|\|/g, ' OR ')
            .replace(/\(/g, ' ( ')
            .replace(/\)/g, ' ) ');

        return normalized
            .split(/\s+/)
            .map((token) => token.trim())
            .filter((token) => !!token)
            .map((token) => this.normalizeLogicalOperator(token) || token);
    }

    normalizeLogicalOperator(token) {
        if (!token) {
            return null;
        }

        const upper = token.toUpperCase();
        if (upper === 'AND' || upper === 'OR') {
            return upper;
        }

        return null;
    }

    normalizeLogicMode(logicMode, logicExpression) {
        const value = (logicMode || '').toUpperCase();
        if (value === LOGIC_MODE_ALL || value === LOGIC_MODE_ANY || value === LOGIC_MODE_CUSTOM) {
            return value;
        }

        if (logicExpression && logicExpression.trim()) {
            return LOGIC_MODE_CUSTOM;
        }

        return LOGIC_MODE_ALL;
    }

    normalizeConditionType(type) {
        if (!type) {
            return null;
        }

        const value = String(type).trim();
        if (value === CONDITION_TYPE_PICKLIST || value.toLowerCase() === CONDITION_TYPE_PICKLIST) {
            return CONDITION_TYPE_PICKLIST;
        }

        if (value === CONDITION_TYPE_RECORD_TYPE || value.toLowerCase() === CONDITION_TYPE_RECORD_TYPE) {
            return CONDITION_TYPE_RECORD_TYPE;
        }

        return null;
    }

    normalizeLoadedOperator(condition) {
        const raw = condition && condition.op ? String(condition.op).trim().toUpperCase() : '';
        if (raw === OPERATOR_EQ || raw === OPERATOR_NEQ || raw === OPERATOR_IN) {
            return raw;
        }

        if (condition && (Array.isArray(condition.values) || Array.isArray(condition.recordTypeIds))) {
            return OPERATOR_IN;
        }

        return OPERATOR_EQ;
    }

    extractSingleValue(singleValue, arrayValues) {
        if (singleValue) {
            return String(singleValue);
        }

        if (Array.isArray(arrayValues) && arrayValues.length > 0) {
            return String(arrayValues[0]);
        }

        return '';
    }

    extractStringList(arrayValues, singleValue) {
        if (Array.isArray(arrayValues) && arrayValues.length > 0) {
            return arrayValues.map((value) => String(value)).filter((value) => !!value);
        }

        if (singleValue) {
            return [String(singleValue)];
        }

        return [];
    }

    format(template, ...args) {
        let output = template || '';
        args.forEach((arg, index) => {
            output = output.replace(`{${index}}`, String(arg));
        });
        return output;
    }

    setSaveMessage(message, variant) {
        this.saveMessage = message;
        this.saveMessageVariant = variant;
    }

    clearSaveMessage() {
        this.saveMessage = '';
        this.saveMessageVariant = '';
    }

    extractErrorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        if (error && error.message) {
            return error.message;
        }
        return this.labels.unexpectedError;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    notifyParent(title, message, variant) {
        this.dispatchEvent(
            new CustomEvent('notify', {
                detail: { title, message, variant },
                bubbles: true,
                composed: true
            })
        );
    }
}
