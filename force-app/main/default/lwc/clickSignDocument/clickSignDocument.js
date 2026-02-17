import { LightningElement, track, api } from 'lwc';
import deleteDocument from '@salesforce/apex/ClickSignController.deleteDocument';
import getDocuments from '@salesforce/apex/ClickSignController.getDocuments';
import uploadDocument from '@salesforce/apex/ClickSignController.uploadDocument'; // Apex method for uploading files
import getActiveTemplates from '@salesforce/apex/ClickSignController.getActiveTemplates'; // Apex method to get active templates
import documentUploadIcon from '@salesforce/resourceUrl/DocumentUploadIcon';
import saveTemplateId from '@salesforce/apex/ClickSignController.saveTemplateId'; // Apex method to save template ID
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import ClickSign_SelectedDocuments from '@salesforce/label/c.ClickSign_SelectedDocuments';
import ClickSign_SelectTemplate from '@salesforce/label/c.ClickSign_SelectTemplate';
import ClickSign_ChangeTemplate from '@salesforce/label/c.ClickSign_ChangeTemplate';
import ClickSign_AddDocuments from '@salesforce/label/c.ClickSign_AddDocuments';
import ClickSign_DragDropFiles from '@salesforce/label/c.ClickSign_DragDropFiles';
import ClickSign_Processing from '@salesforce/label/c.ClickSign_Processing';
import ClickSign_FileProcessing from '@salesforce/label/c.ClickSign_FileProcessing';

export default class ClickSignDocument extends LightningElement {
    @track documents = [];
    @track showModal = false; // State for modal visibility
    @track showTemplateModal = false; // State for template modal visibility
    @track templates = []; // State for templates
    @track selectedTemplate = null; // State for selected template
    @track selectedTemplateName = null; // State for selected template name
    @api clickSign;

    documentUploadIcon = documentUploadIcon;

    labels = {
        selectedDocuments: ClickSign_SelectedDocuments,
        selectTemplate: ClickSign_SelectTemplate,
        changeTemplate: ClickSign_ChangeTemplate,
        addDocuments: ClickSign_AddDocuments,
        dragDropFiles: ClickSign_DragDropFiles,
        processing: ClickSign_Processing,
        fileProcessing: ClickSign_FileProcessing
    };

    connectedCallback() {
        this.loadDocuments();
        this.loadTemplates(); // Load templates on component initialization
        this.loadTemplateSelect();
    }

    // Load existing documents linked to the clickSignId
    loadDocuments() {
        getDocuments({ clickSignId: this.clickSign.Id })
            .then((result) => {
                this.documents = result.map((file) => ({
                    id: file.Id,
                    name: file.Title,
                    size: this.formatFileSize(file.ContentSize || 0),
                    type: this.getFileType(file.Title),
                    icon: this.getFileIcon(file.Title),
                }));
            })
            .catch((error) => {
                console.error('Error loading documents:', error);
                this.showToast('Error', 'Falha ao carregar documentos.', 'error');
            });
    }

    loadTemplateSelect(){
        if(this.clickSign.ClickSignTemplate__c != null){
            this.selectedTemplate = this.clickSign.ClickSignTemplate__c;
            this.selectedTemplateName = this.clickSign.ClickSignTemplate__r.Name;
        }
    }
    // Load active templates
    loadTemplates() {
        getActiveTemplates()
            .then((result) => {
                this.templates = result.map((template) => ({
                    value: template.Id,
                    label: template.Name,
                }));
            })
            .catch((error) => {
                console.error('Error loading templates:', error);
                this.showToast('Error', 'Falha ao carregar templates.', 'error');
            });
    }

    // Open the template selection modal
    openTemplateDialog() {
        this.showTemplateModal = true;
    }

    // Close the template selection modal
    closeTemplateDialog() {
        this.showTemplateModal = false;
    }

    // Handle template update
    updateTemplate() {
        console.log('Template updated:', this.selectedTemplate);
    }

    // Handle template removal
    removeTemplate() {
        this.selectedTemplate = null;
        this.selectedTemplateName = null;
        // Logic to remove the template from ClickSign object
        saveTemplateId({ clickSignId: this.clickSign.Id, templateId: null })
            .then(() => {
                console.log('Template removed');
                this.showToast('Success', 'Template removido com sucesso.', 'success');
            })
            .catch((error) => {
                console.error('Error removing template:', error);
                this.showToast('Error', 'Falha ao remover template.', 'error');
            });
    }

    // Handle template selection
    handleTemplateSelection(event) {
        const selectedOption = this.templates.find(template => template.value === event.target.value);
        this.selectedTemplate = selectedOption.value;
        this.selectedTemplateName = selectedOption.label;
        this.closeTemplateDialog();
        // Save the selected template ID in ClickSign object
        saveTemplateId({ clickSignId: this.clickSign.Id, templateId: this.selectedTemplate })
            .then(() => {
                console.log('Template ID saved');
                this.showToast('Success', 'Template atualizado com sucesso.', 'success');
            })
            .catch((error) => {
                console.error('Error saving template ID:', error);
                this.showToast('Error', 'Falha ao salvar template.', 'error');
            });
    }


    // Handle file selection and upload to Salesforce
    handleFileSelection(event) {
        const files = event.target.files;
        if (files.length > 0) {
            this.showModal = true; // Show loading modal
            const promises = Array.from(files).map((file) => this.uploadFile(file));
    
            Promise.all(promises)
                .then(() => {
                    this.loadDocuments(); // Reload documents after successful upload
                    this.showModal = false; // Hide the modal
                    this.showToast('Success', 'Arquivo enviado com sucesso.', 'success');
                })
                .catch((error) => {
                    console.error('Error uploading files:', error);
                    this.showModal = false; // Hide modal even if an error occurs
                    this.showToast('Error', 'Falha ao enviar arquivo.', 'error');
                });
        } else {
            console.warn('No files selected');
        }
    }
    
    
    uploadFile(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                try {
                    const base64 = reader.result.split(',')[1];
                    uploadDocument({ 
                        fileName: file.name, 
                        base64Data: base64, 
                        contentType: file.type, 
                        clickSignId: this.clickSign.Id 
                    })
                    .then(() => resolve())
                    .catch((error) => {
                        console.error('Apex uploadDocument error:', error);
                        reject(error);
                    });
                } catch (err) {
                    console.error('File processing error:', err);
                    reject(err);
                }
            };
            reader.onerror = (error) => {
                console.error('FileReader error:', error);
                reject(error);
            };
            reader.readAsDataURL(file);
        });
    }
    

    // Handle document deletion
    handleRemoveDocument(event) {
        const documentId = event.target.dataset.id;
        this.showModal = true; // Show loading modal during deletion
        deleteDocument({ documentId })
            .then(() => {
                this.documents = this.documents.filter((doc) => doc.id !== documentId); // Remove from list
                this.showModal = false; // Hide the modal
                this.showToast('Success', 'Documento removido com sucesso.', 'success');
            })
            .catch((error) => {
                console.error('Error deleting document:', error);
                this.showModal = false; // Hide the modal
                this.showToast('Error', 'Falha ao remover documento.', 'error');
            });
    }

    // Get file type based on extension
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

    // Get file icon based on extension
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

    // Format file size for display
    formatFileSize(bytes) {
        if (bytes === 0) return '0 KB';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }

    // Modal state getter
    get isLoading() {
        return this.showModal;
    }

    get hasDocuments() {
        return this.documents.length > 0;
    }

    get hasSelectedTemplate() {
        return this.selectedTemplate !== null;
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({ title, message, variant });
        this.dispatchEvent(event);
    }
}