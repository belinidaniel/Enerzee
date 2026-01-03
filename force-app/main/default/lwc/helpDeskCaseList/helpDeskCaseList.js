import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCases from '@salesforce/apex/ModuloHelpDeskCaseController.getCases';

export default class HelpDeskCaseList extends NavigationMixin(LightningElement) {
    filterOptions = [
        { label: 'My Open Cases', value: 'open' },
        { label: 'My Closed Cases', value: 'closed' }
    ];

    filterType = 'open';
    searchTerm = '';
    @track cases = [];
    isLoading = true;
    wiredResult;

    @wire(getCases, { filterType: '$filterType', searchTerm: '$searchTerm' })
    wiredCases(result) {
        this.wiredResult = result;
        const { data, error } = result;
        this.isLoading = false;

        if (data) {
            this.cases = data.map((c) => ({
                id: c.Id,
                caseNumber: c.CaseNumber,
                subject: c.Subject,
                status: c.Status,
                lastModified: new Intl.DateTimeFormat('en-US', {
                    year: 'numeric',
                    month: 'short',
                    day: '2-digit',
                    hour: '2-digit',
                    minute: '2-digit'
                }).format(new Date(c.LastModifiedDate)),
                contactName: c.Contact ? c.Contact.Name : '',
                url: `/lightning/r/Case/${c.Id}/view`
            }));
        } else if (error) {
            this.showToast('Erro ao carregar casos', this.normalizeError(error), 'error');
        }
    }

    get hasCases() {
        return this.cases && this.cases.length > 0;
    }

    get caseCount() {
        return this.cases ? this.cases.length : 0;
    }

    handleFilterChange(event) {
        this.filterType = event.detail.value;
        this.isLoading = true;
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        this.isLoading = true;
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredResult).finally(() => {
            this.isLoading = false;
        });
    }

    handleNavigate(event) {
        event.preventDefault();
        const recordId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                objectApiName: 'Case',
                actionName: 'view'
            }
        });
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

    normalizeError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Erro inesperado';
    }
}
