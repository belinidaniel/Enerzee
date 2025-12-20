import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getConfiguration from '@salesforce/apex/FieldSetConfigurationService.getConfiguration';
import getConfigurationForTask from '@salesforce/apex/FieldSetConfigurationService.getConfigurationForTask';
import getTaskContext from '@salesforce/apex/ActivityDocumentController.getTaskContext';
import getRequiredDocuments from '@salesforce/apex/ActivityDocumentController.getRequiredDocuments';
import getAttachments from '@salesforce/apex/ActivityDocumentController.getAttachments';
import uploadExternalArchive from '@salesforce/apex/ExternalArchiveService.uploadExternalArchive';
import completeTask from '@salesforce/apex/TaskCompletionService.completeWithComment';
import isTaskClosed from '@salesforce/apex/TaskCompletionService.isTaskClosed';

export default class DynamicFieldsetForm extends NavigationMixin(LightningElement) {
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
    requiresComment = false;
    showAttachmentModal = false;
    attachmentUploading = false;
    attachmentSectionLabel;
    uploadedFilePills = [];
    showCommentModal = false;
    commentText = '';
    completeAfterSave = false;
    silentSave = false;
    completing = false;
    subStatusValue = null;
    subStatusInitialized = false;
    showDocUpload = false;
    taskContext;
    lastFollowUpId;
    autoSaving = false;
    autoSaveQueued = false;
    autoSaveTimeout;
    attachments = [];
    attachmentsLoading = false;
    selectedFiles = [];

    _recordId;

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        this._recordId = value;
        if (value) {
            this.loadConfiguration();
            this.checkTaskClosed();
        }
    }

    get hasSections() {
        return (Array.isArray(this.sections) && this.sections.length > 0) || this.showDocUpload;
    }

    get showForm() {
        return this.targetRecordId && this.targetObjectApiName && this.hasSections;
    }

    get showActions() {
        return this.showForm && !this.formReadOnly && !this.onlyAttachmentMode && !this.onlyCommentMode;
    }

    get hasRenderableSections() {
        return (this.sections || []).some(
            (section) => (section.fields && section.fields.length > 0) || section.requiresAttachment
        );
    }

    get formReadOnly() {
        return this.isReadOnly || this.isClosed || this.isCompletedStatus;
    }

    connectedCallback() {
        if (this.recordId) {
            this.loadConfiguration();
            this.checkTaskClosed();
            this.loadTaskContext();
        }
    }

    renderedCallback() {
        if (this.subStatusInitialized || !this.showForm) {
            return;
        }
        const input = this.template.querySelector('lightning-input-field[data-field-api="SubStatus__c"]');
        if (input) {
            this.subStatusValue = input.value;
            this.subStatusInitialized = true;
            this.refreshMotivoVisibility();
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
                    this.loadTaskContext();
                    return null;
                })
                .catch((error) => {
                    this.clearConfiguration();
                    this.handleError('Não foi possível carregar a configuração de campos.', error);
                })
                .finally(() => {
                    this.isLoading = false;
                });
        } else if (this.isTaskContext()) {
            this.fetchRelatedConfiguration()
                .then(() => this.loadTaskContext())
                .finally(() => {
                    this.isLoading = false;
                });
        } else {
            this.isLoading = false;
        }
    }

    async loadTaskContext() {
        try {
            this.taskContext = await getTaskContext({ taskId: this._recordId });
            const subject = this.taskContext ? this.taskContext.subject : null;
            if (subject) {
                const docs = await getRequiredDocuments({ activitySubject: subject });
                this.showDocUpload = docs && docs.length > 0;
            } else {
                this.showDocUpload = false;
            }
            await this.loadAttachments();
        } catch (e) {
            console.warn('Erro ao carregar contexto da task', e);
            this.showDocUpload = false;
            this.attachments = [];
        }
    }

    fetchRelatedConfiguration() {
        return getConfigurationForTask({ taskId: this._recordId })
            .then((response) => {
                console.log('Configuração relacionada obtida para Task:', JSON.stringify(response));
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
        this.requiresComment = this.sections.some((section) => section.requiresComment);
        const firstAttachmentSection = this.sections.find((section) => section.requiresAttachment);
        this.attachmentSectionLabel = firstAttachmentSection ? firstAttachmentSection.label : null;
        this.uploadedFilePills = [];
        this.subStatusValue = null;
        this.subStatusInitialized = false;
    }

    clearConfiguration() {
        this.sections = [];
        this.targetObjectApiName = null;
        this.targetRecordId = null;
        this.isReadOnly = false;
        this.activeSectionNames = [];
        this.subStatusValue = null;
        this.subStatusInitialized = false;
        this.attachments = [];
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
                isVisible: this.resolveFieldVisibility(field.apiName),
            }));

            return normalizedSection;
        });
    }

    handleFieldChange(event) {
        this.hasChanges = true;
        const input = event?.target;
        const apiName = input?.fieldName || input?.dataset?.fieldApi;
        if (apiName === 'SubStatus__c') {
            this.subStatusValue = input.value;
            this.refreshMotivoVisibility();
        }
        this.queueAutoSave();
    }

    handleFieldBlur() {
        if (!this.showForm || this.formReadOnly) {
            return;
        }
        this.queueAutoSave();
    }

    queueAutoSave() {
        if (!this.showForm || this.formReadOnly) {
            return;
        }

        this.autoSaveQueued = true;

        if (this.autoSaveTimeout) {
            clearTimeout(this.autoSaveTimeout);
        }

        this.autoSaveTimeout = window.setTimeout(() => {
            this.runAutoSave();
        }, 200);
    }

    runAutoSave() {
        if (!this.autoSaveQueued || !this.showForm || this.formReadOnly) {
            return;
        }

        if (this.autoSaving) {
            this.autoSaveTimeout = window.setTimeout(() => {
                this.runAutoSave();
            }, 200);
            return;
        }

        this.autoSaveQueued = false;
        this.autoSaving = true;
        this.silentSave = true;
        this.autoSaveTimeout = null;
        this.submitForm();
    }

    clearAutoSaveQueue() {
        if (this.autoSaveTimeout) {
            clearTimeout(this.autoSaveTimeout);
            this.autoSaveTimeout = null;
        }
        this.autoSaveQueued = false;
    }

    handleCancel() {
        this.clearAutoSaveQueue();
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

        this.clearAutoSaveQueue();
        this.completeAfterSave = false;
        this.submitForm();
    }

    handleSaveAndComplete() {
        if (!this.showForm) {
            return;
        }

        this.clearAutoSaveQueue();
        this.completeAfterSave = true;
        this.submitForm();
    }

    submitForm() {
        const form = this.template.querySelector('lightning-record-edit-form');
        if (form) {
            form.submit();
        }
    }

    handleSubmit(event) {
        if (!this.validateRequiredFields()) {
            event.preventDefault();
            if (!this.silentSave) {
                this.showToast('Erro', 'Preencha os campos obrigatórios antes de salvar.', 'error');
            }
            this.autoSaving = false;
            this.silentSave = false;
        }
    }

    handleSuccess() {
        this.hasChanges = false;
        this.autoSaving = false;
        if (this.silentSave) {
            this.silentSave = false;
            return;
        }
        if (this.completeAfterSave) {
            if (this.completing) {
                return;
            }
            this.handleCompleteWithComment();
            return;
        }

        this.showToast('Sucesso', 'Registro atualizado com sucesso.', 'success');
        this.loadConfiguration();
    }


    // UI API para Task não é suportado; removido o wire para evitar erro.

    validateRequiredFields() {
        if (!this.showForm) {
            return true;
        }

        let isValid = true;
        const inputs = this.template.querySelectorAll('lightning-input-field');

        inputs.forEach((input) => {
            if (!this.isFieldVisibleByApi(input.dataset.fieldApi)) {
                input.setCustomValidity('');
                return;
            }
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

    get shouldShowMotivoSubStatus() {
        if (!this.subStatusValue) {
            return false;
        }
        const normalized = String(this.subStatusValue).toLowerCase();
        return normalized === 'aprovado parcialmente'
            || normalized === 'cancelado'
            || normalized === 'reprovado';
    }

    resolveFieldVisibility(apiName) {
        if (apiName === 'MotivoSubStatus__c') {
            return this.shouldShowMotivoSubStatus;
        }
        return true;
    }

    refreshMotivoVisibility() {
        if (!Array.isArray(this.sections) || !this.sections.length) {
            return;
        }
        this.sections = this.sections.map((section) => {
            const updatedFields = (section.fields || []).map((field) => {
                if (field.apiName === 'MotivoSubStatus__c') {
                    return { ...field, isVisible: this.shouldShowMotivoSubStatus };
                }
                return field;
            });
            return { ...section, fields: updatedFields };
        });
    }

    isFieldVisibleByApi(apiName) {
        if (!apiName) {
            return true;
        }
        for (const section of this.sections || []) {
            for (const field of section.fields || []) {
                if (field.apiName === apiName) {
                    return field.isVisible !== false;
                }
            }
        }
        return true;
    }

    get attachmentTargetId() {
        return this.taskContext?.whatId || this.targetRecordId || this._recordId;
    }

    async loadAttachments() {
        const targetId = this.attachmentTargetId;
        if (!targetId) {
            this.attachments = [];
            return;
        }

        this.attachmentsLoading = true;
        try {
            const items = await getAttachments({ sobjectId: targetId });
            this.attachments = items || [];
        } catch (error) {
            // eslint-disable-next-line no-console
            console.warn('Erro ao carregar anexos', error);
            this.attachments = [];
        } finally {
            this.attachmentsLoading = false;
        }
    }

    handleAccordionToggle(event) {
        const { openSections } = event.detail;
        this.activeSectionNames = Array.isArray(openSections) ? openSections : [openSections];
    }

    get showAttachmentAction() {
        return this.requiresAttachment && this.showForm;
    }

    get showCommentAction() {
        return this.requiresComment && this.showForm;
    }

    get showCompleteAction() {
        return this.showForm && !this.formReadOnly && !this.requiresComment;
    }

    get disableAttachmentUploadButton() {
        return this.attachmentUploading || !this.selectedFiles || this.selectedFiles.length === 0;
    }

    get disableAttachmentAction() {
        return this.formReadOnly || this.attachmentUploading;
    }

    get disableCompleteButton() {
        return this.formReadOnly || this.completing;
    }

    get onlyAttachmentMode() {
        // Se todas as seções são apenas de anexo (sem campos), esconder salvar/cancelar
        return this.requiresAttachment && (!this.sections || this.sections.every((s) => (s.fields || []).length === 0));
    }

    get onlyCommentMode() {
        return this.requiresComment && !this.requiresAttachment && (!this.sections || this.sections.every((s) => (s.fields || []).length === 0));
    }

    openAttachmentModal() {
        if (this.disableAttachmentAction) {
            return;
        }
        this.clearSelectedFiles();
        this.showAttachmentModal = true;
    }

    closeAttachmentModal() {
        this.showAttachmentModal = false;
        this.clearSelectedFiles();
    }

    handleAttachmentFileChange(event) {
        const files = event.target.files;
        if (!files || !files.length) {
            this.selectedFiles = [];
            return;
        }

        const readers = Array.from(files).map((file) => this.readFileAsBase64(file));
        Promise.all(readers)
            .then((results) => {
                this.selectedFiles = results;
            })
            .catch((error) => {
                this.selectedFiles = [];
                this.handleError('Falha ao ler arquivo(s).', error);
            });
    }

    readFileAsBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                try {
                    const base64Body = reader.result.split(',')[1];
                    const prefix = file.type ? `data:${file.type};base64,` : 'data:application/octet-stream;base64,';
                    resolve({ name: file.name, base64: prefix + base64Body });
                } catch (e) {
                    reject(e);
                }
            };
            reader.onerror = (e) => reject(e);
            reader.readAsDataURL(file);
        });
    }

    clearSelectedFiles() {
        this.selectedFiles = [];
    }

    async uploadSelectedFiles() {
        if (!this.selectedFiles || !this.selectedFiles.length) {
            this.showToast('Aviso', 'Selecione ao menos um arquivo para enviar.', 'warning');
            return;
        }
        if (!this.taskContext || !this.taskContext.opportunityId) {
            this.showToast('Erro', 'Oportunidade não identificada para anexar o arquivo.', 'error');
            return;
        }
        const targetId = this.attachmentTargetId;
        if (!targetId) {
            this.showToast('Erro', 'Registro relacionado não identificado para anexar o arquivo.', 'error');
            return;
        }

        this.attachmentUploading = true;
        try {
            const uploadedNames = [];
            for (const file of this.selectedFiles) {
                const cleanedName = this.stripExtension(file.name);
                const result = await uploadExternalArchive({
                    opportunityId: this.taskContext.opportunityId,
                    fileName: cleanedName,
                    base64File: file.base64,
                    sobjectId: targetId,
                    activityName: this.taskContext?.subject
                });

                if (!result || !result.success) {
                    const message = (result && result.message) || 'Falha ao enviar arquivo.';
                    throw new Error(message);
                }
                uploadedNames.push(cleanedName);
            }

            this.uploadedFilePills = uploadedNames.map((name, index) => ({
                label: name,
                name: `${index}-${name}`
            }));
            this.showToast('Sucesso', 'Arquivo(s) enviado(s) com sucesso.', 'success');
            this.closeAttachmentModal();
            await this.loadAttachments();
        } catch (error) {
            this.handleError('Falha ao processar o anexo.', error);
        } finally {
            this.attachmentUploading = false;
        }
    }

    stripExtension(fileName) {
        if (!fileName) {
            return fileName;
        }
        const lastDot = fileName.lastIndexOf('.');
        if (lastDot <= 0) {
            return fileName;
        }
        return fileName.substring(0, lastDot);
    }

    openCommentModal() {
        if (this.formReadOnly) {
            return;
        }
        this.showCommentModal = true;
    }

    closeCommentModal() {
        this.showCommentModal = false;
        this.commentText = '';
    }

    async handleCompleteWithComment() {
        if (this.formReadOnly) {
            return;
        }
        if (this.completing) {
            return;
        }
        // Validação apenas no fluxo via modal
        if (this.showCommentModal && (!this.commentText || !this.commentText.trim())) {
            this.showToast('Aviso', 'Comentário é obrigatório para finalizar.', 'warning');
            return;
        }
        this.completing = true;
        const wasCompletingAfterSave = this.completeAfterSave;
        this.completeAfterSave = false;
        try {
            const result = await completeTask({
                taskId: this._recordId,
                commentBody: this.commentText
            });
            this.showToast('Sucesso', 'Atividade finalizada com comentário.', 'success');
            this.closeCommentModal();
            this.isClosed = true;
            this.loadConfiguration();
            this.refreshRecordView();
            this.navigateToFollowUp(result);
        } catch (error) {
            const message = this.getErrorMessage(error) || 'Falha ao finalizar a atividade.';
            this.handleError(message, error);
        } finally {
            if (wasCompletingAfterSave) {
                this.hasChanges = false;
            }
            this.completing = false;
        }
    }

    navigateToFollowUp(result) {
        if (result && result.followUpId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: result.followUpId,
                    objectApiName: 'Task',
                    actionName: 'view'
                }
            });
        }
    }

    handleCommentChange(event) {
        this.commentText = event.target.value;
    }

    refreshRecordView() {
        // Reload removido por solicitação; mantemos estado local.
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

    get isCompletedStatus() {
        return false;
    }

    async checkTaskClosed() {
        if (!this._recordId) {
            return;
        }
        try {
            const closed = await isTaskClosed({ taskId: this._recordId });
            this.isClosed = Boolean(closed);
        } catch (error) {
            // não bloqueia uso; mantém estado atual
            // eslint-disable-next-line no-console
            console.error('Erro ao verificar status da tarefa', error);
        }
    }

    handleError(message, detail) {
        // eslint-disable-next-line no-console
        console.error(message, detail);
        this.silentSave = false;
        this.completing = false;
        this.autoSaving = false;
        const detailMessage = this.getErrorMessage(detail);
        const finalMessage = detailMessage && detailMessage !== message ? `${message} (${detailMessage})` : message;
        this.showToast('Erro', finalMessage, 'error');
    }

    getErrorMessage(error) {
        if (!error) {
            return null;
        }
        if (typeof error === 'string') {
            return error;
        }
        if (error.body && error.body.message) {
            return error.body.message;
        }
        if (error.body && error.body.pageErrors && error.body.pageErrors.length) {
            const first = error.body.pageErrors[0];
            if (first && first.message) {
                return first.message;
            }
        }
        if (error.message) {
            return error.message;
        }
        return null;
    }
}
