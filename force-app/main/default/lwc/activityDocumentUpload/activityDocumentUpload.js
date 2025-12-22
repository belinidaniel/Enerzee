import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getRequiredDocuments from '@salesforce/apex/ActivityDocumentController.getRequiredDocuments';
import uploadExternalArchive from '@salesforce/apex/ExternalArchiveService.uploadExternalArchive';
import getTaskContext from '@salesforce/apex/ActivityDocumentController.getTaskContext';

export default class ActivityDocumentUpload extends LightningElement {
    @api recordId; // Task Id
    @api activitySubject; // override opcional
    @api activityName; // override opcional
    @track sobjectId; // projeto/instalacao/viabilidade
    @track opportunityId; // para IdProposal
    @track subject;

    @track rows = [];
    @track loading = false;

    @wire(getTaskContext, { taskId: '$recordId' })
    wiredContext({ error, data }) {
        if (data) {
            this.subject = this.activitySubject || data.subject;
            this.sobjectId = data.whatId;
            this.opportunityId = data.opportunityId;
            this.loadDocs();
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
                status: 'Pendente'
            }));
        } catch (error) {
            this.showToast('Erro', this.normalizeError(error), 'error');
        } finally {
            this.loading = false;
        }
    }

    handleFileChange(event) {
        const idx = event.target.dataset.index;
        const file = event.target.files && event.target.files[0];
        if (!file) return;

        const isPdf =
            (file.type && file.type.toLowerCase() === 'application/pdf') ||
            (file.name && file.name.toLowerCase().endsWith('.pdf'));
        if (!isPdf) {
            this.showToast('Aviso', 'Apenas arquivos PDF são aceitos para este envio.', 'warning');
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
                activityName: this.activityName || this.subject
            });
            if (result && result.success) {
                this.rows = this.rows.map(r => r.id == idx ? { ...r, status: 'Enviado' } : r);
                this.showToast('Sucesso', 'Arquivo enviado com sucesso.', 'success');
                this.dispatchEvent(new CustomEvent('uploaded'));
            } else {
                this.showToast('Erro', (result && result.message) || 'Falha ao enviar.', 'error');
            }
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
