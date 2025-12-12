import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getConfiguration from '@salesforce/apex/FieldSetConfigurationService.getConfiguration';
import getConfigurationForTask from '@salesforce/apex/FieldSetConfigurationService.getConfigurationForTask';
import publishAttachmentNote from '@salesforce/apex/AttachmentFeedService.publishAttachmentNote';
import { getRecord, refreshApex } from 'lightning/uiRecordApi';

const TASK_FIELDS = ['Task.IsClosed', 'Task.Status', 'Activity.Status'];

export default class DynamicFieldsetForm extends LightningElement {
    @api objectApiName;

    @track sections = [];
    @track activeSectionNames = [];
    isLoading = false;
    hasChanges = false;
    targetRecordId;
    targetObjectApiName;
    isReadOnly = false;
    isClosed = false;
    wiredTaskResult;
    pollHandle;
    requiresAttachment = false;
    showAttachmentModal = false;
    attachmentUploading = false;
    attachmentSectionLabel;
    uploadedFilePills = [];

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
        return this.showForm && !this.formReadOnly && !this.onlyAttachmentMode;
    }

    get formReadOnly() {
        return this.isReadOnly || this.isClosed;
    }

    connectedCallback() {
        if (this.recordId) {
            this.loadConfiguration();
        }
        this.startPollingForClosure();
    }

    disconnectedCallback() {
        this.stopPollingForClosure();
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
        this.requiresAttachment = this.sections.some((section) => section.requiresAttachment);
        const firstAttachmentSection = this.sections.find((section) => section.requiresAttachment);
        this.attachmentSectionLabel = firstAttachmentSection ? firstAttachmentSection.label : null;
        this.uploadedFilePills = [];
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

    @wire(getRecord, { recordId: '$recordId', fields: TASK_FIELDS })
    wiredTask(value) {
        console.log('wiredTask called with value:', value); // Debug log
        this.wiredTaskResult = value;
        this.applyTaskState(value?.data);
    }

    startPollingForClosure() {
        this.stopPollingForClosure();
        this.pollHandle = window.setInterval(() => {
            if (this.wiredTaskResult) {
                refreshApex(this.wiredTaskResult);
            }
        }, 1500);
    }

    stopPollingForClosure() {
        if (this.pollHandle) {
            window.clearInterval(this.pollHandle);
            this.pollHandle = null;
        }
    }

    applyTaskState(taskData) {
        if (!taskData) {
            return;
        }

        const wasClosed = this.isClosed;
        const isClosedFlag = Boolean(taskData.fields?.IsClosed?.value);
        const statusValue = taskData.fields?.Status?.value || '';
        this.isClosed = isClosedFlag || statusValue.toLowerCase() === 'completed';

        if (this.isClosed && !wasClosed) {
            this.loadConfiguration();
        }
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

    handleAccordionToggle(event) {
        const { openSections } = event.detail;
        this.activeSectionNames = Array.isArray(openSections) ? openSections : [openSections];
    }

    get showAttachmentAction() {
        return this.requiresAttachment && this.showForm;
    }

    get disableAttachmentAction() {
        return this.formReadOnly || this.attachmentUploading;
    }

    get onlyAttachmentMode() {
        // Se todas as seções são apenas de anexo (sem campos), esconder salvar/cancelar
        return this.requiresAttachment && (!this.sections || this.sections.every((s) => (s.fields || []).length === 0));
    }

    openAttachmentModal() {
        if (this.disableAttachmentAction) {
            return;
        }
        this.showAttachmentModal = true;
    }

    closeAttachmentModal() {
        this.showAttachmentModal = false;
    }

    async handleUploadFinished(event) {
        this.attachmentUploading = true;
        try {
            const files = event.detail.files || [];
            const fileNames = files.map((f) => f.name);
            this.uploadedFilePills = fileNames.map((name, index) => ({
                label: name,
                name: `${index}-${name}`
            }));
            await publishAttachmentNote({
                parentId: this.targetRecordId,
                fileNames,
                activityLabel: this.attachmentSectionLabel
            });
            this.showToast('Sucesso', 'Arquivo(s) anexado(s) e comentário publicado.', 'success');
            this.showAttachmentModal = false;
        } catch (error) {
            this.handleError('Falha ao processar o anexo.', error);
        } finally {
            this.attachmentUploading = false;
        }
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
