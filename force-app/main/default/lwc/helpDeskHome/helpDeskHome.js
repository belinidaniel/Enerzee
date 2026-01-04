import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createCase from '@salesforce/apex/ModuloHelpDeskCaseController.createCase';
import getDefaultEntities from '@salesforce/apex/ModuloHelpDeskCaseController.getDefaultEntities';

export default class HelpDeskHome extends LightningElement {
    @track showModal = false;
    @track isSaving = false;
    @track createdCaseId;
    @track contactName;
    contactId;
    @track accountName;
    accountId;

    @track subject = '';
    @track description = '';
    @track typeValue = '';
    @track reasonValue = '';
    @track priorityValue = 'Medium';
    @track suppliedEmail = '';
    @track suppliedPhone = '';

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

    get primaryButtonLabel() {
        return this.createdCaseId ? 'Salvar anexos' : 'Criar caso';
    }

    get disableCreate() {
        return this.isSaving || !this.subject || !this.subject.trim();
    }

    get disableUpload() {
        return !this.createdCaseId;
    }

    get uploadHelperText() {
        return this.createdCaseId ? 'Anexe documentos que serão vinculados ao caso.' : 'Crie o caso para habilitar o envio de anexos.';
    }

    connectedCallback() {
        this.loadDefaults();
    }

    loadDefaults() {
        getDefaultEntities()
            .then((result) => {
                this.contactId = result.contactId;
                this.contactName = result.contactName;
                this.accountId = result.accountId;
                this.accountName = result.accountName;
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
        if (this.disableCreate || this.createdCaseId) {
            return;
        }
        this.isSaving = true;
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
                this.createdCaseId = result;
                this.showToast('Caso criado', 'Caso criado com sucesso. Adicione anexos se necessário.', 'success');
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
