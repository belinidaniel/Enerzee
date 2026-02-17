import { LightningElement, api, track } from 'lwc';
import getObjectFieldsPage from '@salesforce/apex/DataSourceController.getObjectFieldsPage';
import getContactAndAccountFields from '@salesforce/apex/DataSourceController.getContactAndAccountFields';
import getClickSignTemplate from '@salesforce/apex/ClickSignTemplateController.getClickSignTemplate';
import ClickSign_SalesforceFields from '@salesforce/label/c.ClickSign_SalesforceFields';
import ClickSign_SalesforceContactFields from '@salesforce/label/c.ClickSign_SalesforceContactFields';
import ClickSign_ObjectFields from '@salesforce/label/c.ClickSign_ObjectFields';
import ClickSign_AnchorText from '@salesforce/label/c.ClickSign_AnchorText';
import ClickSign_Copy from '@salesforce/label/c.ClickSign_Copy';
import ClickSign_Delete from '@salesforce/label/c.ClickSign_Delete';
import ClickSign_AddField from '@salesforce/label/c.ClickSign_AddField';

export default class ClickSignTemplateFields extends LightningElement {
    @api objectName;
    @api templateId;
    @track objectFields;
    @track selectedFields = [];
    @track selectedContactFields = [];
    @track relationshipFields = [];
    @track lookupFields = [];
    @api isContactInfo = false;
    @api showFields = false;

    labels = {
        salesforceFields: ClickSign_SalesforceFields,
        salesforceContactFields: ClickSign_SalesforceContactFields,
        objectFields: ClickSign_ObjectFields,
        anchorText: ClickSign_AnchorText,
        copy: ClickSign_Copy,
        delete: ClickSign_Delete,
        addField: ClickSign_AddField
    };

    connectedCallback() {
        this.loadFields();
        if (this.templateId) {
            this.loadTemplate();
        }
    }

    loadFields() {
        this.showFields = false;

        if (this.isContactInfo) {
            console.log('objectName', this.objectName);
            getContactAndAccountFields({ objectName: this.objectName })
                .then((result) => {
                    this.objectFields = result;
                    console.log('this.objectFields', this.objectFields);
                    this.showFields = true;
                    console.log('this.showFields', this.showFields);
                    this.addField();
               })
                .catch((error) => {
                    console.error('Error fetching fields:', error);
                    this.notifyParent('Error', 'Falha ao carregar os campos do objeto.', 'error');
                });
        } else {
            getObjectFieldsPage({ objectName: this.objectName })
                .then((result) => {
                    this.objectFields = Array.isArray(result.objectFields) ? [...result.objectFields] : [];
                    this.relationshipFields = Array.isArray(result.relationshipFields) ? [...result.relationshipFields] : [];
                    this.lookupFields = Array.isArray(result.lookupFields) ? [...result.lookupFields] : [];
                    this.objectFields.sort((a, b) => (a.label || '').localeCompare(b.label || ''));
                    this.relationshipFields.sort((a, b) => (a.label || '').localeCompare(b.label || ''));
                    this.lookupFields.sort((a, b) => (a.label || '').localeCompare(b.label || ''));
                })
                .catch((error) => {
                    console.error('Error fetching fields:', error);
                    this.notifyParent('Error', 'Falha ao carregar os campos do objeto.', 'error');
                });
        }
    }

    loadTemplate() {
        getClickSignTemplate({ templateId: this.templateId })
            .then((result) => {
                if (result) {
                    console.log('result 1111', result.ContactsMapping__c);
                    if (this.isContactInfo && result.ContactsMapping__c) {
                        const parsedFields = JSON.parse(result.ContactsMapping__c);
                        this.selectedContactFields = parsedFields.map((field) => ({
                            id: field.id,
                            fieldName: field.fieldName,
                            labelFieldName: field.labelFieldName,
                            emailField: field.emailField,
                            labelEmailField: field.labelEmailField,
                            roleValueField: field.roleValueField,
                            labelRoleField: field.labelRoleField,
                        }));
                    } else if (result.ObjectMappings__c) {
                        const parsedFields = JSON.parse(result.ObjectMappings__c);
                        this.selectedFields = parsedFields.map((field) => ({
                            id: field.id,
                            fieldName: field.fieldName,
                            labelFieldName: field.labelFieldName,
                            relationshipField: field.relationshipField,
                            relatedField: field.relatedField,
                            labelRelatedField: field.labelRelatedField,
                            tag: field.tag,
                            tagLabel: field.tag.replace(/\//g, '').replace(/\./g, ''),
                        }));
                    }
                }
                console.log('teste', JSON.stringify(this.selectedContactFields));
            })
            .catch((error) => {
                console.error('Error loading template:', JSON.stringify(error));
                this.notifyParent('Error', 'Falha ao carregar o template para os campos.', 'error');
            });
    }

    handleFieldChange(event) {
        console.log('handleFieldChange 1111');
        const id = event.target.dataset.index;
        const fieldName = event.detail.fieldName;
        const relatedObject = event.detail.relatedObject;
        const relatedField = event.detail.relatedField;
        const labelFieldName = event.detail.labelFieldName;
        const labelRelatedField = event.detail.labelRelatedField;

        const fieldIndex = this.selectedFields.findIndex((field) => field.id === id);
        console.log('handleFieldChange 22222');

        if (fieldIndex !== -1) {
            this.selectedFields[fieldIndex].fieldName = fieldName;
            this.selectedFields[fieldIndex].relationshipField = relatedObject || null;
            this.selectedFields[fieldIndex].relatedField = relatedField || null;
            this.selectedFields[fieldIndex].labelFieldName = labelFieldName || null;
            this.selectedFields[fieldIndex].labelRelatedField = labelRelatedField || null;

            if (relatedObject && relatedField) {
                this.selectedFields[fieldIndex].tag = `{{/${this.objectName}/${relatedObject}.${relatedField}}}`;
            } else {
                this.selectedFields[fieldIndex].tag = `{{/${this.objectName}/${fieldName}}}`;
            }
        }
        this.selectedFields[fieldIndex].tagLabel = this.selectedFields[fieldIndex].tag.replace(/\//g, '').replace(/\./g, '');
        console.log('teste 1');
        this.dispatchFieldsChangeEvent();
    }

    handleContactFieldChange(event) {
        const index = event.target.dataset.index;
        const fieldName = event.detail.fieldName;
        const labelFieldName = event.detail.labelFieldName;
        const emailField = event.detail.emailField;
        const labelEmailField = event.detail.labelEmailField;
        const roleValueField = event.detail.roleValueField;
        const labelRoleField = event.detail.labelRoleField;
        const labelRelatedField = event.detail.labelRelatedField;
        const objectName = event.detail.objectName;
        const relatedField = event.detail.relatedField;

        const fieldIndex = this.selectedContactFields.findIndex((field) => field.id === index);

        if (fieldIndex !== -1) {
            this.selectedContactFields[fieldIndex] = {
                ...this.selectedContactFields[fieldIndex],
                objectName,
                fieldName,
                relatedField,
                labelRelatedField,
                labelFieldName,
                emailField,
                labelEmailField,
                roleValueField,
                labelRoleField,
            };
        } else {
            this.selectedContactFields.push({
                id: index,
                objectName,
                fieldName,
                relatedField,
                labelRelatedField,
                labelFieldName,
                emailField,
                labelEmailField,
                roleValueField,
                labelRoleField,
            });
        }

        console.log('teste 2');
        this.dispatchContactFieldsChangeEvent();
    }

    handleCopy(event) {
        const tagLabel = event.target.dataset.tag;
        const textarea = document.createElement('textarea');
        textarea.value = tagLabel;
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);
    }

    addField() {
        const uniqueId = `field-${Date.now()}`;
        this.selectedContactFields =[];
        if (this.isContactInfo) {
            this.selectedContactFields = [
                ...this.selectedContactFields,
                {
                    id: uniqueId,
                    fieldName: '',
                    labelFieldName: '',
                    relatedField: '',
                    labelRelatedField: '',
                    emailField: '',
                    labelEmailField: '',
                    roleValueField: '',
                    labelRoleField: '',
                },
            ];
            console.log('teste 3');
            this.dispatchContactFieldsChangeEvent();
        } else {
            this.selectedFields = [
                ...this.selectedFields,
                {
                    id: uniqueId,
                    fieldName: '',
                    relationshipField: '',
                    relatedField: '',
                    tag: '',
                    tagLabel: '',
                    labelFieldName: '',
                    labelRelatedField: '',
                },
            ];
            console.log('teste 4');
            this.dispatchFieldsChangeEvent();
        }
    }

    removeField(event) {
        const id = event.target.dataset.index;
        this.selectedFields = this.selectedFields.filter((field) => field.id !== id);
            console.log('teste 5');
        this.dispatchFieldsChangeEvent();
    }

    removeContactField(event) {
        const id = event.target.dataset.index;
        this.selectedContactFields = this.selectedContactFields.filter((field) => field.id !== id);
        console.log('teste 6');
        this.dispatchContactFieldsChangeEvent();
    }

    dispatchFieldsChangeEvent() {
        const fieldsJson = this.selectedFields.map((field) => ({
            id: field.id,
            fieldName: field.fieldName,
            relationshipField: field.relationshipField || null,
            relatedField: field.relatedField || null,
            tag: field.tag || null,
            tagLabel: field.tagLabel    ,
            labelFieldName: field.labelFieldName || null,
            labelRelatedField: field.labelRelatedField || null,
        }));
        this.dispatchEvent(new CustomEvent('fieldschange', { detail: fieldsJson }));
    }

    dispatchContactFieldsChangeEvent() {
        const fieldsJson = this.selectedContactFields.map((field) => ({
            id: field.id,
            fieldName: field.fieldName,
            relatedField: field.relatedField || null,
            labelRelatedField: field.labelRelatedField || null,
            labelFieldName: field.labelFieldName || null,
            emailField: field.emailField || null,
            labelEmailField: field.labelEmailField || null,
            roleValueField: field.roleValueField || null,
            labelRoleField: field.labelRoleField || null,
        }));
        this.dispatchEvent(new CustomEvent('contactfieldschange', { detail: fieldsJson }));
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