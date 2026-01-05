import { api, LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createCase from '@salesforce/apex/ModuloHelpDeskCaseController.createCase';
import getDefaultEntities from '@salesforce/apex/ModuloHelpDeskCaseController.getDefaultEntities';
import uploadFiles from '@salesforce/apex/ModuloHelpDeskCaseController.uploadFiles';

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

    @track subject = '';
    @track description = '';
    @track typeValue = '';
    @track reasonValue = '';
    @track priorityValue = 'Medium';
    @track suppliedEmail = '';
    @track suppliedPhone = '';
    @track pendingFiles = [];
    @track readingFiles = false;

    typeOptions = [
        { label: 'Erro Salesforce', value: 'Erro Salesforce' },
        { label: 'Acesso', value: 'Acesso' },
        { label: 'Dúvida', value: 'Dúvida' }
    ];

    reasonByType = {
        'Erro Salesforce': [
            { label: 'Login', value: 'Login' },
            { label: 'Performance', value: 'Performance' },
            { label: 'Bug Visual', value: 'Bug Visual' }
        ],
        Acesso: [
            { label: 'Recuperar senha', value: 'Recuperar senha' },
            { label: '2FA', value: '2FA' }
        ],
        'Dúvida': [
            { label: 'Funcionalidade', value: 'Funcionalidade' },
            { label: 'Processo', value: 'Processo' }
        ]
    };

    priorityOptions = [
        { label: 'Alta', value: 'High' },
        { label: 'Média', value: 'Medium' },
        { label: 'Baixa', value: 'Low' }
    ];

    get reasonOptions() {
        return this.reasonByType[this.typeValue] || [];
    }

    get disableCreate() {
        return this.isSaving || this.readingFiles || !this.subject || !this.subject.trim();
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
    }

    loadDefaults(contactIdParam) {
        getDefaultEntities({ contactId: contactIdParam })
            .then((result) => {
                this.accountId = result.accountId;
                this.accountName = result.accountName;
                if (result.contactId) {
                    this._contactId = result.contactId;
                }
                this.contactName = result.contactName;
                this.suppliedEmail = result.contactEmail;
                this.suppliedPhone = result.contactPhone;
            })
            .catch((error) => {
                this.showToast('Aviso', this.normalizeError(error), 'warning');
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
        this[name] = value;
        if (name === 'typeValue') {
            this.reasonValue = '';
        }
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
            typeValue: this.typeValue,
            reasonValue: this.reasonValue,
            priorityValue: this.priorityValue,
            suppliedEmail: this.suppliedEmail,
            suppliedPhone: this.suppliedPhone,
            contactId: this.contactId,
            accountId: this.accountId
        })
            .then((result) => {
                createdId = result;
                if (this.hasFiles) {
                    return uploadFiles({ caseId: createdId, files: this.pendingFiles, contactId: this.contactId });
                }
                return null;
            })
            .then(() => {
                this.createdCaseId = createdId;
                this.showToast('Caso criado', 'Caso criado com sucesso.', 'success');
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

    resetForm() {
        this.isSaving = false;
        this.createdCaseId = null;
        this.subject = '';
        this.description = '';
        this.typeValue = '';
        this.reasonValue = '';
        this.priorityValue = 'Medium';
        this.suppliedEmail = '';
        this.suppliedPhone = '';
        this.pendingFiles = [];
        this.readingFiles = false;
    }

    handleFilesChange(event) {
        const files = event.target.files;
        console.log('Files selected:', files);
        this.readingFiles = true;
        const readers = [];
        Array.from(files).forEach((file) => {
            readers.push(
                new Promise((resolve, reject) => {
                    try {
                        const reader = new FileReader();
                        reader.onload = () => {
                            const base64 = reader.result.split(',')[1];
                            resolve({
                                fileName: file.name,
                                contentType: file.type,
                                base64Data: base64,
                                humanSize: this.formatSize(file.size),
                                name: file.name
                            });
                        };
                        reader.onerror = (e) => reject(e);
                        reader.readAsDataURL(file);
                    } catch (e) {
                        console.log('Error reading file', e);
                    }
                })
            );
        });

        Promise.all(readers)
            .then((results) => {
                this.pendingFiles = [...this.pendingFiles, ...results];
            })
            .catch((error) => {
                this.showToast('Erro ao ler arquivo', error?.message || 'Erro inesperado', 'error');
            })
            .finally(() => {
                this.readingFiles = false;
            });

        console.log('Files pendingFiles:', this.pendingFiles);

    }

    removeFile(event) {
        const name = event.currentTarget.dataset.name;
        this.pendingFiles = this.pendingFiles.filter((f) => f.name !== name);
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
