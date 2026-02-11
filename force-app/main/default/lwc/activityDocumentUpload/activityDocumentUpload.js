import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getRequiredDocuments from '@salesforce/apex/ActivityDocumentController.getRequiredDocuments';
import uploadExternalArchive from '@salesforce/apex/ExternalArchiveService.uploadExternalArchive';
import getAttachments from '@salesforce/apex/ActivityDocumentController.getAttachments';
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

    get isRelatorioFinalDeObra() {
        return this.isRelatorioFinalSubject(this.activityName || this.subject);
    }

    get maxFilesPerRow() {
        return this.isRelatorioFinalDeObra ? null : 1;
    }

    get acceptedFormats() {
        return this.isRelatorioFinalDeObra ? 'image/png,image/jpeg' : 'application/pdf';
    }

    get allowMultipleFiles() {
        return this.isRelatorioFinalDeObra;
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
                status: 'Pendente',
                existingFiles: [],
                existingCount: 0,
                pendingFiles: [],
                canUpload: true,
                canSend: false,
                disableSend: true,
                maxFiles: this.maxFilesPerRow,
                remainingSlots: null
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
            const isRelatorio = this.isRelatorioFinalDeObra;

            this.rows = (this.rows || []).map((r) => {
                const matches = this.existingAttachments.filter(
                    (att) =>
                        (att.docRequiredName && att.docRequiredName === r.name) ||
                        att.name === r.name
                );

                const existingFiles = matches.map((att) => ({
                    name: att.name,
                    url: att.url || att.downloadUrl
                }));

                const existingCount = existingFiles.length;
                const canUpload = isRelatorio ? true : existingCount === 0;
                const remainingSlots = null;
                const canSend = (r.pendingFiles || []).length > 0;

                return {
                    ...r,
                    status: existingCount > 0 ? 'Enviado' : r.status,
                    existingFiles,
                    existingCount,
                    pendingFiles: r.pendingFiles || [],
                    canUpload,
                    canSend,
                    disableSend: !canSend,
                    remainingSlots
                };
            });
        } catch (error) {
            // nao bloqueia UI
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

    async handleFileChange(event) {
        const idx = event.target.dataset.index;
        const row = this.rows.find((r) => r.id == idx);
        if (!row) return;

        const files = Array.from(event.target.files || []);
        if (!files.length) {
            return;
        }

        if (this.isRelatorioFinalDeObra) {
            const invalid = files.find((file) => !this.isImageFile(file));
            if (invalid) {
                this.showToast('Aviso', 'Apenas imagens PNG ou JPG sao aceitas para este envio.', 'warning');
                event.target.value = null;
                return;
            }

            try {
                const payloads = await Promise.all(files.map((file) => this.readFile(file)));
                this.rows = this.rows.map((r) =>
                    r.id == idx
                        ? {
                              ...r,
                          pendingFiles: payloads,
                          status: 'Pronto para enviar',
                          canSend: payloads.length > 0,
                          disableSend: payloads.length === 0
                      }
                        : r
                );
            } catch (error) {
                this.showToast('Erro', 'Falha ao ler a imagem.', 'error');
                event.target.value = null;
            }
            return;
        }

        const file = files[0];
        const isPdf =
            (file.type && file.type.toLowerCase() === 'application/pdf') ||
            (file.name && file.name.toLowerCase().endsWith('.pdf'));
        if (!isPdf) {
            this.showToast('Aviso', 'Apenas arquivos PDF sao aceitos para este envio.', 'warning');
            event.target.value = null; // limpa selecao
            return;
        }

        try {
            const payload = await this.readFile(file);
            this.rows = this.rows.map((r) =>
                r.id == idx
                    ? {
                          ...r,
                          pendingFiles: [payload],
                          status: 'Pronto para enviar',
                          canSend: true,
                          disableSend: false
                      }
                    : r
            );
        } catch (error) {
            this.showToast('Erro', 'Falha ao ler o arquivo.', 'error');
            event.target.value = null;
        }
    }

    async handleUpload(event) {
        const idx = event.target.dataset.index;
        const row = this.rows.find((r) => r.id == idx);
        if (!row) {
            return;
        }

        if (!this.opportunityId) {
            this.showToast('Erro', 'opportunityId e obrigatorio para enviar o arquivo.', 'error');
            return;
        }

        const pendingFiles = row.pendingFiles || [];
        if (!pendingFiles.length) {
            const msg = this.isRelatorioFinalDeObra
                ? 'Selecione ao menos 1 imagem para enviar.'
                : 'Selecione um arquivo antes de enviar.';
            this.showToast('Aviso', msg, 'warning');
            return;
        }

        this.loading = true;
        try {
            for (const file of pendingFiles) {
                const result = await uploadExternalArchive({
                    opportunityId: this.opportunityId,
                    fileName: file.fileName,
                    base64File: file.base64,
                    sobjectId: this.sobjectId,
                    activityName: this.activityName || this.subject,
                    docRequiredName: row.name
                });
                if (!result || !result.success) {
                    throw new Error((result && result.message) || 'Falha ao enviar.');
                }
            }

            this.rows = this.rows.map((r) =>
                r.id == idx
                    ? {
                          ...r,
                          pendingFiles: [],
                          status: 'Enviado',
                          canSend: false,
                          disableSend: true
                      }
                    : r
            );
            this.showToast('Sucesso', 'Arquivo enviado com sucesso.', 'success');
            this.dispatchEvent(new CustomEvent('uploaded'));
            await this.loadExistingAttachments();
        } catch (error) {
            this.showToast('Erro', this.normalizeError(error), 'error');
        } finally {
            this.loading = false;
        }
    }

    get showTable() {
        return (this.rows || []).length > 0;
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

    isImageFile(file) {
        const type = (file.type || '').toLowerCase();
        const name = (file.name || '').toLowerCase();
        return (
            type === 'image/png' ||
            type === 'image/jpeg' ||
            name.endsWith('.png') ||
            name.endsWith('.jpg') ||
            name.endsWith('.jpeg')
        );
    }

    readFile(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                const base64Body = reader.result.split(',')[1];
                const prefix = file.type
                    ? `data:${file.type};base64,`
                    : 'data:application/octet-stream;base64,';
                resolve({
                    fileName: file.name,
                    base64: prefix + base64Body
                });
            };
            reader.onerror = () => reject(reader.error);
            reader.readAsDataURL(file);
        });
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