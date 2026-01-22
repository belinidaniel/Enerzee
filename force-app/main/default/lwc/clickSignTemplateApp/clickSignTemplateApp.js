// clickSignTemplateApp.js
import { LightningElement, api, track } from 'lwc';
import createClickSignTemplate from '@salesforce/apex/ClickSignTemplateController.createClickSignTemplate';
import getClickSignTemplate from '@salesforce/apex/ClickSignTemplateController.getClickSignTemplate';
import updateClickSignTemplate from '@salesforce/apex/ClickSignTemplateController.updateClickSignTemplate';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import ClickSign_CancelButton from '@salesforce/label/c.ClickSign_CancelButton';
import ClickSign_BackButton from '@salesforce/label/c.ClickSign_BackButton';
import ClickSign_NextButton from '@salesforce/label/c.ClickSign_NextButton';
import ClickSign_CreateButtonTitle from '@salesforce/label/c.ClickSign_CreateButtonTitle';
import ClickSign_CreateButtonDescription from '@salesforce/label/c.ClickSign_CreateButtonDescription';
import ClickSign_TemplateName from '@salesforce/label/c.ClickSign_TemplateName';
import ClickSign_TemplateDescription from '@salesforce/label/c.ClickSign_TemplateDescription';
import ClickSign_SelectDataSource from '@salesforce/label/c.ClickSign_SelectDataSource';
import ClickSign_HeaderTitle from '@salesforce/label/c.ClickSign_HeaderTitle';

export default class ClickSignTemplateApp extends NavigationMixin(LightningElement) {
    @api templateId;
    @api isCreating;
    @track isLoading = false;
    @track currentStep = ''; // Initial phase
    @track isSourcePhase = true; // Render Select Data Source phase
    @track isAddFields = false;
    @track isUploadDocuments = false;
    @track isPreviewDocuments = false;
    @track isCreatebutton = false;
    @track isRecipient = false;
    @track clickSignTemplate = '';
    @track fileName = '';
    @track showModal = false;
    @track isCreateButtonTemplate = false;
    @track showBanner = false;
    @track bannerTitle = '';
    @track bannerMessage = '';
    @track bannerVariant = 'info';

    objectName;
    phases = [
        { label: 'Select Source', value: 'Select Source' },
        { label: 'Add Fields', value: 'Add Fields' },
        { label: 'Upload Documents', value: 'Upload Documents' },
        { label: 'Add Recipient', value: 'Add Recipient' },
        { label: 'Preview Documents', value: 'Preview Documents' },
        { label: 'Create button Template', value: 'Create button Template' }
    ];

    labels = {
        cancelButton: ClickSign_CancelButton,
        backButton: ClickSign_BackButton,
        nextButton: ClickSign_NextButton,
        createButtonTitle: ClickSign_CreateButtonTitle,
        createButtonDescription: ClickSign_CreateButtonDescription,
        templateName: ClickSign_TemplateName,
        templateDescription: ClickSign_TemplateDescription,
        selectDataSource: ClickSign_SelectDataSource,
        headerTitle: ClickSign_HeaderTitle
    };

    connectedCallback() {
        this.loadTemplate();
        document.addEventListener('click', this.handleOutsideClick.bind(this));
    }

    disconnectedCallback() {
        document.removeEventListener('click', this.handleOutsideClick.bind(this));
    }

    handleOutsideClick(event) {
        // Logic to handle clicks outside the component
        if (!this.template.contains(event.target)) {
            this.closeModal();
        }
    }

    handleFieldsChange(event){
        this.clickSignTemplate.ObjectMappings__c = JSON.stringify(event.detail);
    }
    handleContactFieldsChange(event){
        this.clickSignTemplate.ContactsMapping__c = JSON.stringify(event.detail);
        console.log('handleContactFieldsChange',   this.clickSignTemplate.ContactsMapping__c );
    }


    closeModal() {
        // this.showModal = false;
    }

    loadTemplate(){
        this.isLoading = true;
        if (this.templateId) {
            this.getTemplate();
        } else {
            this.isCreating = true;
            this.isLoading = false;
            this.showModal = true;
        }
    }
    getTemplate() {
        getClickSignTemplate({ templateId: this.templateId })
        .then(template => {
            if(template){
                this.clickSignTemplate = template;
                this.objectName = template.SourceObject__c;
                this.currentStep = template.Stage__c;
                this.updatePhaseFlags();
                this.isLoading = false;
                this.showModal = false;
            }
        })
        .catch(error => {
            console.error('Error fetching ClickSignTemplate:', error);
            this.showBannerMessage('Error', 'Falha ao carregar o template do ClickSign.', 'error');
            this.showToast('Error', 'Falha ao carregar o template do ClickSign.', 'error');
        });
    }

    handleFileNameChange(event) {
        this.fileName = event.detail.value; // Correctly assign the value to the instance variable
        this.clickSignTemplate.FileName__c = event.detail.value;
    }
    
    updateTemplate() {
        console.log('Updating ClickSignTemplate:', JSON.stringify(this.clickSignTemplate));
        updateClickSignTemplate({ template : this.clickSignTemplate })
        .then(() => {
            this.isLoading = false;
        })
        .catch(error => {
            console.error('Error updating ClickSignTemplate:', error);
            this.showBannerMessage('Error', 'Falha ao atualizar o template do ClickSign.', 'error');
            this.showToast('Error', 'Falha ao atualizar o template do ClickSign.', 'error');
            this.isLoading = false;
        });
    }

    async handleSave() {
        const name = this.template.querySelector('[data-id="templateName"]').value;
        const description = this.template.querySelector('[data-id="templateDescription"]').value;

        console.log('Template Name:', name);
        console.log('Description:', description);
        console.log('Selected Data Source:', JSON.stringify(this.objectName));

        try {
            const result = await createClickSignTemplate({ 
                name: name, 
                description: description, 
                objectName: this.objectName 
            });
            console.log('New ClickSignTemplate Id:', result);
            if(result != null){
                this.templateId = result;
                this.loadTemplate();
            }
        } catch (error) {
            console.error('Error creating ClickSignTemplate:', error);
            this.showBannerMessage('Error', 'Falha ao criar o template do ClickSign.', 'error');
            this.showToast('Error', 'Falha ao criar o template do ClickSign.', 'error');
        }

        this.closeModal();
    }

    handleObjectSelection(event) {
        this.objectName = event.detail.objectName; // Assuming the event contains the selected data source
    }
    

    // Handle object selection from data source
    handleUpdateObject(event) {
        this.objectName = event.detail.objectName; // Assuming the event contains the selected data source
        console.log('objectName ' ,this.objectName );
        if(this.objectName != this.clickSignTemplate.SourceObject__c ){
            this.clickSignTemplate.ObjectMappings__c = '';
        }
        this.clickSignTemplate.SourceObject__c = this.objectName; 
    }

    @track refreshKey = 0;

    refreshComponent() {
        this.refreshKey = Date.now(); // Changing key value forces re-render
    }

    handleBack() {
        this.isLoading = true;
        const currentIndex = this.phases.findIndex((phase) => phase.value === this.currentStep);
        console.log('currentIndex ' ,currentIndex );
        if (currentIndex > 0) {
            this.currentStep = this.phases[currentIndex - 1].value;
            this.updatePhaseFlags();
        }
        console.log('currentStep ' ,this.currentStep );
        this.clickSignTemplate.Stage__c = this.currentStep;
        this.updateTemplate();
    }
    
    handleCreate(){
        this.clickSignTemplate.IsActivate__c = true;
        this.updateTemplate();
        setTimeout(() => {
            this.navigateToRecentListView();
        }, 1000); // Add a delay of 1 second before navigating
    }

    handleNext() {
        this.isLoading = true;
        const currentIndex = this.phases.findIndex((phase) => phase.value === this.currentStep);
        if (currentIndex < this.phases.length - 1) {
            this.currentStep = this.phases[currentIndex + 1].value;
            this.updatePhaseFlags();
        }
        console.log('currentStep ' ,this.currentStep );
        this.clickSignTemplate.Stage__c = this.currentStep;
        console.log('this.clickSignTemplate. ' ,this.clickSignTemplate );
        this.refreshComponent();
        this.updateTemplate();
    }

    handlePathStepChange(event) {
        const nextStep = event.detail?.value;
        if (!nextStep || nextStep === this.currentStep) {
            return;
        }
        const isValidStep = this.phases.some((phase) => phase.value === nextStep);
        if (!isValidStep) {
            return;
        }
        this.currentStep = nextStep;
        this.updatePhaseFlags();
        this.clickSignTemplate.Stage__c = this.currentStep;
        this.refreshComponent();
        this.updateTemplate();
    }

    updatePhaseFlags() {
        this.isSourcePhase = this.currentStep === 'Select Source';
        this.isAddFields = this.currentStep === 'Add Fields';
        this.isUploadDocuments = this.currentStep === 'Upload Documents';
        this.isRecipient = this.currentStep === 'Add Recipient';
        this.isPreviewDocuments = this.currentStep === 'Preview Documents';
        this.isCreateButtonTemplate = this.currentStep === 'Create button Template';
        if(this.currentStep === 'Create button Template'){
            this.isCreateButton = true;
        }else{
            this.isCreateButton = false;
        }
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }

    handleNotify(event) {
        const detail = event.detail || {};
        this.showBannerMessage(detail.title || 'Aviso', detail.message || '', detail.variant || 'info');
    }

    showBannerMessage(title, message, variant) {
        this.bannerTitle = title;
        this.bannerMessage = message;
        this.bannerVariant = variant;
        this.showBanner = true;
        this.clearBannerTimeout();
        this.bannerTimeoutId = setTimeout(() => {
            this.showBanner = false;
        }, 5000);
    }

    handleBannerClose() {
        this.showBanner = false;
        this.clearBannerTimeout();
    }

    clearBannerTimeout() {
        if (this.bannerTimeoutId) {
            clearTimeout(this.bannerTimeoutId);
            this.bannerTimeoutId = null;
        }
    }

    get bannerClass() {
        const themeClass = this.bannerVariant === 'success'
            ? 'slds-theme_success'
            : this.bannerVariant === 'warning'
                ? 'slds-theme_warning'
                : this.bannerVariant === 'error'
                    ? 'slds-theme_error'
                    : 'slds-theme_info';
        return `slds-notify slds-notify_alert slds-theme_alert-texture ${themeClass}`;
    }

    navigateToRecordPage() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.templateId,
                actionName: 'view'
            }
        });
    }

    handleCancel() {
        if (this.templateId) {
            this.navigateToRecordPage();
        } else {
            this.navigateToListView();
        }
    }

    navigateToListView() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'ClickSignTemplate__c',
                actionName: 'list'
            }
        });
    }

    navigateToRecentListView() {
        const pageRef = {
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'ClickSignTemplate__c',
                actionName: 'list'
            },
            state: {
                filterName: '__Recent'
            }
        };

        // Fallback for Visualforce context where NavigationMixin may not redirect
        this[NavigationMixin.GenerateUrl](pageRef)
            .then((url) => {
                const targetUrl = url || '/lightning/o/ClickSignTemplate__c/list?filterName=__Recent';
                const event = new CustomEvent('redirect', {
                    detail: { url: targetUrl },
                    bubbles: true,
                    composed: true,
                    cancelable: true
                });
                const handled = this.dispatchEvent(event) === false;
                if (handled) {
                    return;
                }
                // Try postMessage to parent (Visualforce / Lightning Out)
                try {
                    if (window.top && window.top !== window) {
                        window.top.postMessage({ type: 'clicksign:navigate', url: targetUrl }, '*');
                        return;
                    }
                } catch (e) {
                    // fall through to direct navigation
                }
                // Visualforce may be embedded in an iframe, so use top-level navigation
                if (window.top) {
                    window.top.location.assign(targetUrl);
                } else {
                    window.location.assign(targetUrl);
                }
            })
            .catch(() => {
                const fallbackUrl = '/lightning/o/ClickSignTemplate__c/list?filterName=__Recent';
                if (window.top) {
                    window.top.location.assign(fallbackUrl);
                } else {
                    window.location.assign(fallbackUrl);
                }
            });
    }
}
