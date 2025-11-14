import { LightningElement, api, wire } from 'lwc';
import getPendings from '@salesforce/apex/ProposalPendingController.getPendings';
import getDocumentTypes from '@salesforce/apex/ProposalPendingController.getDocumentTypes';
import createPendings from '@salesforce/apex/ProposalPendingController.createPendings';
import updatePendingStatus from '@salesforce/apex/ProposalPendingController.updatePendingStatus';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

const STATUS_DECISION_OPTIONS = Object.freeze([
    { label: 'Aprovar', value: 'Aprovado' },
    { label: 'Recusar', value: 'Recusado' }
]);

export default class ProposalPendingPanel extends LightningElement {
    @api recordId;
    pendings = [];
    isLoading = true;
    isModalOpen = false;
    isSubmitting = false;
    documentTypesLoading = false;
    statusUpdatingId;
    hasLoadedPendings = false;
    hasLoadedDocumentTypes = false;

    documentTypeOptions = [];
    draftPendings = [];
    draftRowSeed = 0;
    wiredPendingsResult;
    statusDecisionOptions = STATUS_DECISION_OPTIONS;

    connectedCallback() {
        this.resetDraftRows();
    }


    get hasPendings() {
        return this.pendings && this.pendings.length > 0;
    }

    get draftRows() {
        return this.draftPendings.map((row) => ({
            ...row,
            documentInputDisabled: !row.requestDocument || this.documentTypesLoading
        }));
    }

    @wire(getPendings, { opportunityId: '$recordId' })
    wiredPendings(result) {
        this.wiredPendingsResult = result;
        const { error, data } = result;
        if (data) {
            this.hasLoadedPendings = true;
            this.isLoading = false;
            this.pendings = this.decoratePendings(Array.isArray(data) ? data : []);
        } else if (error) {
            this.isLoading = false;
            this.handleError('Não foi possível carregar as pendências.', error);
        }
    }

    @wire(getDocumentTypes)
    wiredDocTypes({ error, data }) {
        if (data && !this.hasLoadedDocumentTypes) {
            this.documentTypeOptions = (data || []).map((item) => ({
                label: item.name,
                value: String(item.id),
                raw: item
            }));
            this.hasLoadedDocumentTypes = true;
        } else if (error) {
            this.handleError('Não foi possível carregar os tipos de documento.', error);
        }
    }

    get disableRemoveButton() {
        return this.draftPendings.length === 1;
    }

    get isModalSaveDisabled() {
        return this.isSubmitting || this.documentTypesLoading;
    }

    handleNewClick() {
        this.isModalOpen = true;
        this.resetDraftRows();
        this.ensureDocumentTypes();
    }

    closeModal() {
        this.isModalOpen = false;
    }

    resetDraftRows() {
        this.draftPendings = [this.createDraftRow()];
    }

    createDraftRow() {
        this.draftRowSeed += 1;
        return {
            uid: `draft-${this.draftRowSeed}`,
            description: '',
            documentTypeId: null,
            documentTypeName: '',
            requestDocument: false
        };
    }

    async ensureDocumentTypes() {
        if (this.documentTypeOptions.length > 0) {
            return;
        }

        this.documentTypesLoading = true;
        try {
            const types = await getDocumentTypes();
            this.documentTypeOptions = (types || []).map((item) => ({
                label: item.name,
                value: String(item.id),
                raw: item
            }));
        } catch (error) {
            this.handleError('Não foi possível carregar os tipos de documento.', error);
            this.closeModal();
        } finally {
            this.documentTypesLoading = false;
        }
    }

    handleDraftDescriptionChange(event) {
        const uid = event.currentTarget.dataset.uid || event.currentTarget.getAttribute('data-uid');
        const value = event.target.value;
        this.draftPendings = this.draftPendings.map((row) =>
            row.uid === uid ? { ...row, description: value } : row
        );
    }

    handleDraftDocumentTypeChange(event) {
        const uid = event.currentTarget.dataset.uid || event.currentTarget.getAttribute('data-uid');
        const value = event.detail.value;
        const option = this.documentTypeOptions.find((opt) => opt.value === value);
        this.draftPendings = this.draftPendings.map((row) =>
            row.uid === uid
                ? {
                      ...row,
                      documentTypeId: value,
                      documentTypeName: option ? option.label : ''
                  }
                : row
        );
    }

    handleDraftRequestDocumentChange(event) {
        const uid = event.currentTarget.dataset.uid || event.currentTarget.getAttribute('data-uid');
        const checked = event.target.checked;
        this.draftPendings = this.draftPendings.map((row) =>
            row.uid === uid
                ? {
                      ...row,
                      requestDocument: checked,
                      documentTypeId: checked ? row.documentTypeId : null,
                      documentTypeName: checked ? row.documentTypeName : ''
                  }
                : row
        );
    }

    handleAddDraftRow() {
        this.draftPendings = [...this.draftPendings, this.createDraftRow()];
    }

    handleRemoveDraftRow(event) {
        if (this.draftPendings.length === 1) {
            return;
        }

        const uid = event.currentTarget.dataset.uid || event.currentTarget.getAttribute('data-uid');
        this.draftPendings = this.draftPendings.filter((row) => row.uid !== uid);
    }

    async handleSavePendings() {
        if (this.isSubmitting) {
            return;
        }

        const formRows = this.collectRowsFromDom();
        this.logDebug('rowsFromDom', formRows);

        const validationError = this.validateRows(formRows);
        if (validationError) {
            this.showToast('Validação', validationError, 'error');
            return;
        }

        this.isSubmitting = true;
        try {
            const payload = formRows.map((row) => ({
                description: row.description.trim(),
                documentTypeId: row.documentTypeId ? parseInt(row.documentTypeId, 10) : null,
                documentTypeName: row.documentTypeName,
                requestDocument: !!row.requestDocument
            }));

            this.logDebug('payload', payload);

            await createPendings({
                opportunityId: this.recordId,
                pendingInputsJson: JSON.stringify(payload)
            });

            this.showToast('Sucesso', 'Pendências enviadas para o aplicativo.', 'success');
            await this.refreshPendings();
            this.resetDraftRows();
            this.closeModal();
        } catch (error) {
            this.handleError('Não foi possível salvar as pendências.', error);
        } finally {
            this.isSubmitting = false;
        }
    }

    collectRowsFromDom() {
        const rowsByUid = new Map();
        this.draftPendings.forEach((row) => {
            rowsByUid.set(row.uid, { ...row });
        });

        const descriptionInputs = this.template.querySelectorAll('lightning-input[data-field="description"]');
        descriptionInputs.forEach((input) => {
            const uid = input.dataset.uid || input.getAttribute('data-uid');
            if (!rowsByUid.has(uid)) {
                return;
            }
            rowsByUid.get(uid).description = input.value || '';
        });

        const documentCombos = this.template.querySelectorAll('lightning-combobox[data-field="documentType"]');
        documentCombos.forEach((combo) => {
            const uid = combo.dataset.uid || combo.getAttribute('data-uid');
            if (!rowsByUid.has(uid)) {
                return;
            }
            rowsByUid.get(uid).documentTypeId = combo.value || null;
            const option = this.documentTypeOptions.find((opt) => opt.value === combo.value);
            rowsByUid.get(uid).documentTypeName = option ? option.label : '';
        });

        return Array.from(rowsByUid.values()).map((row) => ({
            description: row.description || '',
            documentTypeId: row.documentTypeId || null,
            documentTypeName: row.documentTypeName || '',
            requestDocument: !!row.requestDocument
        }));
    }

    validateRows(rows) {
        for (const row of rows) {
            if (!row.description || !row.description.trim()) {
                return 'Informe a descrição de todas as pendências.';
            }
            if (row.requestDocument && !row.documentTypeId) {
                return 'Selecione o tipo de documento para todas as pendências que solicitarem arquivos.';
            }
        }
        return null;
    }

    decoratePendings(pendings) {
        return pendings.map((pending) => ({
            ...pending,
            requiresDecision: pending.status === 'Respondido',
            decisionValue: null,
            isUpdating: false,
            statusVariant: this.getStatusVariant(pending.status)
        }));
    }

    getStatusVariant(status) {
        const normalized = (status || '').toLowerCase();
        if (normalized === 'respondido' || normalized === 'aprovado') {
            return 'success';
        }
        if (normalized === 'recusado' || normalized === 'reprovado') {
            return 'error';
        }
        return 'pending';
    }

    async refreshPendings() {
        if (this.wiredPendingsResult) {
            try {
                await refreshApex(this.wiredPendingsResult);
            } catch (error) {
                this.handleError('Não foi possível atualizar as pendências.', error);
            }
        }
    }

    handleError(message, error, silent = false) {
        // eslint-disable-next-line no-console
        console.error(message, error);
        if (!silent) {
            const detail = error && error.body && error.body.message ? error.body.message : message;
            this.showToast('Erro', detail, 'error');
        }
    }

    logDebug(label, data) {
        try {
            // eslint-disable-next-line no-console
            console.log(`ProposalPendingPanel - ${label}`, JSON.stringify(data));
        } catch (e) {
            // ignore logging errors
        }
    }

    async handleDecisionChange(event) {
        const pendingId = event.currentTarget.dataset.pendingId;
        const value = event.detail.value;
        if (!pendingId) {
            return;
        }

        this.updatePendingLocally(pendingId, { decisionValue: value });

        if (!value) {
            return;
        }

        this.statusUpdatingId = pendingId;
        this.updatePendingLocally(pendingId, { isUpdating: true });

        try {
            await updatePendingStatus({ pendingId, status: value });
            this.showToast('Sucesso', 'Status atualizado.', 'success');
            await this.refreshPendings();
        } catch (error) {
            this.handleError('Não foi possível atualizar o status da pendência.', error);
            this.updatePendingLocally(pendingId, { decisionValue: null });
        } finally {
            this.statusUpdatingId = null;
            this.updatePendingLocally(pendingId, { isUpdating: false });
        }
    }

    updatePendingLocally(pendingId, changes) {
        this.pendings = this.pendings.map((pending) =>
            pending.id === pendingId ? { ...pending, ...changes } : pending
        );
    }

    handleAttachmentClick(event) {
        const url = event.currentTarget.dataset.url;
        if (url) {
            window.open(url, '_blank');
        }
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
}
