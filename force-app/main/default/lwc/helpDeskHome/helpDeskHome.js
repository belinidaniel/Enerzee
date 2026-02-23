import { api, LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createCase from '@salesforce/apex/ModuloHelpDeskCaseController.createCase';
import getDefaultEntities from '@salesforce/apex/ModuloHelpDeskCaseController.getDefaultEntities';
import uploadFilesBypassLicense from '@salesforce/apex/ModuloHelpDeskCaseController.uploadFilesBypassLicense';
import getCaseCategoryOptions from '@salesforce/apex/ModuloHelpDeskCaseController.getCaseCategoryOptions';
import cloudLogo from '@salesforce/resourceUrl/salesforceCloudV3';
import agentAstro from '@salesforce/resourceUrl/agentforceAgentAstro';

export default class HelpDeskHome extends LightningElement {
    _contactId;
    @api
    get contactId() {
        return this._contactId;
    }
    set contactId(value) {
        this._contactId = value;
        if (value) {
            this.loadDefaults(value);
        }
    }
    @track showModal = false;
    @track isSaving = false;
    @track createdCaseId;
    @track contactName;
    @track accountName;
    accountId;
    defaultSuppliedEmail = '';
    defaultSuppliedPhone = '';

    @track subject = '';
    @track description = '';
    @track richDescription = '';
    @track systemValue = '';
    @track typeValue = '';
    @track subtypeValue = '';
    @track priorityValue = 'Medium';
    @track suppliedEmail = '';
    @track suppliedPhone = '';
    @track pendingFiles = [];
    @track readingFiles = false;
    @track categoryOptions = [];
    @track systemOptions = [];
    @track typeOptions = [];
    @track subtypeOptions = [];
    cloudLogo = cloudLogo;
    agentAstro = agentAstro;
    fileSequence = 0;
    fileToReplaceKey;

    fallbackCategoryOptions = [
        { systemValue: 'Salesforce', typeValue: 'Acesso', subtypeValue: 'Login', sortOrder: 10 },
        { systemValue: 'Salesforce', typeValue: 'Acesso', subtypeValue: 'Permissao', sortOrder: 20 },
        { systemValue: 'Salesforce', typeValue: 'Erro', subtypeValue: 'Performance', sortOrder: 30 },
        { systemValue: 'VO', typeValue: 'Integracao', subtypeValue: 'Falha de API', sortOrder: 40 },
        { systemValue: 'VO', typeValue: 'Integracao', subtypeValue: 'Timeout', sortOrder: 50 },
        { systemValue: 'App', typeValue: 'Acesso', subtypeValue: 'Login', sortOrder: 60 },
        { systemValue: 'App', typeValue: 'Funcionalidade', subtypeValue: 'Notificacao', sortOrder: 70 },
        { systemValue: 'Site', typeValue: 'Formulario', subtypeValue: 'Erro de validacao', sortOrder: 80 },
        { systemValue: 'Site', typeValue: 'Conteudo', subtypeValue: 'Texto incorreto', sortOrder: 90 }
    ];

    priorityOptions = [
        { label: 'Alta', value: 'High' },
        { label: 'Média', value: 'Medium' },
        { label: 'Baixa', value: 'Low' }
    ];

    richFormats = [
        'font',
        'size',
        'bold',
        'italic',
        'underline',
        'strike',
        'list',
        'align',
        'link',
        'image',
        'clean'
    ];

    get disableCreate() {
        return (
            this.isSaving ||
            this.readingFiles ||
            !this.subject ||
            !this.subject.trim() ||
            !this.systemValue ||
            !this.typeValue ||
            !this.subtypeValue
        );
    }

    get disableType() {
        return !this.systemValue || !this.typeOptions.length;
    }

    get disableSubtype() {
        return !this.systemValue || !this.typeValue || !this.subtypeOptions.length;
    }

    get hasFiles() {
        return this.pendingFiles && this.pendingFiles.length > 0;
    }

    get acceptedFormats() {
        return '.pdf,.png,.jpg,.jpeg,.doc,.docx,.xls,.xlsx,.txt';
    }

    get canCreate() {
        return !!this.contactId;
    }

    connectedCallback() {
        this.loadDefaults(this.contactId);
        this.loadCaseCategoryOptions();
    }

    loadDefaults(contactIdParam) {
        if (!contactIdParam) {
            return;
        }
        getDefaultEntities({ contactId: contactIdParam })
            .then((result) => {
                this.accountId = result.accountId;
                this.accountName = result.accountName;
                if (result.contactId) {
                    this._contactId = result.contactId;
                }
                this.contactName = result.contactName;
                this.defaultSuppliedEmail = result.contactEmail || '';
                this.defaultSuppliedPhone = result.contactPhone || '';
                this.suppliedEmail = result.contactEmail || '';
                this.suppliedPhone = result.contactPhone || '';
            })
            .catch((error) => {
                this.showToast('Aviso', this.normalizeError(error), 'warning');
            });
    }

    loadCaseCategoryOptions() {
        getCaseCategoryOptions()
            .then((result) => {
                const options = result && result.length ? result : this.fallbackCategoryOptions;
                this.categoryOptions = options.map((item) => ({ ...item }));
                this.refreshSystemOptions();
            })
            .catch(() => {
                this.categoryOptions = this.fallbackCategoryOptions.map((item) => ({ ...item }));
                this.refreshSystemOptions();
            });
    }

    openModal() {
        this.resetForm();
        this.showModal = true;
    }

    closeModal() {
        this.showModal = false;
    }

    handleInputChange(event) {
        const { name, value } = event.target;
        if (name === 'systemValue') {
            this.systemValue = value;
            this.typeValue = '';
            this.subtypeValue = '';
            this.refreshTypeOptions();
            return;
        }
        if (name === 'typeValue') {
            this.typeValue = value;
            this.subtypeValue = '';
            this.refreshSubtypeOptions();
            return;
        }
        this[name] = value;
    }

    handleCreate() {
        if (this.disableCreate || this.createdCaseId || !this.contactId) {
            return;
        }
        this.isSaving = true;
        let createdId;
        createCase({
            subject: this.subject,
            description: this.description,
            richDescription: this.richDescription,
            systemValue: this.systemValue,
            typeValue: this.typeValue,
            subtypeValue: this.subtypeValue,
            priorityValue: this.priorityValue,
            suppliedEmail: this.suppliedEmail,
            suppliedPhone: this.suppliedPhone,
            contactId: this.contactId,
            accountId: this.accountId
        })
            .then((result) => {
                createdId = result;
                if (this.hasFiles) {
                    return uploadFilesBypassLicense({
                        caseId: createdId,
                        files: this.buildApexFilePayload(),
                        contactId: this.contactId
                    });
                }
                return null;
            })
            .then(() => {
                this.createdCaseId = createdId;
                this.showToast('Caso criado', 'Caso criado com sucesso.', 'success');
                this.navigateToCase(createdId);
                this.resetForm();
                this.showModal = false;
                this.template.querySelector('c-help-desk-case-list')?.handleRefresh?.();
            })
            .catch((error) => {
                this.showToast('Erro ao criar caso', this.normalizeError(error), 'error');
            })
            .finally(() => {
                this.isSaving = false;
            });
    }

    navigateToCase(caseId) {
        if (!caseId) return;
        // Redireciona para a rota do case no site (preserva cId para uso nos detalhes)
        const url = `/helpdesk/case/${caseId}${this.contactId ? `?cId=${this.contactId}` : ''}`;
        window.location.assign(url);
    }

    resetForm() {
        this.isSaving = false;
        this.createdCaseId = null;
        this.subject = '';
        this.description = '';
        this.richDescription = '';
        this.systemValue = '';
        this.typeValue = '';
        this.subtypeValue = '';
        this.priorityValue = 'Medium';
        this.suppliedEmail = this.defaultSuppliedEmail || '';
        this.suppliedPhone = this.defaultSuppliedPhone || '';
        this.pendingFiles = [];
        this.readingFiles = false;
        this.fileToReplaceKey = null;
        this.refreshTypeOptions();
    }

    handleFilesChange(event) {
        const files = Array.from(event.target.files || []);
        if (!files.length) {
            return;
        }
        this.readingFiles = true;

        const readers = files.map((file) => this.buildFilePayload(file, this.generateFileKey()));

        Promise.allSettled(readers)
            .then((results) => {
                const success = results.filter((r) => r.status === 'fulfilled').map((r) => r.value);
                const failures = results.filter((r) => r.status === 'rejected');
                if (success.length) {
                    this.pendingFiles = [...this.pendingFiles, ...success];
                }
                if (failures.length) {
                    const firstErr = failures[0].reason;
                    this.showToast('Erro ao ler arquivo', firstErr?.message || firstErr || 'Erro inesperado', 'error');
                }
            })
            .finally(() => {
                this.readingFiles = false;
            });
    }

    removeFile(event) {
        const key = event.currentTarget.dataset.key;
        this.pendingFiles = this.pendingFiles.filter((f) => f.clientKey !== key);
    }

    handleEditFile(event) {
        this.fileToReplaceKey = event.currentTarget.dataset.key;
        const input = this.template.querySelector('.replace-file-input');
        if (input) {
            input.value = null;
            input.click();
        }
    }

    handleReplaceFileChange(event) {
        const selectedFile = event.target.files && event.target.files[0];
        if (!selectedFile || !this.fileToReplaceKey) {
            return;
        }
        const replaceKey = this.fileToReplaceKey;
        this.readingFiles = true;
        this.buildFilePayload(selectedFile, replaceKey)
            .then((updatedFile) => {
                this.pendingFiles = this.pendingFiles.map((file) => (file.clientKey === replaceKey ? updatedFile : file));
            })
            .catch((error) => {
                this.showToast('Erro ao editar arquivo', error?.message || error || 'Erro inesperado', 'error');
            })
            .finally(() => {
                this.readingFiles = false;
                this.fileToReplaceKey = null;
                event.target.value = null;
            });
    }

    buildFilePayload(file, clientKey) {
        return new Promise((resolve, reject) => {
            try {
                const reader = new FileReader();
                reader.onload = () => {
                    try {
                        const base64 = reader.result.split(',')[1];
                        resolve({
                            fileName: file.name,
                            contentType: file.type,
                            base64Data: base64,
                            humanSize: this.formatSize(file.size),
                            name: file.name,
                            clientKey
                        });
                    } catch (e) {
                        reject(e);
                    }
                };
                reader.onerror = (e) => reject(e);
                reader.readAsDataURL(file);
            } catch (e) {
                reject(e);
            }
        });
    }

    generateFileKey() {
        this.fileSequence += 1;
        return `file_${Date.now()}_${this.fileSequence}`;
    }

    refreshSystemOptions() {
        const systems = this.uniqueValues(this.categoryOptions.map((item) => item.systemValue));
        this.systemOptions = this.toPicklistOptions(systems);
        if (!systems.includes(this.systemValue)) {
            this.systemValue = '';
        }
        this.refreshTypeOptions();
    }

    refreshTypeOptions() {
        const types = this.uniqueValues(
            this.categoryOptions.filter((item) => item.systemValue === this.systemValue).map((item) => item.typeValue)
        );
        this.typeOptions = this.toPicklistOptions(types);
        if (!types.includes(this.typeValue)) {
            this.typeValue = '';
        }
        this.refreshSubtypeOptions();
    }

    refreshSubtypeOptions() {
        const subtypes = this.uniqueValues(
            this.categoryOptions
                .filter((item) => item.systemValue === this.systemValue && item.typeValue === this.typeValue)
                .map((item) => item.subtypeValue)
        );
        this.subtypeOptions = this.toPicklistOptions(subtypes);
        if (!subtypes.includes(this.subtypeValue)) {
            this.subtypeValue = '';
        }
    }

    uniqueValues(values) {
        const seen = new Set();
        const unique = [];
        values.forEach((value) => {
            const normalized = (value || '').trim();
            if (!normalized || seen.has(normalized)) {
                return;
            }
            seen.add(normalized);
            unique.push(normalized);
        });
        return unique;
    }

    toPicklistOptions(values) {
        return values.map((value) => ({ label: value, value }));
    }

    buildApexFilePayload() {
        return this.pendingFiles.map((file) => ({
            fileName: file.fileName || file.name || '',
            contentType: file.contentType || '',
            base64Data: file.base64Data || '',
            humanSize: file.humanSize || '',
            name: file.name || file.fileName || ''
        }));
    }

    formatSize(bytes) {
        if (!bytes && bytes !== 0) {
            return '';
        }
        const units = ['B', 'KB', 'MB', 'GB'];
        const index = Math.floor(Math.log(bytes) / Math.log(1024));
        return `${(bytes / Math.pow(1024, index)).toFixed(1)} ${units[index]}`;
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

    normalizeError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Erro inesperado';
    }
}