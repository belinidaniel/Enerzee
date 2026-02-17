import { LightningElement, api, track } from 'lwc';
import getDocuments from '@salesforce/apex/ClickSignTemplateController.getTemplateClickSign';
import getContentDocumentDownloadUrl from '@salesforce/apex/ClickSignTemplateController.getContentDocumentDownloadUrl';
import getClickSignTemplate from '@salesforce/apex/ClickSignTemplateController.getClickSignTemplate';
import generatePreview from '@salesforce/apex/ClickSignTemplateController.generatePreview';
import activateTemplate from '@salesforce/apex/ClickSignTemplateController.activateTemplate';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import ClickSign_Loading from '@salesforce/label/c.ClickSign_Loading';
import ClickSign_DownloadMessage from '@salesforce/label/c.ClickSign_DownloadMessage';
import ClickSign_PreviewDocument from '@salesforce/label/c.ClickSign_PreviewDocument';

export default class ClickSignPreviewDocuments extends NavigationMixin(LightningElement) {
    @api templateId;
    @track documents = [];
    @track isLoading = false;
    @track selectedDocumentUrl = ''; // URL of the selected document for viewing
    @track sourceObject = '';
    @track template;
    @track selectedRecord = '';
    @track selectedRecordName = '';
    @track isCreatingRenditions = false;

    labels = {
        ClickSign_Loading,
        ClickSign_DownloadMessage,
        ClickSign_PreviewDocument
    };

    connectedCallback() {
        this.isLoading = true;
        this.loadTemplate();
        console.log('templateId:', this.templateId);
    }

    loadTemplate() {
        getClickSignTemplate({ templateId: this.templateId })
            .then((result) => {
                this.template = result;
                this.sourceObject = this.template.SourceObject__c;
            })
            .catch((error) => {
                this.showToast('Error', 'Failed to load template. ' + error.body.message, 'error');
                console.error('Error loading template:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    @track showDocument = false;

    handleViewDocument(event) {
        const documentUrl = event.target.dataset.url;
        this.selectedDocumentUrl = documentUrl;
    }

    handleIframeLoad(event) {
        const iframe = event.target;
        const iframeDocument = iframe.contentDocument || iframe.contentWindow.document;
        const bodyText = iframeDocument.body.textContent || iframeDocument.body.innerText;
        if (bodyText.includes('Creating renditions of the file.')) {
            this.isCreatingRenditions = true;
        } else {
            this.isCreatingRenditions = false;
        }
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({ title, message, variant });
        this.dispatchEvent(event);
        this.notifyParent(title, message, variant);
    }

    getFileType(fileName) {
        const extension = fileName.split('.').pop().toLowerCase();
        switch (extension) {
            case 'pdf':
                return 'PDF';
            case 'doc':
            case 'docx':
                return 'Word Document';
            case 'xls':
            case 'xlsx':
                return 'Excel Spreadsheet';
            case 'txt':
                return 'Text File';
            default:
                return 'Unknown';
        }
    }

    getFileIcon(fileName) {
        const extension = fileName.split('.').pop().toLowerCase();
        switch (extension) {
            case 'pdf':
                return 'doctype:pdf';
            case 'doc':
            case 'docx':
                return 'doctype:word';
            case 'xls':
            case 'xlsx':
                return 'doctype:excel';
            case 'txt':
                return 'doctype:txt';
            default:
                return 'doctype:unknown';
        }
    }

    formatFileSize(bytes) {
        if (bytes === 0) return '0 KB';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }

    get hasSelectedDocument() {
        return this.selectedDocumentUrl !== '';
    }

    handleRecordSelection(event) {
        this.selectedRecord = event.detail;
        this.selectedRecordName = this.selectedRecord.CaseNumber || this.selectedRecord.Name;
        this.handlePreviewDocument();
    }

    get hasSelectedRecord() {
        return this.selectedRecord !== '' && this.showDocument === false;
    }

    handlePreviewDocument() {
        console.log('Generating preview for record:', this.selectedRecord.Id);
        this.isLoading = true;
    
        generatePreview({ recordId: this.selectedRecord.Id, templateId: this.templateId })
            .then((result) => {
                if (result) {
                    this.activateTemplate();
                    setTimeout(() => {
                        this.downloadDocument();
                    }, 1000); // Adding a small delay to ensure the document is available
                }
            })
            .catch((error) => {
                console.error("Error generating preview:", error);
                this.showToast('Error', 'Failed to generate preview. ' + (error?.body?.message || ''), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    downloadDocument() {
        console.log('this.templateId ',this.templateId )
        getContentDocumentDownloadUrl({ recordId: this.templateId })
            .then((url) => {
                console.log('url',url)
                if (url) {
                    console.log('url',url)
                    this.downloadFile(url);
                } else {
                    this.showToast('Error', 'No document URL found for the selected record.', 'error');
                }
            })
            .catch((error) => {
                console.error('Error fetching document URL:', error);
                this.showToast('Error', 'Failed to retrieve document URL.', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    downloadFile(url) {
        const fileId = url.split('/').pop();
        const downloadUrl = `/sfc/servlet.shepherd/version/download/${fileId}?operationContext=S1`;
        const link = document.createElement('a');
        link.href = downloadUrl;
        link.target = '_blank'; // Open in a new tab if desired
        console.log('link', link);
        document.body.appendChild(link);

        link.click();
        document.body.removeChild(link);
    }

    activateTemplate(){
        activateTemplate({ templateId: this.templateId }).then((result) => {});
    }

    notifyParent(title, message, variant) {
        this.dispatchEvent(
            new CustomEvent('notify', {
                detail: { title, message, variant },
                bubbles: true,
                composed: true
            })
        );
    }
}