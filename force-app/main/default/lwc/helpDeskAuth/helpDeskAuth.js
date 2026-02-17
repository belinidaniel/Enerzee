import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import requestAccessCode from '@salesforce/apex/ModuloHelpDeskCaseController.requestAccessCode';
import validateAccessCode from '@salesforce/apex/ModuloHelpDeskCaseController.validateAccessCode';

export default class HelpDeskAuth extends LightningElement {
    storageKey = 'helpDeskContactId';
    @track email = '';
    @track code = '';
    @track firstName = '';
    @track lastName = '';
    @track mobilePhone = '';
    @track showRegister = false;
    @track showSuccessModal = false;
    @track contactId;
    isRequesting = false;
    isValidating = false;

    connectedCallback() {
        // Auto-restores an authenticated session if a contactId was cached.
        const cached = window?.localStorage?.getItem(this.storageKey);
        if (cached) {
            this.setAuthenticated(cached);
        }
    }

    handleInputChange(event) {
        const { name, value } = event.target;
        this[name] = value;
    }

    handleToggleRegister() {
        this.showRegister = !this.showRegister;
    }

    handleRegister() {
        if (!this.email) {
            this.showToast('Informe seu e-mail', 'E-mail é obrigatório.', 'warning');
            return;
        }
        if (!this.firstName || !this.lastName) {
            this.showToast('Informe nome e sobrenome', 'Preencha os campos de registro.', 'warning');
            return;
        }
        this.isRequesting = true;
        requestAccessCode({ email: this.email, firstName: this.firstName, lastName: this.lastName, mobilePhone: this.mobilePhone })
            .then(() => {
                this.showSuccessModal = true;
            })
            .catch((error) => {
                this.showToast('Erro ao registrar', this.normalizeError(error), 'error');
            })
            .finally(() => {
                this.isRequesting = false;
            });
    }

    handleValidateCode() {
        if (!this.email || !this.code) {
            this.showToast('Informe e-mail e código', 'Ambos são obrigatórios.', 'warning');
            return;
        }
        this.isValidating = true;
        validateAccessCode({ email: this.email, code: this.code })
            .then((cid) => {
                if (!cid) {
                    throw new Error('Código inválido ou contato não retornado.');
                }
                this.setAuthenticated(cid);
            })
            .catch((error) => {
                this.showToast('Erro ao validar código', this.normalizeError(error), 'error');
            })
            .finally(() => {
                this.isValidating = false;
            });
    }

    handleCloseModal() {
        this.showSuccessModal = false;
        this.showRegister = false;
        this.firstName = '';
        this.lastName = '';
        this.mobilePhone = '';
    }

    setAuthenticated(cid) {
        this.contactId = cid;
        // Persist contactId for future visits.
        try {
            window.localStorage.setItem(this.storageKey, cid);
        } catch (e) {
            // Swallow storage errors (private browsing, etc.)
        }
        this.dispatchEvent(
            new CustomEvent('authenticated', {
                detail: { contactId: cid },
                bubbles: true,
                composed: true
            })
        );
        this.showRegister = false;
        this.code = '';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant: variant || 'info',
                mode: 'dismissable'
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