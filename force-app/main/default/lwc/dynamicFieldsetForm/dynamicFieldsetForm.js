import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getConfiguration from '@salesforce/apex/FieldSetConfigurationService.getConfiguration';
import getConfigurationForTask from '@salesforce/apex/FieldSetConfigurationService.getConfigurationForTask';

export default class DynamicFieldsetForm extends LightningElement {
    @api objectApiName;

    @track sections = [];
    @track activeSectionNames = [];
    isLoading = false;
    hasChanges = false;
    targetRecordId;
    targetObjectApiName;
    isReadOnly = false;

    _recordId;

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        this._recordId = value;
        if (value) {
            this.loadConfiguration();
        }
    }

    get hasSections() {
        return Array.isArray(this.sections) && this.sections.length > 0;
    }

    get showForm() {
        return this.hasSections && this.targetRecordId && this.targetObjectApiName;
    }

    get showActions() {
        return this.showForm && !this.isReadOnly;
    }

    connectedCallback() {
        if (this.recordId) {
            this.loadConfiguration();
        }
    }

    loadConfiguration() {
        if (!this._recordId) {
            return;
        }

        this.isLoading = true;
        this.hasChanges = false;

        if (this.objectApiName) {
            getConfiguration({
                objectApiName: this.objectApiName,
                recordId: this._recordId,
            })
                .then((data) => {
                    const sections = this.decorateSections(data);

                    if (!sections.length && this.isTaskContext()) {
                        return this.fetchRelatedConfiguration();
                    }

                    this.applyConfiguration({
                        sections,
                        targetObjectApiName: this.objectApiName,
                        targetRecordId: this._recordId,
                        readOnly: false,
                    });
                    return null;
                })
                .catch((error) => {
                    this.clearConfiguration();
                    this.handleError('Não foi possível carregar a configuração de campos.', error);
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }
    }

    fetchRelatedConfiguration() {
        return getConfigurationForTask({ taskId: this._recordId })
            .then((response) => {
                this.applyConfiguration({
                    sections: this.decorateSections(response?.sections),
                    targetObjectApiName: response?.targetObjectApiName,
                    targetRecordId: response?.targetRecordId,
                    readOnly: response?.readOnly,
                });
            })
            .catch((error) => {
                this.clearConfiguration();
                this.handleError('Não foi possível carregar a configuração relacionada.', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    applyConfiguration({ sections, targetObjectApiName, targetRecordId, readOnly }) {
        this.sections = sections || [];
        this.targetObjectApiName = targetObjectApiName || null;
        this.targetRecordId = targetRecordId || null;
        this.isReadOnly = Boolean(readOnly);
        this.activeSectionNames = this.sections.map((section) => section.key);
    }

    clearConfiguration() {
        this.sections = [];
        this.targetObjectApiName = null;
        this.targetRecordId = null;
        this.isReadOnly = false;
        this.activeSectionNames = [];
    }

    isTaskContext() {
        return (this.objectApiName || '').toLowerCase() === 'task';
    }

    decorateSections(sections) {
        if (!Array.isArray(sections)) {
            return [];
        }

        return sections.map((section, sectionIndex) => {
            const normalizedSection = {
                ...section,
                key: `${section.fieldSetName || 'section'}-${sectionIndex}`,
            };

            normalizedSection.fields = (section.fields || []).map((field, fieldIndex) => ({
                ...field,
                domKey: `${normalizedSection.key}-${field.apiName}-${fieldIndex}`,
            }));

            return normalizedSection;
        });
    }

    handleFieldChange() {
        this.hasChanges = true;
    }

    handleCancel() {
        const form = this.template.querySelector('lightning-record-edit-form');
        if (form) {
            form.reset();
        }
        this.clearFieldValidation();
        this.hasChanges = false;
        this.loadConfiguration();
    }

    handleSave() {
        if (!this.showForm) {
            return;
        }

        const form = this.template.querySelector('lightning-record-edit-form');
        if (form) {
            form.submit();
        }
    }

    handleSubmit(event) {
        if (!this.validateRequiredFields()) {
            event.preventDefault();
            this.showToast('Erro', 'Preencha os campos obrigatórios antes de salvar.', 'error');
        }
    }

    handleSuccess() {
        this.hasChanges = false;
        this.showToast('Sucesso', 'Registro atualizado com sucesso.', 'success');
        this.loadConfiguration();
    }

    handleFormError(event) {
        this.handleError('Falha ao salvar o registro.', event.detail);
    }

    validateRequiredFields() {
        if (!this.showForm) {
            return true;
        }

        let isValid = true;
        const inputs = this.template.querySelectorAll('lightning-input-field');

        inputs.forEach((input) => {
            const required = input.dataset.required === 'true';
            const updateable = input.dataset.updateable !== 'false';

            if (required && updateable && this.isEmpty(input.value)) {
                input.setCustomValidity('Campo obrigatório.');
                isValid = false;
            } else {
                input.setCustomValidity('');
            }

            input.reportValidity();
        });

        return isValid;
    }

    clearFieldValidation() {
        this.template.querySelectorAll('lightning-input-field').forEach((input) => {
            input.setCustomValidity('');
            input.reportValidity();
        });
    }

    isEmpty(value) {
        return value === null || value === undefined || value === '';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant,
            })
        );
    }

    handleError(message, detail) {
        // eslint-disable-next-line no-console
        console.error(message, detail);
        this.showToast('Erro', message, 'error');
    }
}
