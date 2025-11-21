import { LightningElement, api, wire } from 'lwc';
import getPendings from '@salesforce/apex/ProposalPendingController.getPendings';
import getDocumentTypes from '@salesforce/apex/ProposalPendingController.getDocumentTypes';
import createPendings from '@salesforce/apex/ProposalPendingController.createPendings';
import updatePendingStatus from '@salesforce/apex/ProposalPendingController.updatePendingStatus';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

export default class ProposalPendingPanel extends LightningElement {
    @api recordId;
    pendings = [];
    isLoading = true;
    isModalOpen = false;
    isSubmitting = false;
    documentTypesLoading = false;
    hasLoadedPendings = false;
    hasLoadedDocumentTypes = false;

    documentTypeOptions = [];
    draftPendings = [];
    draftRowSeed = 0;
    wiredPendingsResult;
    channelName = '/data/ProposalPending__ChangeEvent';
    pendingsSubscription;
    isPreviewModalOpen = false;
    previewPending;
    isStatusActionRunning = false;
    isPreviewLoading = false;
    previewFileObjectUrl;
    previewIsImage = false;
    previewIsPdf = false;
    previewMode = 'file';
    previewResponseText = '';
    isRejectModalOpen = false;
    rejectReason = '';
    rejectReasonError = '';
    shouldRestorePreviewAfterReject = false;

    connectedCallback() {
        this.resetDraftRows();
        this.handleSubscribe();
    }

    // Map of status codes (API names) to labels and variants
    STATUS_MAP = {
        '1': { code: '1', label: 'Aguardando', variant: 'pending', allowActions: false },
        '2': { code: '2', label: 'Respondido', variant: 'info', allowActions: true },
        '3': { code: '3', label: 'Aprovado', variant: 'success', allowActions: false },
        '4': { code: '4', label: 'Recusado', variant: 'error', allowActions: false }
    };

    disconnectedCallback() {
        this.handleUnsubscribe();
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

    closeModal(force = false) {
        if (this.isSubmitting && !force) {
            return;
        }
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
            requestDocument: true
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
                      documentTypeId: checked ? row.documentTypeId : 0,
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

    async handleOpenPreview(event) {
        const pendingId = event.currentTarget.dataset.id;
        const pending = this.pendings.find((item) => item.id === pendingId);

        if (!pending) {
            return;
        }

        const hasFile = !!pending.fileUrl;
        const hasResponse = !!pending.response;

        if (!hasFile && !hasResponse) {
            this.showToast(
                'Conteúdo indisponível',
                'Esta pendência não possui documento ou resposta para visualização.',
                'warning'
            );
            return;
        }

        this.previewPending = pending;
        this.previewResponseText = pending.response || '';
        this.previewMode = hasFile ? 'file' : 'response';
        this.isPreviewModalOpen = true;

        if (hasFile) {
            this.preparePreviewFromUrl(pending.fileUrl);
        } else {
            this.previewFileObjectUrl = null;
            this.previewIsImage = false;
            this.previewIsPdf = false;
            this.isPreviewLoading = false;
        }
    }

    handleClosePreview() {
        if (this.isStatusActionRunning) {
            return;
        }
        this.shouldRestorePreviewAfterReject = false;
        this.closeRejectModal(false);
        this.isPreviewModalOpen = false;
        this.previewPending = null;
        this.previewMode = 'file';
        this.previewResponseText = '';
        this.previewIsImage = false;
        this.previewIsPdf = false;
        if (this.previewFileObjectUrl && this.previewFileObjectUrl.startsWith('blob:')) {
            URL.revokeObjectURL(this.previewFileObjectUrl);
        }
        this.previewFileObjectUrl = null;
    }

    preparePreviewFromUrl(fileUrl) {
        this.isPreviewLoading = true;
        this.previewIsImage = false;
        this.previewIsPdf = false;

        if (this.previewFileObjectUrl && this.previewFileObjectUrl.startsWith('blob:')) {
            URL.revokeObjectURL(this.previewFileObjectUrl);
        }

        try {
            const normalized = (fileUrl || '').toLowerCase();
            const cleanUrl = normalized.includes('?') ? normalized.substring(0, normalized.indexOf('?')) : normalized;
            this.previewIsImage =
                cleanUrl.endsWith('.png') ||
                cleanUrl.endsWith('.jpg') ||
                cleanUrl.endsWith('.jpeg') ||
                cleanUrl.endsWith('.gif');
            this.previewIsPdf = cleanUrl.endsWith('.pdf');
            this.previewFileObjectUrl = fileUrl;
        } catch (error) {
            this.handleError('Não foi possível carregar o arquivo para visualização.', error);
            this.handleClosePreview();
        } finally {
            this.isPreviewLoading = false;
        }
    }

    get previewDisplayUrl() {
        return this.previewFileObjectUrl;
    }

    get previewHasActions() {
        if (!this.previewPending) {
            return false;
        }
        const code = String(this.previewPending.statusCode || this.previewPending.status || '');
        return code === '2' || code.toLowerCase() === 'respondido';
    }

    get previewIsUnsupported() {
        if (this.previewMode !== 'file') {
            return false;
        }
        return !!this.previewFileObjectUrl && !this.previewIsImage && !this.previewIsPdf;
    }

    get isResponsePreview() {
        return this.previewMode === 'response';
    }

    get hasResponseText() {
        return !!(this.previewResponseText && this.previewResponseText.trim());
    }

    handleApprove() {
        this.handleStatusDecision('3');
    }

    handleReject() {
        if (!this.previewPending || this.isStatusActionRunning) {
            return;
        }
        this.shouldRestorePreviewAfterReject = this.isPreviewModalOpen;
        this.isPreviewModalOpen = false;
        this.rejectReason = '';
        this.rejectReasonError = '';
        this.isRejectModalOpen = true;
    }

    closeRejectModal(restorePreview = true) {
        if (this.isStatusActionRunning) {
            return;
        }
        this.isRejectModalOpen = false;
        this.rejectReason = '';
        this.rejectReasonError = '';
        if (restorePreview && this.shouldRestorePreviewAfterReject) {
            this.isPreviewModalOpen = true;
        }
        this.shouldRestorePreviewAfterReject = false;
    }

    handleRejectReasonChange(event) {
        const value = event?.detail?.value !== undefined ? event.detail.value : event.target.value;
        this.rejectReason = value || '';
        this.rejectReasonError = '';
    }

    async handleConfirmReject() {
        const textarea = this.template.querySelector('[data-id="rejectReasonInput"]');
        const currentValue = textarea ? textarea.value : this.rejectReason;
        const reasonValue = currentValue ? currentValue.trim() : '';
        if (!reasonValue) {
            this.rejectReasonError = 'Informe o motivo da recusa.';
            return;
        }
        const reason = reasonValue;
        this.rejectReason = reason;
        this.rejectReasonError = '';
        this.closeRejectModal(false);
        await this.handleStatusDecision('4', reason);
    }

    handleOpenPreviewExternally() {
        if (this.previewPending && this.previewPending.fileUrl) {
            window.open(this.previewPending.fileUrl, '_blank');
        }
    }

    async handleStatusDecision(status, descriptionRejected = null) {
        if (!this.previewPending || this.isStatusActionRunning) {
            return;
        }

        this.isStatusActionRunning = true;
        try {
            this.logDebug('updateStatusPayload', {
                pendingId: this.previewPending.id,
                status,
                descriptionRejected
            });
            await updatePendingStatus({
                pendingId: this.previewPending.id,
                status,
                descriptionRejected
            });
            const statusLabel = (this.STATUS_MAP[String(status)] || {}).label || status;
            this.showToast('Sucesso', `Pendência ${statusLabel.toLowerCase()} com sucesso.`, 'success');
            this.isPreviewModalOpen = false;
            this.previewPending = null;
            await this.refreshPendings();
        } catch (error) {
            this.handleError('Não foi possível atualizar o status.', error);
        } finally {
            this.isStatusActionRunning = false;
        }
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
            this.closeModal(true);
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

        const requestCheckboxes = this.template.querySelectorAll('lightning-input[data-field="requestDocument"]');
        requestCheckboxes.forEach((checkbox) => {
            const uid = checkbox.dataset.uid || checkbox.getAttribute('data-uid');
            if (!rowsByUid.has(uid)) {
                return;
            }
            rowsByUid.get(uid).requestDocument = checkbox.checked;
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
            requestDocument: !!row.requestDocument,
            documentTypeId: row.requestDocument ? row.documentTypeId || null : null,
            documentTypeName: row.requestDocument ? row.documentTypeName || '' : ''
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
        return pendings.map((pending) => {
            const meta = this.getStatusMeta(pending.status);
            const hasFile = !!pending.fileUrl;
            const hasResponse = (() => {
                if (!pending.response) {
                    return false;
                }
                return typeof pending.response === 'string'
                    ? !!pending.response.trim()
                    : true;
            })();
            return {
                ...pending,
                statusCode: meta.code,
                statusLabel: meta.label,
                statusVariant: meta.variant,
                allowActions: meta.allowActions,
                actionLabel: meta.allowActions ? 'Analisar' : 'Visualizar',
                showActionButton: hasFile || (meta.allowActions && hasResponse),
                cardClass: `pending-card pending-card_${meta.variant}`,
                documentTypeLabel: pending.documentTypeName || ''
            };
        });
    }

    getStatusMeta(status) {
        const value = status ? String(status) : '';
        let meta = this.STATUS_MAP[value];
        if (!meta) {
            const normalized = value.toLowerCase();
            meta = Object.values(this.STATUS_MAP).find((item) => item.label.toLowerCase() === normalized);
        }
        return (
            meta || { code: value || '', label: value || '', variant: 'pending', allowActions: false }
        );
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

    handleSubscribe() {
        if (this.pendingsSubscription || !this.channelName) {
            return;
        }

        subscribe(this.channelName, -1, (message) => this.handleCdcMessage(message))
            .then((response) => {
                this.pendingsSubscription = response;
            })
            .catch((error) => {
                this.handleError('Erro no canal de atualizações de pendências.', error, true);
            });

        onError((error) => {
            this.handleError('Erro no canal de atualizações de pendências.', error, true);
        });
    }

    handleUnsubscribe() {
        if (this.pendingsSubscription) {
            unsubscribe(this.pendingsSubscription, () => {});
            this.pendingsSubscription = null;
        }
    }

    handleCdcMessage(message) {
        try {
            const opportunityId = message?.data?.payload?.Opportunity__c;
            if (opportunityId === this.recordId) {
                this.refreshPendings();
            }
        } catch (error) {
            this.handleError('Erro ao processar atualização das pendências.', error, true);
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