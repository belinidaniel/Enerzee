import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAttachments from '@salesforce/apex/ActivityDocumentController.getAttachments';

export default class AttachmentTabs extends LightningElement {
    @api recordId;
    @api sobjectId;
    @track groups = [];
    @track loading = false;
    activeTab;
    selectedGroupName;
    isFileModalOpen = false;
    filePreviewName;
    filePreviewUrl;
    filePreviewIsPdf = false;
    filePreviewIsImage = false;
    isAttachmentPreviewLoading = false;
    isGeneratingPdf = false;
    error;

    connectedCallback() {
        this.load();
    }

    get targetId() {
        return this.sobjectId || this.recordId;
    }

    async load() {
        if (!this.targetId) return;
        this.loading = true;
        try {
            const items = await getAttachments({ sobjectId: this.targetId, activitySubject: null });
            const mapGroups = {};
            (items || []).forEach((it) => {
                const key = it.activityName || 'Outros';
                if (!mapGroups[key]) {
                    mapGroups[key] = [];
                }
                mapGroups[key].push(this.formatAttachment(it));
            });
            this.groups = Object.keys(mapGroups)
                .sort()
                .map((name) => ({
                    name,
                    items: mapGroups[name]
                }));
            if (!this.activeTab && this.groups.length) {
                this.activeTab = this.groups[0].name;
                this.selectedGroupName = this.groups[0].name;
            }
        } catch (error) {
            // eslint-disable-next-line no-console
            console.error(error);
            this.error = error;
        } finally {
            this.loading = false;
        }
    }

    get hasData() {
        return (this.groups || []).length > 0;
    }

    get isGenerateDisabled() {
        return !this.targetId || !this.selectedGroupName || this.isGeneratingPdf;
    }

    get isRelatorioFinalSelected() {
        return this.isRelatorioFinalSubject(this.selectedGroupName);
    }

    get generateButtonLabel() {
        return this.isGeneratingPdf ? 'Gerando...' : 'Gerar PDF';
    }

    handleTabChange(event) {
        this.activeTab = event.detail.value;
    }

    handleNavSelect(event) {
        this.selectedGroupName = event.detail.name;
    }

    get selectedGroup() {
        if (!this.selectedGroupName) {
            return null;
        }
        return (this.groups || []).find((g) => g.name === this.selectedGroupName) || null;
    }

    handlePreviewFile(event) {
        const recordId = event.currentTarget?.dataset?.id;
        const group = event.currentTarget?.dataset?.group;
        if (!recordId || !group) {
            return;
        }
        const groupData = (this.groups || []).find((g) => g.name === group);
        if (!groupData) {
            return;
        }
        const file = (groupData.items || []).find((item) => item.id === recordId);
        if (!file) {
            return;
        }

        this.filePreviewName = file.name;
        this.prepareAttachmentPreview(file.url);
        console.log('Opening file preview for', file.name, file.url);
        this.isFileModalOpen = true;
    }

    closeFileModal() {
        this.isFileModalOpen = false;
        this.filePreviewUrl = null;
        this.filePreviewIsPdf = false;
        this.filePreviewIsImage = false;
        this.filePreviewName = null;
    }

    openFile(event) {
        const url = event.currentTarget?.dataset?.url;
        if (url) {
            window.open(url, '_blank');
        }
    }

    async handleGeneratePdf() {
        if (!this.targetId) {
            this.showToast('Erro', 'Registro não identificado para gerar PDF.', 'error');
            return;
        }
        if (!this.selectedGroupName) {
            this.showToast('Aviso', 'Selecione uma atividade para gerar o PDF.', 'warning');
            return;
        }
        this.isGeneratingPdf = true;
        try {
            const pdfUrl = this.buildPdfUrl();
            window.open(pdfUrl, '_blank');
        } catch (error) {
            this.showToast('Erro', this.normalizeError(error), 'error');
        } finally {
            this.isGeneratingPdf = false;
        }
    }

    handlePreviewPdf() {
        if (!this.targetId) {
            this.showToast('Erro', 'Registro não identificado para pré-visualizar.', 'error');
            return;
        }
        if (!this.selectedGroupName) {
            this.showToast('Aviso', 'Selecione uma atividade para pré-visualizar.', 'warning');
            return;
        }
        const pdfUrl = this.buildPdfUrl();
        this.filePreviewName = `Relatório - ${this.selectedGroupName}`;
        this.filePreviewUrl = pdfUrl;
        this.filePreviewIsPdf = true;
        this.filePreviewIsImage = false;
        this.isAttachmentPreviewLoading = false;
        this.isFileModalOpen = true;
    }

    formatAttachment(record) {
        const date = record.createdDate ? new Date(record.createdDate) : null;
        const formatter = new Intl.DateTimeFormat('pt-BR', {
            dateStyle: 'medium',
            timeStyle: 'medium'
        });
        const displayMeta = date ? formatter.format(date) : '';
        const docRequiredName = record.docRequiredName;
        const iconName = 'doctype:attachment';

        return {
            id: record.id,
            name: record.name,
            activityName: record.activityName || 'Outros',
            url: record.url || record.downloadUrl,
            displayMeta,
            iconName,
            docRequiredName
        };
    }

    prepareAttachmentPreview(url) {
        this.isAttachmentPreviewLoading = true;
        this.filePreviewIsImage = false;
        this.filePreviewIsPdf = false;
        this.filePreviewUrl = null;

        try {
            const rawUrl = (url || '').trim();
            this.filePreviewUrl = rawUrl || null;

            if (rawUrl) {
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
            }
        } catch (error) {
            this.filePreviewUrl = null;
        } finally {
            this.isAttachmentPreviewLoading = false;
        }
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

    buildPdfUrl() {
        const base = '/apex/WorkDeliveryReportPdf';
        const params = new URLSearchParams({
            sobjectId: this.targetId,
            activityName: this.selectedGroupName
        });
        return `${base}?${params.toString()}`;
    }

    isRelatorioFinalSubject(value) {
        return this.normalizeSubject(value) === 'RELATORIO FINAL DE OBRA';
    }

    normalizeSubject(value) {
        if (!value) return '';
        try {
            return value
                .toString()
                .trim()
                .normalize('NFD')
                .replace(/[\u0300-\u036f]/g, '')
                .toUpperCase();
        } catch (error) {
            return value.toString().trim().toUpperCase();
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    normalizeError(error) {
        if (!error) return 'Erro desconhecido';
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        } else if (error.body && error.body.message) {
            return error.body.message;
        }
        return error.message || JSON.stringify(error);
    }
}