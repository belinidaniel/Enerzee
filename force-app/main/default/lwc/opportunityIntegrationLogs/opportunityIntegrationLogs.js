import { LightningElement, api } from 'lwc';
import getLogsByOpportunity from '@salesforce/apex/OpportunityLogViewerController.getLogsByOpportunity';
import getLogDetail from '@salesforce/apex/OpportunityLogViewerController.getLogDetail';
import isCurrentUserAdmin from '@salesforce/apex/OpportunityLogViewerController.isCurrentUserAdmin';

export default class OpportunityIntegrationLogs extends LightningElement {
    _recordId;
    logs = [];
    selectedLog;
    isLoading = true;
    detailLoading = false;
    isDetailOpen = false;
    hasAccess = false;
    accessChecked = false;
    errorMessage;

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        this._recordId = value;
        if (this.hasAccess && value) {
            this.loadLogs();
        }
    }

    connectedCallback() {
        this.checkAccessAndLoad();
    }

    async checkAccessAndLoad() {
        try {
            this.hasAccess = await isCurrentUserAdmin();
            this.accessChecked = true;

            if (this.hasAccess) {
                await this.loadLogs();
            }
            this.errorMessage = null;
        } catch (error) {
            this.errorMessage = this.reduceError(error);
            this.accessChecked = true;
        } finally {
            this.isLoading = false;
        }
    }

    async loadLogs() {
        if (!this.recordId) {
            this.logs = [];
            this.isLoading = false;
            return;
        }

        this.isLoading = true;
        try {
            const data = await getLogsByOpportunity({ opportunityId: this.recordId, recordLimit: 100 });
            this.logs = this.decorateLogs(data);
            this.errorMessage = null;
        } catch (error) {
            this.errorMessage = this.reduceError(error);
            this.logs = [];
        } finally {
            this.isLoading = false;
        }
    }

    decorateLogs(logs = []) {
        return logs.map((log) => {
            const statusClass = this.getStatusClass(log.StatusCode__c, log.Status__c);
            return {
                ...log,
                statusValue: log.StatusCode__c !== null && log.StatusCode__c !== undefined
                    ? log.StatusCode__c
                    : (log.Status__c || '-'),
                statusBadgeClass: `slds-badge status-badge ${statusClass}`
            };
        });
    }

    get hasLogs() {
        return this.logs && this.logs.length > 0;
    }

    getStatusClass(statusCode, statusText) {
        if (statusCode !== null && statusCode !== undefined) {
            const numericCode = parseInt(statusCode, 10);
            if (!isNaN(numericCode)) {
                if (numericCode >= 200 && numericCode < 300) {
                    return 'status-success';
                }
                if (numericCode >= 400) {
                    return 'status-error';
                }
                if (numericCode >= 300 && numericCode < 400) {
                    return 'status-warning';
                }
            }
        }

        if (statusText && statusText.toLowerCase().includes('warn')) {
            return 'status-warning';
        }

        return 'status-neutral';
    }

    handleRowClick(event) {
        const logId = event.currentTarget.dataset.id;
        if (logId) {
            this.openDetail(logId);
        }
    }

    handleRowKeydown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.handleRowClick(event);
        }
    }

    async openDetail(logId) {
        this.detailLoading = true;
        try {
            const log = await getLogDetail({ logId });
            if (log) {
                const statusClass = this.getStatusClass(log.StatusCode__c, log.Status__c);
                this.selectedLog = {
                    ...log,
                    statusValue: log.StatusCode__c !== null && log.StatusCode__c !== undefined
                        ? log.StatusCode__c
                        : (log.Status__c || '-'),
                    statusBadgeClass: `slds-badge status-badge ${statusClass}`,
                    formattedRequest: this.formatJson(log.RequestBody__c),
                    formattedResponse: this.formatJson(log.ResponseBody__c)
                };
                this.isDetailOpen = true;
            }
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.detailLoading = false;
        }
    }

    handleCloseDetail() {
        this.isDetailOpen = false;
        this.selectedLog = null;
    }

    handleRefresh() {
        this.loadLogs();
    }

    formatJson(rawValue) {
        if (!rawValue) {
            return '';
        }

        try {
            const parsed = JSON.parse(rawValue);
            return JSON.stringify(parsed, null, 2);
        } catch (e) {
            return rawValue;
        }
    }

    reduceError(error) {
        if (Array.isArray(error)) {
            return error.map((e) => e.message).join(', ');
        }
        if (error && Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (error && error.body && typeof error.body.message === 'string') {
            return error.body.message;
        }
        if (typeof error === 'string') {
            return error;
        }
        return 'Erro desconhecido';
    }
}
