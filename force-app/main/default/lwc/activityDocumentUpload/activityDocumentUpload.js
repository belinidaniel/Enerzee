import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getRequiredDocuments from '@salesforce/apex/ActivityDocumentController.getRequiredDocuments';
import uploadExternalArchive from '@salesforce/apex/ExternalArchiveService.uploadExternalArchive';
import getAttachments from '@salesforce/apex/ActivityDocumentController.getAttachments';
import deleteAttachment from '@salesforce/apex/ActivityDocumentController.deleteAttachment';
import getDocumentCompletionStates from '@salesforce/apex/ActivityDocumentController.getDocumentCompletionStates';
import setDocumentCompleted from '@salesforce/apex/ActivityDocumentController.setDocumentCompleted';
import getTaskContext from '@salesforce/apex/ActivityDocumentController.getTaskContext';

export default class ActivityDocumentUpload extends LightningElement {
    @api recordId;
    @api activitySubject;
    @api activityName;
    @track sobjectId;
    @track opportunityId;
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
            this.rows = (docs || []).map((doc, index) => ({
                id: index,
                name: doc.name,
                observation: doc.observation,
                status: 'Pendente',
                completed: false,
                canComplete: false,
                disableComplete: true,
                existingFiles: [],
                existingCount: 0,
                pendingFiles: [],
                canUpload: true,
                canSend: false,
                disableSend: true
            }));
        } catch (error) {
            this.showToast('Erro', this.normalizeError(error), 'error');
        } finally {
            this.loading = false;
        }
    }

    async loadExistingAttachments() {
        if (!this.sobjectId) {
            return;
        }

        try {
            const activity = this.activityName || this.subject;
            const [attachments, completionStates] = await Promise.all([
                getAttachments({
                    sobjectId: this.sobjectId,
                    activitySubject: activity
                }),
                getDocumentCompletionStates({
                    sobjectId: this.sobjectId,
                    activitySubject: activity
                })
            ]);

            this.existingAttachments = attachments || [];
            const completionMap = this.buildCompletionMap(completionStates || []);

            this.rows = (this.rows || []).map((row) => {
                const matches = this.existingAttachments.filter(
                    (item) =>
                        (item.docRequiredName && this.normalizeDocKey(item.docRequiredName) === this.normalizeDocKey(row.name)) ||
                        this.normalizeDocKey(item.name) === this.normalizeDocKey(row.name)
                );

                const existingFiles = matches.map((item) => ({
                    id: item.id,
                    name: item.name,
                    url: item.url || item.downloadUrl
                }));

                const existingCount = existingFiles.length;
                const completed = completionMap.has(this.normalizeDocKey(row.name));
                const pendingFiles = completed ? [] : (row.pendingFiles || []);
                const canComplete = existingCount > 0;
                const canUpload = !completed && (this.isRelatorioFinalDeObra ? true : existingCount === 0);
                const canSend = !completed && pendingFiles.length > 0;

                return {
                    ...row,
                    completed,
                    canComplete,
                    disableComplete: !canComplete,
                    existingFiles,
                    existingCount,
                    pendingFiles,
                    canUpload,
                    canSend,
                    disableSend: !canSend,
                    status: this.resolveStatus(completed, existingCount, pendingFiles.length)
                };
            });
        } catch (error) {
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
        const rowId = event.target.dataset.index;
        const row = this.rows.find((item) => item.id == rowId);
        if (!row || row.completed) {
            return;
        }

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
                this.rows = this.rows.map((item) =>
                    item.id == rowId
                        ? {
                              ...item,
                              pendingFiles: payloads,
                              canSend: payloads.length > 0,
                              disableSend: payloads.length === 0,
                              status: this.resolveStatus(false, item.existingCount || 0, payloads.length)
                          }
                        : item
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
            event.target.value = null;
            return;
        }

        try {
            const payload = await this.readFile(file);
            this.rows = this.rows.map((item) =>
                item.id == rowId
                    ? {
                          ...item,
                          pendingFiles: [payload],
                          canSend: true,
                          disableSend: false,
                          status: this.resolveStatus(false, item.existingCount || 0, 1)
                      }
                    : item
            );
        } catch (error) {
            this.showToast('Erro', 'Falha ao ler o arquivo.', 'error');
            event.target.value = null;
        }
    }

    async handleUpload(event) {
        const rowId = event.target.dataset.index;
        const row = this.rows.find((item) => item.id == rowId);
        if (!row) {
            return;
        }
        if (!this.opportunityId) {
            this.showToast('Erro', 'opportunityId e obrigatorio para enviar o arquivo.', 'error');
            return;
        }

        const pendingFiles = row.pendingFiles || [];
        if (!pendingFiles.length) {
            const message = this.isRelatorioFinalDeObra
                ? 'Selecione ao menos 1 imagem para enviar.'
                : 'Selecione um arquivo antes de enviar.';
            this.showToast('Aviso', message, 'warning');
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
                r.id == rowId
                    ? {
                          ...r,
                          pendingFiles: [],
                          status: this.resolveStatus(
                              r.completed,
                              (r.existingCount || 0) + pendingFiles.length,
                              0
                          ),
                          canSend: false,
                          disableSend: true
                      }
                    : r
            );
            this.clearFileInputForRow(rowId);
            this.showToast('Sucesso', 'Arquivo enviado com sucesso.', 'success');
            this.dispatchEvent(new CustomEvent('uploaded'));
            await this.loadExistingAttachments();
        } catch (error) {
            this.showToast('Erro', this.normalizeError(error), 'error');
        } finally {
            this.loading = false;
        }
    }

    clearFileInputForRow(rowId) {
        const input = this.template.querySelector(`input[data-index="${rowId}"]`);
        if (input) {
            input.value = null;
        }
    }

    async handleRemove(event) {
        const attachmentId = event.currentTarget?.dataset?.attachmentId;
        if (!attachmentId) {
            return;
        }

        this.loading = true;
        try {
            await deleteAttachment({ attachmentId });
            this.showToast('Sucesso', 'Arquivo removido com sucesso.', 'success');
            this.dispatchEvent(new CustomEvent('uploaded'));
            await this.loadExistingAttachments();
        } catch (error) {
            this.showToast('Erro', this.normalizeError(error), 'error');
        } finally {
            this.loading = false;
        }
    }

    async handleToggleCompleted(event) {
        const rowId = event.target.dataset.index;
        const markCompleted = event.target.checked;
        const row = this.rows.find((item) => item.id == rowId);
        if (!row) {
            return;
        }

        if (markCompleted && !row.canComplete) {
            event.target.checked = false;
            this.showToast('Aviso', 'Anexe evidências antes de concluir esta atividade.', 'warning');
            return;
        }

        this.loading = true;
        try {
            await setDocumentCompleted({
                sobjectId: this.sobjectId,
                activitySubject: this.activityName || this.subject,
                docRequiredName: row.name,
                completed: markCompleted
            });
            const message = markCompleted ? 'Atividade concluída.' : 'Conclusão removida.';
            this.showToast('Sucesso', message, 'success');
            await this.loadExistingAttachments();
        } catch (error) {
            event.target.checked = row.completed;
            this.showToast('Erro', this.normalizeError(error), 'error');
        } finally {
            this.loading = false;
        }
    }

    get showTable() {
        return (this.rows || []).length > 0;
    }

    isRelatorioFinalSubject(value) {
        const normalized = this.normalizeSubject(value);
        return normalized === 'RELATORIO DE EXECUCAO DE OBRA' || normalized === 'RELATORIO FINAL DE OBRA';
    }

    buildCompletionMap(states) {
        const map = new Set();
        for (const state of states || []) {
            if (state && state.completed && state.docRequiredName) {
                map.add(this.normalizeDocKey(state.docRequiredName));
            }
        }
        return map;
    }

    resolveStatus(completed, existingCount, pendingCount) {
        if (completed) {
            return 'Concluído';
        }
        if (pendingCount > 0) {
            return 'Pronto para enviar';
        }
        if (existingCount > 0) {
            return 'Enviado';
        }
        return 'Pendente';
    }

    normalizeDocKey(value) {
        return this.normalizeSubject(value);
    }

    normalizeSubject(value) {
        if (!value) {
            return '';
        }
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
                    localId: `${file.name}-${file.size}-${file.lastModified}`,
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
        if (!error) {
            return 'Erro desconhecido';
        }
        if (Array.isArray(error.body)) {
            return error.body.map((item) => item.message).join(', ');
        }
        if (error.body && error.body.message) {
            return error.body.message;
        }
        return error.message || JSON.stringify(error);
    }
}
