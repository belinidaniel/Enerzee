import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDocuments from '@salesforce/apex/ClickSignTemplateController.getDocuments';
import uploadDocument from '@salesforce/apex/ClickSignTemplateController.uploadDocument';
import deleteDocument from '@salesforce/apex/ClickSignTemplateController.deleteDocument';
import generateTemplateFromMappings from '@salesforce/apex/ClickSignTemplateController.generateTemplateFromMappings';
import ClickSign_Success from '@salesforce/label/c.ClickSign_Success';
import ClickSign_Error from '@salesforce/label/c.ClickSign_Error';
import ClickSign_FileProcessing from '@salesforce/label/c.ClickSign_FileProcessing';
import ClickSign_OnlyDocxAllowed from '@salesforce/label/c.ClickSign_OnlyDocxAllowed';
import ClickSign_FileUploaded from '@salesforce/label/c.ClickSign_FileUploaded';
import ClickSign_FileUploadError from '@salesforce/label/c.ClickSign_FileUploadError';
import ClickSign_DocumentRemoved from '@salesforce/label/c.ClickSign_DocumentRemoved';
import ClickSign_DocumentRemoveError from '@salesforce/label/c.ClickSign_DocumentRemoveError';
import ClickSign_FetchDocumentsError from '@salesforce/label/c.ClickSign_FetchDocumentsError';
import ClickSign_HeaderTitle from '@salesforce/label/c.ClickSign_HeaderTitle';
import ClickSign_DragDropFiles from '@salesforce/label/c.ClickSign_DragDropFiles';
import ClickSign_GeneratedFileName from '@salesforce/label/c.ClickSign_GeneratedFileName';
import ClickSign_RemoveFile from '@salesforce/label/c.ClickSign_RemoveFile';
import ClickSign_Close from '@salesforce/label/c.ClickSign_Close';
import ClickSign_Loading from '@salesforce/label/c.ClickSign_Loading';

export default class ClickSignUploadDocuments extends LightningElement {
    @api templateId; // Record ID for ClickSignTemplate__c
    @track documents = []; // List of uploaded documents
    @track generatedFileName = ''; // File name for the generated document
    @track isLoading = false; // Spinner visibility
    @track uploadedFile = false;
    @track document;
    label = {
        ClickSign_Success,
        ClickSign_Error,
        ClickSign_FileProcessing,
        ClickSign_OnlyDocxAllowed,
        ClickSign_FileUploaded,
        ClickSign_FileUploadError,
        ClickSign_DocumentRemoved,
        ClickSign_DocumentRemoveError,
        ClickSign_FetchDocumentsError,
        ClickSign_HeaderTitle,
        ClickSign_DragDropFiles,
        ClickSign_GeneratedFileName,
        ClickSign_RemoveFile,
        ClickSign_Close,
        ClickSign_Loading
    };

    connectedCallback() {
        // Fetch existing documents on load
        this.fetchDocuments();
    }

    async fetchDocuments() {
        this.cleanAllFields();
        this.isLoading = true;
        try {
            console.log('templateId:', this.templateId);
            const result = await getDocuments({ templateId: this.templateId });
            this.documents = result.map((doc) => ({
                id: doc.Id,
                title: doc.Title,
                versionId: doc.LatestPublishedVersionId,
            }));
            if (this.documents.length > 0) {
                this.uploadedFile = true;
                this.document = this.documents[0];
                this.generatedFileName = this.document.title;
                this.dispatchEvent(new CustomEvent('changefilename', { detail: { value:  this.generatedFileName } }));
            }
        } catch (error) {
            console.error('Error fetching documents:', error);
            this.showToastMessage(this.label.ClickSign_FetchDocumentsError, 'error');
            this.uploadedFile = false;
        } finally {
            this.isLoading = false;
        }
    }
    
    handleFileUpload(event) {
        this.isLoading = true;
        const file = event.target.files[0];
        if (file && file.name.endsWith('.docx')) {
            const reader = new FileReader();
            reader.onload = () => {
                const base64 = reader.result.split(',')[1];
                this.uploadDocument(file.name, base64, file.type);
            };
            reader.readAsDataURL(file);
        } else {
            this.showToastMessage(this.label.ClickSign_OnlyDocxAllowed, 'error');
        }
    }

    async uploadDocument(fileName, base64Data, contentType) {
        try {
            await uploadDocument({
                fileName,
                base64Data,
                contentType,
                templateId: this.templateId,
            });
            this.showToastMessage(this.label.ClickSign_FileUploaded, 'success');
            this.fetchDocuments(); // Refresh the document list
        } catch (error) {
            console.error('Error uploading document:', error);
            this.showToastMessage(this.label.ClickSign_FileUploadError, 'error');
            return;
        } finally {
            this.isLoading = false;
        }

        try {
            const templateResult = await generateTemplateFromMappings({ templateId: this.templateId });
            if (templateResult === 'no-mappings') {
                this.showToastMessage('Campos do template ainda não foram definidos.', 'warning');
            } else if (templateResult === 'no-document') {
                this.showToastMessage('Arquivo do template não encontrado para gerar.', 'warning');
            }
        } catch (error) {
            console.error('Error generating template:', error);
            this.showToastMessage('Nao foi possivel gerar o template agora. Tente novamente.', 'warning');
        }
    }

    async handleRemoveDocument(event) {
        this.isLoading = true;
        try {
            await deleteDocument({ templateId: this.templateId });
            this.showToastMessage(this.label.ClickSign_DocumentRemoved, 'success');
            this.fetchDocuments(); // Refresh the document list
        } catch (error) {
            console.error('Error removing document:', error);
            this.showToastMessage(this.label.ClickSign_DocumentRemoveError, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    cleanAllFields() {
        this.uploadedFile = false;
        this.documents = [];
        this.generatedFileName = '';
        this.document = null;
    }

    showToastMessage(message, variant) {
        const title = variant === 'success'
            ? this.label.ClickSign_Success
            : variant === 'warning'
                ? 'Atencao'
                : this.label.ClickSign_Error;
        const event = new ShowToastEvent({
            title,
            message,
            variant,
        });
        this.dispatchEvent(event);
        this.notifyParent(
            title,
            message,
            variant
        );
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

    handleGeneratedFileNameChange(event) {
        const inputValue = event.target.value;
        this.dispatchEvent(new CustomEvent('changefilename', { detail: { value: inputValue } }));

    }
}
