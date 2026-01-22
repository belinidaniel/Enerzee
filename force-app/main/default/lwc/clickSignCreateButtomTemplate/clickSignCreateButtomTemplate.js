import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getClickSignTemplateToSend from '@salesforce/apex/ClickSignTemplateController.getClickSignTemplateToSend';
import getClickSignTemplate from '@salesforce/apex/ClickSignTemplateController.getClickSignTemplate';
import createButtonInLayout from '@salesforce/apex/ClickSignTemplateController.createButtonInLayout';
import generateMapFields from '@salesforce/apex/ClickSignUtils.generateMapFields';
import ClickSign_CreateButtonTitle from '@salesforce/label/c.ClickSign_CreateButtonTitle';
import ClickSign_CreateButtonDescription from '@salesforce/label/c.ClickSign_CreateButtonDescription';
import ClickSign_TemplateDetails from '@salesforce/label/c.ClickSign_TemplateDetails';
import ClickSign_TemplateName from '@salesforce/label/c.ClickSign_TemplateName';
import ClickSign_TemplateDescription from '@salesforce/label/c.ClickSign_TemplateDescription';
import ClickSign_TemplateObject from '@salesforce/label/c.ClickSign_TemplateObject';
import ClickSign_ButtonLabel from '@salesforce/label/c.ClickSign_ButtonLabel';
import ClickSign_CreateButtonInLayout from '@salesforce/label/c.ClickSign_CreateButtonInLayout';
import ClickSign_SuccessMessage from '@salesforce/label/c.ClickSign_SuccessMessage';
import ClickSign_Recipients from '@salesforce/label/c.ClickSign_Recipients';
import ClickSign_FieldName from '@salesforce/label/c.ClickSign_FieldName';
import ClickSign_Email from '@salesforce/label/c.ClickSign_Email';
import ClickSign_RoleLabel from '@salesforce/label/c.ClickSign_RoleLabel';
import ClickSign_Fields from '@salesforce/label/c.ClickSign_Fields';
import ClickSign_Tag from '@salesforce/label/c.ClickSign_Tag';
import ClickSign_TagLabel from '@salesforce/label/c.ClickSign_TagLabel';
import ClickSign_NoTemplateData from '@salesforce/label/c.ClickSign_NoTemplateData';
import ClickSign_TagValue from '@salesforce/label/c.ClickSign_TagValue';


export default class ClickSignCreateButtomTemplate extends LightningElement {
    @api templateId;
    @track template; // Stores the full template JSON
    @api recordId;
    @track isLoading = false;
    @track contactsMapping = [];
    @track objectMappings = [];
    @track buttonLabel = '';
    @track successMessage = '';
    @api isSendTemplate = false;
    @track title;
    labels = {
        createButtonTitle: ClickSign_CreateButtonTitle,
        createButtonDescription: ClickSign_CreateButtonDescription,
        templateDetails: ClickSign_TemplateDetails,
        templateName: ClickSign_TemplateName,
        templateDescription: ClickSign_TemplateDescription,
        templateObject: ClickSign_TemplateObject,
        buttonLabel: ClickSign_ButtonLabel,
        createButtonInLayout: ClickSign_CreateButtonInLayout,
        successMessage: ClickSign_SuccessMessage,
        recipients: ClickSign_Recipients,
        fieldName: ClickSign_FieldName,
        email: ClickSign_Email,
        roleLabel: ClickSign_RoleLabel,
        fields: ClickSign_Fields,
        tag: ClickSign_Tag,
        tagLabel: ClickSign_TagLabel,
        noTemplateData: ClickSign_NoTemplateData,
        tagValue: ClickSign_TagValue
    };
    connectedCallback() {
        if(this.isSendTemplate){
            this.title = '';
        }else{
            this.title = 'Create Custom Button"';
        }
        if(this.isSendTemplate){
            this.getClickSignTemplateToSend();
        }else{
            this.getClickSignTemplate();
        }
    }

    getClickSignTemplateToSend() {
        this.isLoading = true;
        console.log('result templateId', this.templateId);
        this.recordId == null? this.recordId = '5008900000GJg2MAAT' : this.recordId;
        getClickSignTemplateToSend({ templateId: this.templateId ,recordId: this.recordId})
            .then((result) => {
                if(result){
                    this.template = result;
                    this.contactsMapping = this.template.ClickSignSigners__r;
                    this.objectMappings = JSON.parse(this.template.ObjectMappings__c);
                    this.buttonLabel = this.template.ButtonLabel__c;
                    this.fetchObjectMappingValues();
                }
            })
            .catch((error) => {
                console.error('Error loading template 2222:', error);
                this.showToast('Error', 'Falha ao carregar o template.', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    getClickSignTemplate() {
        this.isLoading = true;
        console.log('result templateId', this.templateId);
        this.recordId == null? this.recordId = '5008900000GJg2MAAT' : this.recordId;
        getClickSignTemplate({ templateId: this.templateId ,recordId: this.recordId})
            .then((result) => {
                if(result){
                    this.template = result;
                    this.contactsMapping = this.template.ClickSignSigners__r;
                    this.objectMappings = JSON.parse(this.template.ObjectMappings__c);
                    this.buttonLabel = this.template.ButtonLabel__c;
                    this.fetchObjectMappingValues();
                }
            })
            .catch((error) => {
                console.error('Error loading template 2222:', error);
                this.showToast('Error', 'Falha ao carregar o template.', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    fetchObjectMappingValues() {
        console.log('fetchObjectMappingValues' , this.recordId);
        generateMapFields({ recordId: this.recordId, objectMappings: this.template.ObjectMappings__c, contractNumber: null, jsonContractInformation: null })
            .then((data) => {
                const mapFields = JSON.parse(data);
                console.log('objectMappings 2', JSON.stringify(mapFields));
                this.objectMappings = this.objectMappings.map(field => {
                    return {
                        ...field,
                        tagValue: mapFields[field.tagLabel.replace('{{', '').replace('}}', '')] || ''
                    };
                });
                console.log('objectMappings 2', JSON.stringify(this.objectMappings ));
            })
            .catch((error) => {
                this.showToast('Error', error.body.message, 'error');
            });
    }

    handleButtonLabelChange(event) {
        this.buttonLabel = event.target.value;
    }

    createButton() {
        createButtonInLayout({ templateId: this.templateId, buttonLabel: this.buttonLabel })
            .then(() => {
                this.successMessage = 'Button created with success!';
            })
            .catch((error) => {
                console.error('Error creating button:', error);
                this.showToast('Error', 'Falha ao criar o botão.', 'error');
            });
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
        this.notifyParent(title, message, variant);
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
