import { api, LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getClickSignRecords from '@salesforce/apex/ClickSignController.getClickSignRecords';
import prepareToSend from '@salesforce/apex/ClickSignController.prepareToSend';
import getTemplates from '@salesforce/apex/ClickSignController.getTemplates';
import process from '@salesforce/apex/ClickSignController.process';
import ClickSign_Error from '@salesforce/label/c.ClickSign_Error';
import ClickSign_RecordIdNotFound from '@salesforce/label/c.ClickSign_RecordIdNotFound';
import ClickSign_Success from '@salesforce/label/c.ClickSign_Success';
import ClickSign_DocumentProcessed from '@salesforce/label/c.ClickSign_DocumentProcessed';
import ClickSign_RecipientsProcessed from '@salesforce/label/c.ClickSign_RecipientsProcessed';
import ClickSign_DocumentPreparedAndSent from '@salesforce/label/c.ClickSign_DocumentPreparedAndSent';
import ClickSign_HeaderTitle from '@salesforce/label/c.ClickSign_HeaderTitle';
import ClickSign_SendDocument from '@salesforce/label/c.ClickSign_SendDocument';
import ClickSign_CancelButton from '@salesforce/label/c.ClickSign_CancelButton';

export default class ClickSignTemplateButton extends NavigationMixin(LightningElement) {
    @api recordId;
    clickSignRecords = [];
    error;
    isLoading = false;
    buttonTemplates = [];
    isCreateButtonTemplate = false;
    templateId;
    isModalLoading = false;
    @api recordTypeFilter;
    labels = {
        ClickSign_Error,
        ClickSign_RecordIdNotFound,
        ClickSign_Success,
        ClickSign_DocumentProcessed,
        ClickSign_RecipientsProcessed,
        ClickSign_DocumentPreparedAndSent,
        ClickSign_HeaderTitle,
        ClickSign_SendDocument,
        ClickSign_CancelButton
    };

    connectedCallback() {
        this.fetchClickSignRecords();
        this.fetchTemplates();
    }

    fetchClickSignRecords() {
        if (this.recordId) {
            this.isLoading = true;
            getClickSignRecords({ recordId: this.recordId })
                .then((data) => {
                    this.clickSignRecords = data;
                    this.error = undefined;
                })
                .catch((error) => {
                    this.error = error;
                    this.clickSignRecords = [];
                })
                .finally(() => {
                    this.isLoading = false;
                });
        } else {
            this.error = 'Record ID not found in URL parameters';
        }
    }

    fetchTemplates() {
        if (this.recordId) {
            getTemplates({recordId: this.recordId })
                .then((data) => {
                    this.buttonTemplates = data;
                })
                .catch((error) => {
                    this.error = error;
                });
        }
    }

    handleViewRecord(event) {
        const recordId = event.target.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view',
            },
        });
    }


    handleViewRecordId(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                actionName: 'view',
            },
        });
    }

    handleNameClick(event) {
        const recordId = event.target.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view',
            },
        });
    }

    handleSend() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: `/lightning/n/Send_with_Click_Sign?c__recordId=${this.recordId}`,
            },
        });
        this.refreshPage();
    }

    @track clicksign;
    handleSendDocument() {
        if (this.recordId) {
            this.isModalLoading = true;
            setTimeout(() => {
                prepareToSend({ templateId : this.templateId, recordId: this.recordId})
                    .then((data) => {
                        this.clicksign = data;
                        console.log('this.clicksign', JSON.stringify(this.clicksign));
                        if(data){
                            this.processClickSignDocumentStage();
                        }
                    })
                    .catch((error) => {
                        this.showToast('Error', error.body.message, 'error');
                        this.isModalLoading = false;
                    })
                    .finally(() => {
                    });
            }, 1000);
        } else {
            this.showToast('Error', 'Record ID not found', 'error');
        }
    }

    processClickSignDocumentStage() {
        setTimeout(() => {
            process({ clickSign: this.clicksign, recordId: this.recordId, currentStep : 'Documents'})
                .then((result) => {
                    this.showToast('Success', 'Document processed successfully', 'success');
                    if(result){
                        this.processClickSignRecipientsStage();
                    }
                })
                .catch((error) => {
                    this.showToast('Error', error.body.message, 'error');
                    this.isModalLoading = false;
                })
                .finally(() => {
                });
        }, 1000);
    }
    processClickSignRecipientsStage() {
        setTimeout(() => {
            process({ clickSign: this.clicksign, recordId: this.recordId, currentStep : 'Recipients'})
                .then((result) => {
                    this.showToast('Success', 'Recipients processed successfully', 'success');
                    if(result){
                        this.processClickSignCompletionStage();
                    }
                })
                .catch((error) => {
                    this.showToast('Error', error.body.message, 'error');
                    this.isModalLoading = false;
                })
                .finally(() => {
                });
        }, 1000);
    }
    processClickSignCompletionStage() {
        setTimeout(() => {
            process({ clickSign: this.clicksign, recordId: this.recordId, currentStep : 'Prepare & Send'})
                .then((result) => {
                    if(result){
                        this.showToast('Success', 'Document prepared and sent successfully', 'success');
                    }
                })
                .catch((error) => {
                    this.showToast('Error', error.body.message, 'error');
                    this.isModalLoading = false;
                })
                .finally(() => {
                    this.isModalLoading = false;
                    this.handleViewRecordId();
                });
        }, 1000);
    }


    handleOpenModal(event) {
        this.templateId = event.target.dataset.id;
        this.isCreateButtonTemplate = true;
    }

    handleCloseModal() {
        this.isCreateButtonTemplate = false;
        this.templateId = null;
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }

    refreshPage() {
        eval("$A.get('e.force:refreshView').fire();");
    }
}