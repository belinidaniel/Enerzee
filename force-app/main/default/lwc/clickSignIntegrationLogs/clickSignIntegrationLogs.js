import { LightningElement, api } from 'lwc';
import getLogsByClickSign from '@salesforce/apex/ClickSignLogViewerController.getLogsByClickSign';
import getLogDetail from '@salesforce/apex/ClickSignLogViewerController.getLogDetail';
import isCurrentUserAdmin from '@salesforce/apex/ClickSignLogViewerController.isCurrentUserAdmin';

export default class ClickSignIntegrationLogs extends LightningElement {
    _recordId;
    logs = [];
    selectedLog;
    isLoading = true;
    detailLoading = false;
    hasAccess = false;
    accessChecked = false;
    errorMessage;
    lastSeenCreatedDate;

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

    async loadLogs(isRefresh = false, refreshSelected = false) {
        if (!this.recordId) {
            this.logs = [];
            this.isLoading = false;
            return;
        }

        this.isLoading = true;
        try {
            const data = await getLogsByClickSign({ relatedId: this.recordId, recordLimit: 100 });

            const previousLatest = this.lastSeenCreatedDate ? new Date(this.lastSeenCreatedDate) : null;
            const latestCreated = data.reduce((acc, log) => {
                const created = new Date(log.CreatedDate);
                return created > acc ? created : acc;
            }, previousLatest || new Date(0));

            const withNewFlag = data.map((log) => ({
                ...log,
                isNew: isRefresh && previousLatest ? new Date(log.CreatedDate) > previousLatest : false
            }));

            this.logs = this.decorateLogs(withNewFlag);
            this.lastSeenCreatedDate = latestCreated ? latestCreated.toISOString() : this.lastSeenCreatedDate;

            if (this.logs.length && (!this.selectedLog || !this.logs.some((l) => l.Id === this.selectedLog.Id))) {
                await this.openDetail(this.logs[0].Id);
            } else {
                this.logs = this.decorateLogs(this.logs);
                if (refreshSelected && this.selectedLog) {
                    await this.openDetail(this.selectedLog.Id);
                }
            }
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
            const createdDate = new Date(log.CreatedDate);
            return {
                ...log,
                displayClass: this.truncate(log.Class__c, 25),
                displayDate: this.formatDate(createdDate),
                displayTime: this.formatTime(createdDate),
                statusValue: log.StatusCode__c !== null && log.StatusCode__c !== undefined
                    ? log.StatusCode__c
                    : (log.Status__c || '-'),
                statusBadgeClass: `slds-badge status-badge ${statusClass}`,
                rowClass: `row-hover ${this.selectedLog && this.selectedLog.Id === log.Id ? 'row-selected' : ''}`
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
                this.logs = this.decorateLogs(this.logs);
            }
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.detailLoading = false;
        }
    }

    handleRefresh() {
        this.loadLogs(true, true);
    }

    truncate(text, maxLength) {
        if (!text || text.length <= maxLength) {
            return text;
        }
        return text.substring(0, maxLength - 3) + '...';
    }

    formatDate(dateObj) {
        return new Intl.DateTimeFormat('pt-BR', {
            day: '2-digit',
            month: '2-digit',
            year: 'numeric'
        }).format(dateObj);
    }

    formatTime(dateObj) {
        return new Intl.DateTimeFormat('pt-BR', {
            hour: '2-digit',
            minute: '2-digit',
            hour12: false
        }).format(dateObj);
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