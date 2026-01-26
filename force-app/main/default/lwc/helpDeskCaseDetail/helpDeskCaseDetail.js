import { api, LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { CurrentPageReference } from 'lightning/navigation';
import getCaseDetail from '@salesforce/apex/ModuloHelpDeskCaseController.getCaseDetail';
import getCaseComments from '@salesforce/apex/ModuloHelpDeskCaseController.getCaseComments';
import addComment from '@salesforce/apex/ModuloHelpDeskCaseController.addComment';
import getCaseAttachments from '@salesforce/apex/ModuloHelpDeskCaseController.getCaseAttachments';
import uploadFiles from '@salesforce/apex/ModuloHelpDeskCaseController.uploadFiles';

export default class HelpDeskCaseDetail extends LightningElement {
    @api recordId;
    contactId;
    detail;
    wiredDetail;
    wiredComments;
    wiredAttachments;
    @track comments = [];
    @track attachments = [];
    @track pendingFiles = [];
    readingFiles = false;
    newComment = '';
    isSaving = false;
    pageRef;

    @wire(CurrentPageReference)
    wiredPageRef(ref) {
        this.pageRef = ref;
        const fromState = ref?.state?.recordId || ref?.state?.c__recordId || ref?.attributes?.recordId;
        const contactState = ref?.state?.cId || ref?.state?.c__contactId;
        if (!this.recordId && fromState) {
            this.recordId = fromState;
        }
        if (!this.contactId && contactState) {
            this.contactId = contactState;
        }
    }

    @wire(getCaseDetail, { caseId: '$recordId', contactId: '$contactId' })
    wiredCaseDetail(result) {
        this.wiredDetail = result;
        const { data, error } = result;
        if (data) {
            this.detail = this.normalizeDetail(data);
        } else if (error) {
            this.handleError('Erro ao carregar caso', error);
        }
    }

    @wire(getCaseComments, { caseId: '$recordId', contactId: '$contactId' })
    wiredCaseComments(result) {
        this.wiredComments = result;
        const { data, error } = result;
        if (data) {
            this.comments = data.map((item) => ({
                id: item.Id,
                body: item.CommentBody,
                date: this.formatDate(item.CreatedDate),
                author: item.CreatedBy ? item.CreatedBy.Name : 'User',
                avatar: item.CreatedBy ? item.CreatedBy.SmallPhotoUrl : null,
                initials: item.CreatedBy && item.CreatedBy.Name ? this.getInitials(item.CreatedBy.Name) : 'U'
            }));
        } else if (error) {
            this.handleError('Erro ao carregar comentários', error);
        }
    }

    @wire(getCaseAttachments, { caseId: '$recordId', contactId: '$contactId' })
    wiredCaseAttachments(result) {
        this.wiredAttachments = result;
        const { data, error } = result;
        if (data) {
            this.attachments = data.map((link) => ({
                id: link.Id,
                title: link.ContentDocument ? link.ContentDocument.Title : 'Arquivo',
                extension: link.ContentDocument ? link.ContentDocument.FileExtension : '',
                size: link.ContentDocument ? this.formatSize(link.ContentDocument.ContentSize) : '',
                versionId: link.ContentDocument ? link.ContentDocument.LatestPublishedVersionId : null,
                downloadUrl:
                    link.ContentDocument && link.ContentDocument.LatestPublishedVersionId
                        ? `/sfc/servlet.shepherd/version/download/${link.ContentDocument.LatestPublishedVersionId}`
                        : null,
                createdDate: link.ContentDocument ? this.formatDate(link.ContentDocument.CreatedDate) : '',
                createdBy: link.ContentDocument && link.ContentDocument.CreatedBy ? link.ContentDocument.CreatedBy.Name : ''
            }));
        } else if (error) {
            this.handleError('Erro ao carregar anexos', error);
        }
    }

    get isOpen() {
        return this.detail && this.detail.status !== 'Fechado';
    }

    get isBlank() {
        return !this.newComment || !this.newComment.trim();
    }

    get isAddDisabled() {
        return this.isSaving || this.readingFiles || this.isBlank;
    }

    get hasComments() {
        return this.comments && this.comments.length > 0;
    }

    get hasAttachments() {
        return this.attachments && this.attachments.length > 0;
    }

    get acceptedFormats() {
        return '.pdf,.png,.jpg,.jpeg,.doc,.docx,.xls,.xlsx,.txt';
    }

    handleCommentChange(event) {
        this.newComment = event.target.value;
    }

    handleFilesChange(event) {
        const files = event.target.files;
        if (!files || files.length === 0) {
            return;
        }
        this.readingFiles = true;
        const readers = [];
        Array.from(files).forEach((file) => {
            readers.push(
                new Promise((resolve, reject) => {
                    const reader = new FileReader();
                    reader.onload = () => {
                        const base64 = reader.result.split(',')[1];
                        resolve({
                            fileName: file.name,
                            contentType: file.type,
                            base64Data: base64,
                            humanSize: this.formatSize(file.size),
                            name: file.name
                        });
                    };
                    reader.onerror = reject;
                    reader.readAsDataURL(file);
                })
            );
        });

        Promise.all(readers)
            .then((results) => {
                this.pendingFiles = [...this.pendingFiles, ...results];
            })
            .catch((error) => {
                this.showToast('Erro ao ler arquivo', error?.message || 'Erro inesperado', 'error');
            })
            .finally(() => {
                this.readingFiles = false;
            });
    }

    removePendingFile(event) {
        const name = event.currentTarget.dataset.name;
        this.pendingFiles = this.pendingFiles.filter((f) => f.name !== name);
    }

    handleAddComment() {
        if (this.isBlank || !this.recordId) {
            return;
        }
        this.isSaving = true;
        addComment({ caseId: this.recordId, commentBody: this.newComment, contactId: this.contactId })
            .then(() => {
                if (this.pendingFiles.length > 0) {
                    return uploadFiles({ caseId: this.recordId, files: this.pendingFiles, contactId: this.contactId }).then(() => null);
                }
                return null;
            })
            .then(() => refreshApex(this.wiredComments))
            .then(() => refreshApex(this.wiredAttachments))
            .catch((error) => {
                this.handleError('Não foi possível adicionar o comentário', error);
            })
            .finally(() => {
                this.isSaving = false;
                this.newComment = '';
                this.pendingFiles = [];
                this.readingFiles = false;
            });
    }

    handleReopen() {
        this.showToast('Ação futura', 'Fluxo de reabertura pode ser adicionado aqui.', 'info');
    }

    normalizeDetail(data) {
        return {
            id: data.Id,
            caseNumber: data.CaseNumber,
            subject: data.Subject,
            status: data.Status,
            contactName: data.Contact ? data.Contact.Name : '',
            createdDateDisplay: this.formatDate(data.CreatedDate),
            lastModifiedDisplay: this.formatDate(data.LastModifiedDate),
            richDescription: data.Description_Rich__c || data.Description || ''
        };
    }

    formatDate(dateValue) {
        return new Intl.DateTimeFormat('en-US', {
            year: 'numeric',
            month: 'short',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        }).format(new Date(dateValue));
    }

    formatSize(bytes) {
        if (!bytes && bytes !== 0) {
            return '';
        }
        const sizes = ['B', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(1024));
        return `${(bytes / Math.pow(1024, i)).toFixed(1)} ${sizes[i]}`;
    }

    getInitials(name) {
        return name
            .split(' ')
            .map((n) => n.charAt(0))
            .join('')
            .substring(0, 2)
            .toUpperCase();
    }

    handleError(title, error) {
        this.showToast(title, this.normalizeError(error), 'error');
    }

    normalizeError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Erro inesperado';
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
