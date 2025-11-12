import { LightningElement, api, track } from 'lwc';
import getDocuments from '@salesforce/apex/ClickSignController.getDocuments';
import getRecipients from '@salesforce/apex/ClickSignController.getRecipients';
import process from '@salesforce/apex/ClickSignController.process';
import generatePreview from '@salesforce/apex/ClickSignTemplateController.generatePreview';
import getOrCreateClickSign from '@salesforce/apex/ClickSignController.getOrCreateClickSign';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import ClickSign_Recipients from '@salesforce/label/c.ClickSign_Recipients';
import ClickSign_NoRecipients from '@salesforce/label/c.ClickSign_NoRecipients';
import ClickSign_PreviewDocument from '@salesforce/label/c.ClickSign_PreviewDocument';
import ClickSign_SendDocuments from '@salesforce/label/c.ClickSign_SendDocuments';
import ClickSign_Loading from '@salesforce/label/c.ClickSign_Loading';
import ClickSign_Processing from '@salesforce/label/c.ClickSign_Processing';
import ClickSign_FileProcessing from '@salesforce/label/c.ClickSign_FileProcessing';

export default class ClickSignPrepareSend extends NavigationMixin(LightningElement) {
    @api recordId;
    @api clickSign;
    @track documents = [];
    @track recipients = [];
    @track isLoading = false;
    @track selectedDocumentUrl = ''; // URL of the selected document for viewing
    @track selectedTemplateId = '';
    @track selectedTemplateUrl = '';
    @track isCreatingRenditions = false;
    @track disableSendDocument = true; // Initially disabled

    labels = {
        ClickSign_Recipients,
        ClickSign_NoRecipients,
        ClickSign_PreviewDocument,
        ClickSign_SendDocuments,
        ClickSign_Loading,
        ClickSign_Processing,
        ClickSign_FileProcessing
    };

    connectedCallback() {
        this.isLoading = true;
        this.getOrCreateClickSign();
    }

    clear(){
        this.recipients = [];
        this.documents = [];
        this.selectedDocumentUrl = '';
        this.selectedTemplateId = '';
        this.selectedTemplateUrl = '';
        this.isCreatingRenditions = false;
        this.disableSendDocument = true;
    }

    getOrCreateClickSign(){
        getOrCreateClickSign({ recordId: this.recordId })
            .then(result => {
                this.clickSign = result;
            }).finally(() => {
                this.clear();
                this.loadDocuments();
                this.loadRecipients();
            });
    }
    checkButtonState() {
        this.disableSendDocument = true;
        console.log('Recipients:', this.recipients);
        console.log('Selected document URL:', this.selectedDocumentUrl);
        if(this.recipients.length > 0){
            this.disableSendDocument = false;
        }
    }

    loadDocuments() {
        this.selectedDocumentUrl = '';
        this.documents = [];
        if (this.clickSign.ClickSignTemplate__c) return;
        this.isLoading = true;
        getDocuments({ clickSignId: this.clickSign.Id })
            .then((result) => {
                this.documents = result.map((file) => ({
                    id: file.Id,
                    name: file.Title,
                    size: this.formatFileSize(file.ContentSize || 0),
                    type: this.getFileType(file.Title),
                    icon: this.getFileIcon(file.Title),
                    url: `/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=${file.LatestPublishedVersionId}&operationContext=CHATTER&contentId=${file.Id}&page=0` // Correct URL for document preview
                }));

                // Automatically load first document if ClickSignTemplate__c is not set
                if (!this.clickSign.ClickSignTemplate__c && this.documents.length > 0) {
                    this.selectedDocumentUrl = this.documents[0].url;
                }
            })
            .catch((error) => {
                this.showToast('Error', 'Failed to load documents. ' + error.body.message, 'error');
                console.error('Error loading documents:', error);
            })
            .finally(() => {
                this.isLoading = false;
                this.checkButtonState(); // Recheck the button state when the document URL is updated
            });
    }

    loadRecipients() {
        this.isLoading = true;
        console.log('Loading recipients for ClickSign ID:', this.recordId);
        getRecipients({ recordId: this.clickSign.Id })
            .then((result) => {
                this.recipients = result;
            })
            .catch((error) => {
                this.showToast('Error', 'Failed to load recipients. ' + error.body.message, 'error');
                console.error('Error loading recipients:', error);
            })
            .finally(() => {
                this.isLoading = false;
                this.checkButtonState(); // Recheck the button state when the document URL is updated
            });
    }

    handlePreviewDocument() {
        console.log('Generating preview for record:', this.recordId);
        this.isLoading = true;
    
        generatePreview({ recordId: this.recordId, templateId: this.clickSign.ClickSignTemplate__c })
            .then((result) => {
                if (result) {
                    setTimeout(() => {
                        if (this.documents.length > 0) {
                            const file = this.documents[0];
                            this.downloadFile(file.url, file.name);
                        }
                    }, 2000);
                }
            })
            .catch((error) => {
                this.showToast('Error', 'Failed to generate preview. ' + error.body.message, 'error');
                console.error('Error generating preview:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    downloadFile(url, fileName) {
        if (!url) {
            console.error("No file URL available for download");
            return;
        }
    
        const extension = fileName.split('.').pop().toLowerCase();
        const validExtensions = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'];
        
        const downloadFileName = validExtensions.includes(extension) ? fileName : `document.${extension}`;
    
        const link = document.createElement('a');
        link.href = url;
        link.download = downloadFileName;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    }

    
    handleSend() {
        this.isLoading = true;
        process({ clickSign: this.clickSign })
            .then(() => {
                this.showToast('Success', 'Documents sent successfully.', 'success');
                this.navigateToRecordPage();
            })
            .catch((error) => {
                this.showToast('Error', 'Failed to send documents. ' + error.body.message, 'error');
                console.error('Error sending documents:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

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
    }

    // Helper methods for file type and size
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

    navigateToRecordPage() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                actionName: 'view'
            }
        });
    }
}