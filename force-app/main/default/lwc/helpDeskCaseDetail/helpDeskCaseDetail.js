import { api, LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getCaseDetail from '@salesforce/apex/ModuloHelpDeskCaseController.getCaseDetail';
import getCaseComments from '@salesforce/apex/ModuloHelpDeskCaseController.getCaseComments';
import addComment from '@salesforce/apex/ModuloHelpDeskCaseController.addComment';

export default class HelpDeskCaseDetail extends LightningElement {
    @api recordId;
    detail;
    wiredDetail;
    wiredComments;
    @track comments = [];
    newComment = '';
    isSaving = false;

    @wire(getCaseDetail, { caseId: '$recordId' })
    wiredCaseDetail(result) {
        this.wiredDetail = result;
        const { data, error } = result;
        if (data) {
            this.detail = this.normalizeDetail(data);
        } else if (error) {
            this.handleError('Erro ao carregar caso', error);
        }
    }

    @wire(getCaseComments, { caseId: '$recordId' })
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

    get isOpen() {
        return this.detail && this.detail.status !== 'Closed';
    }

    get isBlank() {
        return !this.newComment || !this.newComment.trim();
    }

    get isAddDisabled() {
        return this.isSaving || this.isBlank;
    }

    get hasComments() {
        return this.comments && this.comments.length > 0;
    }

    handleCommentChange(event) {
        this.newComment = event.target.value;
    }

    handleAddComment() {
        if (this.isBlank || !this.recordId) {
            return;
        }
        this.isSaving = true;
        addComment({ caseId: this.recordId, commentBody: this.newComment })
            .then(() => {
                this.newComment = '';
                this.showToast('Comentário adicionado', 'Seu comentário foi enviado.', 'success');
                return refreshApex(this.wiredComments);
            })
            .catch((error) => {
                this.handleError('Não foi possível adicionar o comentário', error);
            })
            .finally(() => {
                this.isSaving = false;
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
            lastModifiedDisplay: this.formatDate(data.LastModifiedDate)
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
