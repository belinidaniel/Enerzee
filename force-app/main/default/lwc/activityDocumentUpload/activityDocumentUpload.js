import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getRequiredDocuments from '@salesforce/apex/ActivityDocumentController.getRequiredDocuments';
import uploadExternalArchive from '@salesforce/apex/ExternalArchiveService.uploadExternalArchive';
import getAttachments from '@salesforce/apex/ActivityDocumentController.getAttachments';
import getTaskContext from '@salesforce/apex/ActivityDocumentController.getTaskContext';
import deleteAttachment from '@salesforce/apex/ActivityDocumentController.deleteAttachment';

export default class ActivityDocumentUpload extends LightningElement {
    @api recordId; // Task Id
    @api activitySubject; // override opcional
    @api activityName; // override opcional
    @track sobjectId; // projeto/instalacao/viabilidade
    @track opportunityId; // para IdProposal
    @track subject;

    @track rows = [];
    @track loading = false;
    @track existingAttachments = [];
    previewOpen = false;
    previewUrl = null;
    previewTitle = null;

    @wire(getTaskContext, { taskId: '$recordId' })
    wiredContext({ error, data }) {
        if (data) {
            this.subject = this.activitySubject || data.subject;
            this.sobjectId = data.whatId;
            this.opportunityId = data.opportunityId;
            this.loadDocs();
            this.loadExistingAttachments();
        } else if (error) {
            this.showToast('Erro', this.normalizeError(error), 'error');
        }
    }

    async loadDocs() {
        if (!this.subject) {
            return;
        }
        this.loading = true;
        try {
            const docs = await getRequiredDocuments({ activitySubject: this.subject });
            this.rows = (docs || []).map((d, index) => ({
                id: index,
                name: d.name,
                observation: d.observation,
                fileName: null,
                base64: null,
                status: 'Pendente',
                existingUrl: null,
                existingId: null
            }));
        } catch (error) {
            this.showToast('Erro', this.normalizeError(error), 'error');
        } finally {
            this.loading = false;
        }
    }

    async loadExistingAttachments() {
        if (!this.sobjectId) return;
        try {
            const attachments = await getAttachments({
                sobjectId: this.sobjectId,
                activitySubject: this.subject
            });
            this.existingAttachments = attachments || [];
            this.rows = (this.rows || []).map((r) => {
                const match = this.existingAttachments.find(
                    (att) =>
                        (att.docRequiredName && att.docRequiredName === r.name) ||
                        att.name === r.name
                );
                if (match) {
                    return {
                        ...r,
                        status: 'Enviado',
                        fileName: match.name,
                        existingUrl: match.url || match.downloadUrl,
                        existingId: match.id
                    };
                }
                return r;
            });
        } catch (error) {
            // não bloqueia UI
            // eslint-disable-next-line no-console
            console.error('Erro ao carregar anexos existentes', error);
        }
    }

    handleOpenPreview(event) {
        event.preventDefault();
        const url = event.currentTarget?.dataset?.url;
        const label = event.currentTarget?.dataset?.label;
        if (!url) {
            return;
        }
        this.previewUrl = url;
        this.previewTitle = label || 'Documento';
        this.previewOpen = true;
    }

    handleClosePreview() {
        this.previewOpen = false;
        this.previewUrl = null;
        this.previewTitle = null;
    }

    handleFileChange(event) {
        const idx = event.target.dataset.index;
        const file = event.target.files && event.target.files[0];
        if (!file) return;

        const isImage =
            (file.type && file.type.toLowerCase().startsWith('image/')) ||
            (file.name && /\.(png|jpe?g|gif|bmp|webp)$/i.test(file.name));
        if (!isImage) {
            this.showToast('Aviso', 'Apenas imagens (JPG/PNG/etc.) são aceitas para este envio.', 'warning');
            event.target.value = null; // limpa seleção
            return;
        }

        const reader = new FileReader();
        reader.onload = () => {
            const base64Body = reader.result.split(',')[1];
            const prefix = file.type ? `data:${file.type};base64,` : 'data:application/octet-stream;base64,';
            const base64 = prefix + base64Body;
            this.rows = this.rows.map(r => r.id == idx ? { ...r, fileName: file.name, base64, status: 'Pronto para enviar' } : r);
        };
        reader.readAsDataURL(file);
    }

    async handleUpload(event) {
        const idx = event.target.dataset.index;
        const row = this.rows.find(r => r.id == idx);
        if (!row || !row.base64) {
            this.showToast('Aviso', 'Selecione um arquivo antes de enviar.', 'warning');
            return;
        }
        if (!this.opportunityId) {
            this.showToast('Erro', 'opportunityId é obrigatório para enviar o arquivo.', 'error');
            return;
        }
        this.loading = true;
        try {
            const result = await uploadExternalArchive({
                opportunityId: this.opportunityId,
                fileName: row.fileName,
                base64File: row.base64,
                sobjectId: this.sobjectId,
                activityName: this.activityName || this.subject,
                docRequiredName: row.name
            });
            if (result && result.success) {
                if (row.existingId && result.attachmentId && row.existingId !== result.attachmentId) {
                    try {
                        await deleteAttachment({ attachmentId: row.existingId });
                    } catch (deleteError) {
                        // eslint-disable-next-line no-console
                        console.warn('Erro ao remover anexo antigo', deleteError);
                    }
                }
                this.rows = this.rows.map(r => r.id == idx ? { ...r, status: 'Enviado' } : r);
                this.showToast('Sucesso', 'Arquivo enviado com sucesso.', 'success');
                this.dispatchEvent(new CustomEvent('uploaded'));
                await this.loadExistingAttachments();
            } else {
                this.showToast('Erro', (result && result.message) || 'Falha ao enviar.', 'error');
            }
        } catch (error) {
            this.showToast('Erro', this.normalizeError(error), 'error');
        } finally {
            this.loading = false;
        }
    }

    async handleRemove(event) {
        const idx = event.target.dataset.index;
        const row = this.rows.find(r => r.id == idx);
        if (!row || !row.existingId) {
            return;
        }
        this.loading = true;
        try {
            const removed = await deleteAttachment({ attachmentId: row.existingId });
            if (removed) {
                this.showToast('Sucesso', 'Arquivo removido.', 'success');
            } else {
                this.showToast('Aviso', 'Arquivo não encontrado para remoção.', 'warning');
            }
            await this.loadExistingAttachments();
            this.rows = this.rows.map(r => r.id == idx ? { ...r, existingUrl: null, existingId: null, status: 'Pendente' } : r);
        } catch (error) {
            this.showToast('Erro', this.normalizeError(error), 'error');
        } finally {
            this.loading = false;
        }
    }

    get showTable() {
        return (this.rows || []).length > 0;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    normalizeError(error) {
        if (!error) return 'Erro desconhecido';
        if (Array.isArray(error.body)) {
            return error.body.map(e => e.message).join(', ');
        } else if (error.body && error.body.message) {
            return error.body.message;
        }
        return error.message || JSON.stringify(error);
    }
}
