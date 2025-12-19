import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getRequiredDocuments from '@salesforce/apex/ActivityDocumentController.getRequiredDocuments';
import uploadExternalArchive from '@salesforce/apex/ExternalArchiveService.uploadExternalArchive';

export default class ActivityDocumentUpload extends LightningElement {
    @api activitySubject; // texto do subject da atividade
    @api activityName; // nome para salvar no Attachment
    @api sobjectId; // projeto/instalacao/viabilidade
    @api opportunityId; // necessário para IdProposal

    @track rows = [];
    @track loading = false;

    connectedCallback() {
        this.loadDocs();
    }

    async loadDocs() {
        if (!this.activitySubject) {
            return;
        }
        this.loading = true;
        try {
            const docs = await getRequiredDocuments({ activitySubject: this.activitySubject });
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

        const reader = new FileReader();
        reader.onload = () => {
            const base64 = reader.result.split(',')[1];
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
                activityName: this.activityName || this.activitySubject
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
