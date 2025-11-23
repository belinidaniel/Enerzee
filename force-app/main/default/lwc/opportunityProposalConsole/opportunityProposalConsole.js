import { LightningElement, api, wire } from 'lwc';
import loadProposalData from '@salesforce/apex/ProposalConsoleController.loadProposalData';
import sendProposal from '@salesforce/apex/ProposalConsoleController.sendProposal';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

export default class OpportunityProposalConsole extends LightningElement {
    @api recordId;

    proposalData;
    proposalAttachments = [];
    otherAttachments = [];
    wiredResult;
    selectedTemplateId;
    previewUrl;
    isModalOpen = false;
    isSendMode = false;
    isLoading = true;
    isProcessing = false;
    isPreviewLoading = false;
    proposalVisibleCount = 0;
    otherVisibleCount = 0;
    activeTab = 'proposal';
    isFileModalOpen = false;
    filePreviewUrl;
    filePreviewName;
    fileDownloadUrl;
    filePreviewIsPdf = false;
    filePreviewIsImage = false;
    isAttachmentPreviewLoading = false;
    error;
    subscription = null;
    channelName = '/data/OpportunityAttachmentLink__ChangeEvent';
    refreshTimer = null;
    refreshAttempts = 0;

    connectedCallback() {
        this.subscribeToAttachmentChanges();
        this.registerEmpError();
    }

    disconnectedCallback() {
        this.unsubscribeFromAttachmentChanges();
        this.clearScheduledRefresh();
    }

    @wire(loadProposalData, { opportunityId: '$recordId' })
    wiredProposals(result) {
        this.wiredResult = result;
        const { data, error } = result;

        if (data) {
            this.error = undefined;
            this.proposalData = data;
            this.proposalAttachments = this.formatAttachments(data.proposalFiles || [], 'proposal');
            this.otherAttachments = this.formatAttachments(data.otherFiles || [], 'other');
            this.proposalVisibleCount = this.proposalAttachments.length > 0 ? Math.min(4, this.proposalAttachments.length) : 0;
            this.otherVisibleCount = this.otherAttachments.length > 0 ? Math.min(4, this.otherAttachments.length) : 0;
            this.updatePreviewUrl();
        } else if (error) {
            this.error = this.reduceError(error);
            this.proposalData = undefined;
            this.proposalAttachments = [];
            this.otherAttachments = [];
        }

        this.isLoading = false;
    }

    get hasProposalAttachments() {
        return this.proposalAttachments.length > 0;
    }

    get hasOtherAttachments() {
        return this.otherAttachments.length > 0;
    }

    get proposalFiles() {
        const count = this.proposalVisibleCount || this.proposalAttachments.length;
        return this.proposalAttachments.slice(0, count);
    }

    get otherFiles() {
        const count = this.otherVisibleCount || this.otherAttachments.length;
        return this.otherAttachments.slice(0, count);
    }

    get canLoadMoreProposals() {
        return this.proposalAttachments.length > this.proposalVisibleCount;
    }

    get canLoadMoreOthers() {
        return this.otherAttachments.length > this.otherVisibleCount;
    }

    get hasTemplates() {
        return (this.proposalData?.templates || []).length > 0;
    }

    get emptyProposalMessage() {
        const label = this.modeLabelSingular.toLowerCase();
        return `Nenhuma ${label} disponível ainda.`;
    }

    get templateOptions() {
        const options = (this.proposalData?.templates || []).map((template) => ({
            label: template.label,
            value: template.id
        }));
        options.unshift({
            label: 'Selecione um modelo',
            value: ''
        });
        return options;
    }

    get comboboxValue() {
        return this.selectedTemplateId || '';
    }

    get disableActions() {
        return !this.hasTemplates || this.isProcessing;
    }

    get disablePrimaryAction() {
        return !this.selectedTemplateId || this.isProcessing;
    }

    get isViabilityMode() {
        return this.proposalData?.hasViability === true;
    }

    get modeLabelSingular() {
        return this.isViabilityMode ? 'Readequação' : 'Proposta';
    }

    get modeLabelPlural() {
        return this.isViabilityMode ? 'Readequações' : 'Propostas';
    }

    get viewButtonLabel() {
        return this.isViabilityMode ? 'Visualizar readequação' : 'Visualizar proposta';
    }

    get sendButtonLabel() {
        return this.isViabilityMode ? 'Enviar readequação' : 'Enviar proposta';
    }

    get modalTitle() {
        return this.isSendMode ? this.sendButtonLabel : this.viewButtonLabel;
    }

    handleOpenPreview() {
        this.isSendMode = false;
        this.openModal();
    }

    handleOpenSend() {
        this.isSendMode = true;
        this.openModal();
    }

    openModal() {
        this.isModalOpen = true;
        this.updatePreviewUrl();
    }

    closeModal() {
        this.isModalOpen = false;
        this.isSendMode = false;
        this.previewUrl = null;
        this.isPreviewLoading = false;
        this.selectedTemplateId = null;
    }

    handleTemplateChange(event) {
        const selectedValue = event.detail.value;
        this.selectedTemplateId = selectedValue || null;
        this.updatePreviewUrl();
    }

    updatePreviewUrl() {
        if (!this.selectedTemplateId) {
            this.previewUrl = null;
            this.isPreviewLoading = false;
            return;
        }

        const template = (this.proposalData?.templates || []).find(
            (item) => item.id === this.selectedTemplateId
        );

        this.previewUrl = template
            ? `/apex/${template.templateName}?id=${this.recordId}&selectedCoverId=${template.id}&isManual=true&skipAutoSave=true`
            : null;
        this.isPreviewLoading = !!this.previewUrl;
    }

    handleIframeLoad() {
        this.isPreviewLoading = false;
    }

    handlePreviewFile(event) {
        const recordId = event.currentTarget?.dataset?.id;
        const collection = event.currentTarget?.dataset?.collection;
        if (!recordId) {
            return;
        }
        const source = collection === 'other' ? this.otherAttachments : this.proposalAttachments;
        const file = source.find((item) => item.id === recordId);
        if (!file) {
            return;
        }

        const previewSupported = this.prepareAttachmentPreview(file.previewUrl || file.downloadUrl);
        if (!previewSupported) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Download iniciado',
                    message: 'O arquivo foi baixado na sua máquina.',
                    variant: 'info'
                })
            );
            window.open(file.downloadUrl, '_blank');
            return;
        }

        this.filePreviewName = file.title;
        this.fileDownloadUrl = file.downloadUrl;
        this.isFileModalOpen = true;
    }

    closeFileModal() {
        this.isFileModalOpen = false;
        this.filePreviewUrl = null;
        this.filePreviewIsPdf = false;
        this.filePreviewIsImage = false;
        this.filePreviewName = null;
        this.fileDownloadUrl = null;
    }

    downloadCurrentFile() {
        if (this.fileDownloadUrl) {
            window.open(this.fileDownloadUrl, '_blank');
        }
    }

    handleLoadMore(event) {
        const collection = event.currentTarget?.dataset?.collection || 'proposal';
        if (collection === 'other') {
            if (this.otherVisibleCount < this.otherAttachments.length) {
                this.otherVisibleCount = Math.min(this.otherVisibleCount + 4, this.otherAttachments.length);
            }
        } else if (this.proposalVisibleCount < this.proposalAttachments.length) {
            this.proposalVisibleCount = Math.min(this.proposalVisibleCount + 4, this.proposalAttachments.length);
        }
    }

    handleTabChange(event) {
        this.activeTab = event.detail.value;
    }

    handleSendProposal() {
        if (!this.selectedTemplateId) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Selecione um modelo',
                    message: 'É necessário escolher um modelo antes de enviar.',
                    variant: 'error'
                })
            );
            return;
        }

        this.isProcessing = true;
        this.isLoading = true;

        // Oculta modal mas mantém estado para reabrir em caso de falha.
        this.isModalOpen = false;

        sendProposal({
            opportunityId: this.recordId,
            coverId: this.selectedTemplateId
        })
            .then((result) => {
                const success = result?.success !== false;
                const variant = success ? 'success' : 'error';
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: success ? 'Sucesso' : 'Falha ao enviar',
                        message: result?.message || 'Proposta enviada.',
                        variant
                    })
                );
                // Refresh imediato; agenda novos refreshes para capturar anexos assíncronos.
                this.scheduleRefresh();
                return refreshApex(this.wiredResult);
            })
            .catch((error) => {
                // Reabre a modal em caso de falha.
                this.isModalOpen = true;
                this.isSendMode = true;
                const message = this.reduceError(error);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Erro ao enviar proposta',
                        message,
                        variant: 'error'
                    })
                );
                this.error = message;
            })
            .finally(() => {
                this.isProcessing = false;
                this.isLoading = false;
            });
    }

    subscribeToAttachmentChanges() {
        if (this.subscription || !this.channelName) {
            return;
        }

        const callback = (message) => {
            const payload = message?.data?.payload;
            const changeType = payload?.ChangeEventHeader?.changeType;
            const opportunityId = payload?.OpportunityId__c;

            if (changeType === 'CREATE' && opportunityId === this.recordId) {
                refreshApex(this.wiredResult);
            }
        };

        subscribe(this.channelName, -1, callback).then((response) => {
            this.subscription = response;
        });
    }

    unsubscribeFromAttachmentChanges() {
        if (this.subscription) {
            unsubscribe(this.subscription, () => {
                this.subscription = null;
            });
        }
    }

    registerEmpError() {
        onError((error) => {
            // Apenas loga; não interrompe fluxo principal.
            // eslint-disable-next-line no-console
            console.error('EMP API error: ', JSON.stringify(error));
        });
    }

    scheduleRefresh() {
        this.clearScheduledRefresh();
        this.refreshAttempts = 0;
        this.refreshTimer = window.setInterval(() => {
            this.refreshAttempts += 1;
            refreshApex(this.wiredResult);

            // Faz 3 tentativas espaçadas (3 x 4s).
            if (this.refreshAttempts >= 3) {
                this.clearScheduledRefresh();
            }
        }, 2000);
    }

    clearScheduledRefresh() {
        if (this.refreshTimer) {
            window.clearInterval(this.refreshTimer);
            this.refreshTimer = null;
        }
        this.refreshAttempts = 0;
    }

    openFile(event) {
        const url = event.currentTarget.dataset.url;
        if (url) {
            window.open(url, '_blank');
        }
    }

    formatAttachments(records, collection) {
        return records.map((record) => {
            const date = record.createdDate ? new Date(record.createdDate) : null;
            const formatter = new Intl.DateTimeFormat('pt-BR', {
                dateStyle: 'medium',
                timeStyle: 'short'
            });
            const displayParts = [];
            if (date) {
                displayParts.push(formatter.format(date));
            }
            if (record.fileType) {
                displayParts.push(record.fileType);
            }

            const iconName =
                (record.fileType || '').toLowerCase() === 'proposal'
                    ? 'doctype:pdf'
                    : 'doctype:attachment';

            return {
                id: record.recordId,
                title: record.title,
                description: record.description,
                downloadUrl: record.downloadUrl,
                createdDate: record.createdDate,
                displayMeta: displayParts.join(' • '),
                fileType: this.isViabilityMode && collection === 'proposal' ? 'Readequação' : record.fileType,
                iconName,
                collection,
                previewUrl: record.downloadUrl
            };
        });
    }

    prepareAttachmentPreview(url) {
        this.isAttachmentPreviewLoading = true;
        this.filePreviewIsImage = false;
        this.filePreviewIsPdf = false;
        this.filePreviewUrl = null;

        let previewSupported = false;

        try {
            const rawUrl = (url || '').trim();
            const normalized = rawUrl.toLowerCase();
            const cleanUrl = normalized.includes('?')
                ? normalized.substring(0, normalized.indexOf('?'))
                : normalized;

            this.filePreviewIsImage =
                cleanUrl.endsWith('.png') ||
                cleanUrl.endsWith('.jpg') ||
                cleanUrl.endsWith('.jpeg') ||
                cleanUrl.endsWith('.gif');
            this.filePreviewIsPdf = cleanUrl.endsWith('.pdf');

            if (this.filePreviewIsPdf || this.filePreviewIsImage) {
                this.filePreviewUrl = rawUrl;
                previewSupported = !!this.filePreviewUrl;
            } else {
                this.filePreviewUrl = null;
            }
        } catch (error) {
            this.error = this.reduceError(error);
            this.filePreviewUrl = null;
        } finally {
            this.isAttachmentPreviewLoading = false;
        }

        return previewSupported;
    }

    get filePreviewIsUnsupported() {
        return (
            !this.isAttachmentPreviewLoading &&
            this.filePreviewUrl &&
            !this.filePreviewIsPdf &&
            !this.filePreviewIsImage
        );
    }

    get hasPreviewUrl() {
        return !!this.filePreviewUrl;
    }

    reduceError(error) {
        if (!error) {
            return 'Erro inesperado.';
        }

        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }

        if (typeof error.body?.message === 'string') {
            return error.body.message;
        }

        return error.message || 'Erro inesperado.';
    }
}
