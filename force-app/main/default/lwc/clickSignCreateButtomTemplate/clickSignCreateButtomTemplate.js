import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getClickSignTemplateToSend from '@salesforce/apex/ClickSignTemplateController.getClickSignTemplateToSend';
import getClickSignTemplate from '@salesforce/apex/ClickSignTemplateController.getClickSignTemplate';
import createButtonInLayout from '@salesforce/apex/ClickSignTemplateController.createButtonInLayout';
import listPicklistFields from '@salesforce/apex/ClickSignVisibilityRuleService.listPicklistFields';
import listRecordTypes from '@salesforce/apex/ClickSignVisibilityRuleService.listRecordTypes';
import generateMapFields from '@salesforce/apex/ClickSignUtils.generateMapFields';
import { getPicklistValuesByRecordType } from 'lightning/uiObjectInfoApi';
import ClickSign_CreateButtonTitle from '@salesforce/label/c.ClickSign_CreateButtonTitle';
import ClickSign_CreateButtonDescription from '@salesforce/label/c.ClickSign_CreateButtonDescription';
import ClickSign_TemplateDetails from '@salesforce/label/c.ClickSign_TemplateDetails';
import ClickSign_TemplateName from '@salesforce/label/c.ClickSign_TemplateName';
import ClickSign_TemplateDescription from '@salesforce/label/c.ClickSign_TemplateDescription';
import ClickSign_TemplateObject from '@salesforce/label/c.ClickSign_TemplateObject';
import ClickSign_ButtonLabel from '@salesforce/label/c.ClickSign_ButtonLabel';
import ClickSign_CreateButtonInLayout from '@salesforce/label/c.ClickSign_CreateButtonInLayout';
import ClickSign_SuccessMessage from '@salesforce/label/c.ClickSign_SuccessMessage';
import ClickSign_Recipients from '@salesforce/label/c.ClickSign_Recipients';
import ClickSign_FieldName from '@salesforce/label/c.ClickSign_FieldName';
import ClickSign_Email from '@salesforce/label/c.ClickSign_Email';
import ClickSign_RoleLabel from '@salesforce/label/c.ClickSign_RoleLabel';
import ClickSign_Fields from '@salesforce/label/c.ClickSign_Fields';
import ClickSign_Tag from '@salesforce/label/c.ClickSign_Tag';
import ClickSign_TagLabel from '@salesforce/label/c.ClickSign_TagLabel';
import ClickSign_NoTemplateData from '@salesforce/label/c.ClickSign_NoTemplateData';
import ClickSign_TagValue from '@salesforce/label/c.ClickSign_TagValue';

export default class ClickSignCreateButtomTemplate extends LightningElement {
    @api templateId;
    @track template;
    @api recordId;
    @track isLoading = false;
    @track contactsMapping = [];
    @track objectMappings = [];
    @track buttonLabel = '';
    @track successMessage = '';
    @api isSendTemplate = false;
    @track title;
    
    // Nova estrutura de filtros
    @track visibilityFilters = [];
    @track logicOperator = 'E'; // 'E', 'OU', 'Formula'
    @track formulaExpression = '';
    
    @track picklistFieldOptions = [];
    @track recordTypeOptions = [];
    @track picklistValuesByField = {};
    @track operatorOptions = [
        { label: 'Igual', value: 'equals' },
        { label: 'Não é igual', value: 'notEquals' },
        { label: 'Contém', value: 'contains' },
        { label: 'Não contém', value: 'notContains' },
        { label: 'Começa com', value: 'startsWith' },
        { label: 'Termina com', value: 'endsWith' },
        { label: 'Maior que', value: 'greaterThan' },
        { label: 'Menor que', value: 'lessThan' },
        { label: 'Maior ou igual', value: 'greaterOrEqual' },
        { label: 'Menor ou igual', value: 'lessOrEqual' }
    ];

    get logicOptions() {
        return [
            { label: 'E (todos os critérios)', value: 'E' },
            { label: 'OU (qualquer critério)', value: 'OU' },
            { label: 'Fórmula personalizada', value: 'Formula' }
        ];
    }

    get isFormulaMode() {
        return this.logicOperator === 'Formula';
    }

    sourceObjectApiName;
    masterRecordTypeId = '012000000000000AAA';

    labels = {
        createButtonTitle: ClickSign_CreateButtonTitle,
        createButtonDescription: ClickSign_CreateButtonDescription,
        templateDetails: ClickSign_TemplateDetails,
        templateName: ClickSign_TemplateName,
        templateDescription: ClickSign_TemplateDescription,
        templateObject: ClickSign_TemplateObject,
        buttonLabel: ClickSign_ButtonLabel,
        createButtonInLayout: ClickSign_CreateButtonInLayout,
        successMessage: ClickSign_SuccessMessage,
        recipients: ClickSign_Recipients,
        fieldName: ClickSign_FieldName,
        email: ClickSign_Email,
        roleLabel: ClickSign_RoleLabel,
        fields: ClickSign_Fields,
        tag: ClickSign_Tag,
        tagLabel: ClickSign_TagLabel,
        noTemplateData: ClickSign_NoTemplateData,
        tagValue: ClickSign_TagValue
    };

    connectedCallback() {
        if(this.isSendTemplate){
            this.title = '';
        }else{
            this.title = 'Criar Botão Personalizado';
        }
        if(this.isSendTemplate){
            this.getClickSignTemplateToSend();
        }else{
            this.getClickSignTemplate();
        }
    }

    @wire(getPicklistValuesByRecordType, { objectApiName: '$sourceObjectApiName', recordTypeId: '$masterRecordTypeId' })
    wiredPicklistValues({ error, data }) {
        if (data) {
            const valueMap = {};
            Object.keys(data.picklistFieldValues || {}).forEach((fieldApiName) => {
                valueMap[fieldApiName] = (data.picklistFieldValues[fieldApiName].values || []).map((valueOption) => ({
                    label: valueOption.label,
                    value: valueOption.value
                }));
            });
            this.picklistValuesByField = valueMap;
            this.syncFilterPicklistOptions();
        } else if (error) {
            console.error('Error loading picklist values for visibility rules:', error);
        }
    }

    getClickSignTemplateToSend() {
        this.isLoading = true;
        this.recordId == null? this.recordId = '5008900000GJg2MAAT' : this.recordId;
        getClickSignTemplateToSend({ templateId: this.templateId ,recordId: this.recordId})
            .then((result) => {
                if(result){
                    this.template = result;
                    this.contactsMapping = this.template.ClickSignSigners__r;
                    this.objectMappings = JSON.parse(this.template.ObjectMappings__c);
                    this.buttonLabel = this.template.ButtonLabel__c;
                    this.sourceObjectApiName = this.template.SourceObject__c;
                    this.initializeVisibilityFilters();
                    this.fetchObjectMappingValues();
                }
            })
            .catch((error) => {
                console.error('Error loading template:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    getClickSignTemplate() {
        this.isLoading = true;
        getClickSignTemplate({ templateId: this.templateId ,recordId: this.recordId})
            .then((result) => {
                if(result){
                    this.template = result;
                    this.contactsMapping = this.template.ClickSignSigners__r;
                    this.objectMappings = JSON.parse(this.template.ObjectMappings__c);
                    this.buttonLabel = this.template.ButtonLabel__c;
                    this.sourceObjectApiName = this.template.SourceObject__c;
                    this.initializeVisibilityFilters();
                    this.loadVisibilityRuleOptions();
                    this.fetchObjectMappingValues();
                }
            })
            .catch((error) => {
                console.error('Error loading template:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    fetchObjectMappingValues() {
        generateMapFields({ recordId: this.recordId, objectMappings: this.template.ObjectMappings__c, contractNumber: null, jsonContractInformation: null })
            .then((data) => {
                const mapFields = JSON.parse(data);
                this.objectMappings = this.objectMappings.map(field => {
                    return {
                        ...field,
                        tagValue: mapFields[field.tagLabel.replace('{{', '').replace('}}', '')] || ''
                    };
                });
            })
            .catch((error) => {
                this.showToast('Error', error.body.message, 'error');
            });
    }

    loadVisibilityRuleOptions() {
        if (!this.sourceObjectApiName || this.isSendTemplate) {
            return;
        }

        Promise.all([
            listPicklistFields({ sObjectApiName: this.sourceObjectApiName }),
            listRecordTypes({ sObjectApiName: this.sourceObjectApiName })
        ])
            .then(([picklistFields, recordTypes]) => {
                this.picklistFieldOptions = (picklistFields || []).map((fieldItem) => ({
                    label: fieldItem.label,
                    value: fieldItem.apiName
                }));
                this.recordTypeOptions = (recordTypes || []).map((recordType) => ({
                    label: recordType.name,
                    value: recordType.recordTypeId
                }));
                this.syncFilterPicklistOptions();
            })
            .catch((error) => {
                console.error('Error loading visibility rule options:', error);
            });
    }

    initializeVisibilityFilters() {
        this.visibilityFilters = [];
        this.logicOperator = 'E';
        this.formulaExpression = '';

        if (!this.template || !this.template.VisibilityRule__c) {
            this.visibilityFilters = [this.createEmptyFilter()];
            return;
        }

        try {
            const parsedRule = JSON.parse(this.template.VisibilityRule__c);
            
            // Suporta novo formato: { logic, filters, formula }
            if (parsedRule.filters && Array.isArray(parsedRule.filters)) {
                this.logicOperator = parsedRule.logic || 'E';
                this.formulaExpression = parsedRule.formula || '';
                this.visibilityFilters = parsedRule.filters.map((filter) => this.mapFilter(filter));
            } 
            // Compatibilidade com formato legado
            else if (parsedRule.groups && Array.isArray(parsedRule.groups)) {
                this.convertLegacyFormat(parsedRule);
            }
        } catch (error) {
            console.error('Error parsing VisibilityRule__c:', error);
            this.visibilityFilters = [];
        }

        if (!this.visibilityFilters.length) {
            this.visibilityFilters = [this.createEmptyFilter()];
        }
        this.syncFilterPicklistOptions();
    }

    convertLegacyFormat(legacyRule) {
        // Converte formato antigo para novo
        const filters = [];
        if (legacyRule.groups && legacyRule.groups.length > 0) {
            const group = legacyRule.groups[0];
            if (group.conditions && Array.isArray(group.conditions)) {
                group.conditions.forEach((condition) => {
                    if (condition.type === 'picklist') {
                        condition.values.forEach((value) => {
                            filters.push({
                                id: this.generateFilterId(),
                                field: condition.field,
                                operator: 'equals',
                                value: value
                            });
                        });
                    }
                });
            }
        }
        this.visibilityFilters = filters.length ? filters : [this.createEmptyFilter()];
        this.logicOperator = legacyRule.logic === 'OR' ? 'OU' : 'E';
    }

    mapFilter(filter) {
        return {
            id: filter.id || this.generateFilterId(),
            field: filter.field || '',
            operator: filter.operator || 'equals',
            value: filter.value || ''
        };
    }

    createEmptyFilter() {
        return {
            id: this.generateFilterId(),
            field: '',
            operator: 'equals',
            value: ''
        };
    }

    generateFilterId() {
        return `filter-${Date.now()}-${Math.random().toString(36).substring(2, 8)}`;
    }

    syncFilterPicklistOptions() {
        // Sincroniza opções de valor para cada filtro baseado no campo selecionado
        this.visibilityFilters = (this.visibilityFilters || []).map((filter) => {
            const fieldOptions = filter.field ? (this.picklistValuesByField[filter.field] || []) : [];
            return {
                ...filter,
                fieldValueOptions: fieldOptions
            };
        });
    }

    handleAddFilter() {
        this.visibilityFilters = [...this.visibilityFilters, this.createEmptyFilter()];
    }

    handleRemoveFilter(event) {
        const filterId = event.currentTarget.dataset.id;
        this.visibilityFilters = this.visibilityFilters.filter((filter) => filter.id !== filterId);
        if (!this.visibilityFilters.length) {
            this.visibilityFilters = [this.createEmptyFilter()];
        }
    }

    handleFilterFieldChange(event) {
        const filterId = event.currentTarget.dataset.id;
        const field = event.detail.value;
        const fieldOptions = this.picklistValuesByField[field] || [];
        this.updateFilter(filterId, {
            field,
            value: '',
            fieldValueOptions: fieldOptions
        });
    }

    handleFilterOperatorChange(event) {
        const filterId = event.currentTarget.dataset.id;
        const operator = event.detail.value;
        this.updateFilter(filterId, { operator });
    }

    handleFilterValueChange(event) {
        const filterId = event.currentTarget.dataset.id;
        const value = event.detail.value;
        this.updateFilter(filterId, { value });
    }

    handleLogicOperatorChange(event) {
        this.logicOperator = event.detail.value;
        if (this.logicOperator !== 'Formula') {
            this.formulaExpression = '';
        }
    }

    handleFormulaChange(event) {
        this.formulaExpression = event.detail.value;
    }

    updateFilter(filterId, patch) {
        this.visibilityFilters = this.visibilityFilters.map((filter) => {
            if (filter.id !== filterId) {
                return filter;
            }
            return { ...filter, ...patch };
        });
    }

    buildVisibilityRulePayload() {
        const filters = (this.visibilityFilters || [])
            .filter((filter) => filter.field && filter.value)
            .map((filter) => ({
                field: filter.field,
                operator: filter.operator,
                value: filter.value
            }));

        if (!filters.length) {
            return null;
        }

        const payload = {
            version: 2,
            logic: this.logicOperator,
            filters
        };

        if (this.logicOperator === 'Formula' && this.formulaExpression) {
            payload.formula = this.formulaExpression;
        }

        return payload;
    }

    buildVisibilityRuleJson() {
        const payload = this.buildVisibilityRulePayload();
        return payload ? JSON.stringify(payload) : null;
    }

    @api
    getButtonConfiguration() {
        return {
            buttonLabel: this.buttonLabel,
            visibilityRuleJson: this.buildVisibilityRuleJson()
        };
    }

    handleButtonLabelChange(event) {
        this.buttonLabel = event.target.value;
    }

    createButton() {
        const visibilityRuleJson = this.buildVisibilityRuleJson();
        createButtonInLayout({
            templateId: this.templateId,
            buttonLabel: this.buttonLabel,
            visibilityRuleJson
        })
            .then(() => {
                this.successMessage = 'Botão criado com sucesso!';
                if (this.template) {
                    this.template.VisibilityRule__c = visibilityRuleJson;
                }
            })
            .catch((error) => {
                console.error('Error creating button:', error);
                const errorMessage = (error && error.body && error.body.message) ? error.body.message : 'Erro ao criar botão';
                this.showToast('Erro', errorMessage, 'error');
            });
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }
}
