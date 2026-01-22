import { api, LightningElement, track, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getOrCreateClickSign from '@salesforce/apex/ClickSignController.getOrCreateClickSign';
import createNewClickSign from '@salesforce/apex/ClickSignController.createNewClickSign';
import cancelAndCreateClickSign from '@salesforce/apex/ClickSignController.cancelAndCreateClickSign';
import process from '@salesforce/apex/ClickSignController.process';
import updateClickSignCurrentStep from '@salesforce/apex/ClickSignController.updateClickSignCurrentStep';
import { RefreshEvent } from 'lightning/refresh';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import ClickSign_HeaderTitle from '@salesforce/label/c.ClickSign_HeaderTitle';
import ClickSign_CancelButton from '@salesforce/label/c.ClickSign_CancelButton';
import ClickSign_BackButton from '@salesforce/label/c.ClickSign_BackButton';
import ClickSign_NextButton from '@salesforce/label/c.ClickSign_NextButton';
import ClickSign_ModalHeader from '@salesforce/label/c.ClickSign_ModalHeader';
import ClickSign_ModalContent from '@salesforce/label/c.ClickSign_ModalContent';
import ClickSign_ContinueButton from '@salesforce/label/c.ClickSign_ContinueButton';
import ClickSign_NewDocumentButton from '@salesforce/label/c.ClickSign_NewDocumentButton';
import ClickSign_ObjectSelectionModalHeader from '@salesforce/label/c.ClickSign_ObjectSelectionModalHeader';
import ClickSign_CloseButton from '@salesforce/label/c.ClickSign_CloseButton';
import ClickSign_LoadingText from '@salesforce/label/c.ClickSign_LoadingText';

export default class ClickSign extends NavigationMixin(LightningElement) {
    @track currentStep = 'Documents'; // Initial phase
    @track clickSignRecord;
    @track showModal = false;
    @track isLoading = false;
    @track showObjectSelectionModal = false;
    @api recordId;
    phases = [
        { label: 'Documents', value: 'Documents' },
        { label: 'Recipients', value: 'Recipients' },
        { label: 'Prepare & Send', value: 'Prepare & Send' }
    ];

    labels = {
        headerTitle: ClickSign_HeaderTitle,
        cancelButton: ClickSign_CancelButton,
        backButton: ClickSign_BackButton,
        nextButton: ClickSign_NextButton,
        modalHeader: ClickSign_ModalHeader,
        modalContent: ClickSign_ModalContent,
        continueButton: ClickSign_ContinueButton,
        newDocumentButton: ClickSign_NewDocumentButton,
        objectSelectionModalHeader: ClickSign_ObjectSelectionModalHeader,
        closeButton: ClickSign_CloseButton,
        loadingText: ClickSign_LoadingText
    };

    @wire(CurrentPageReference)
    currentPageReference(value) {
        if (value) {
            console.log('currentPageReference', value);
            const newRecordId = value.state?.c__recordId;
            this.recordId = newRecordId;
            console.log('recordId', this.recordId);
            if (this.recordId) {
                this.initializeClickSign();
            } else {
                this.showObjectSelectionModal = true;
            }
        }
    }

    connectedCallback() {
        this.resetComponentState();
        document.addEventListener('click', this.handleOutsideClick.bind(this));

    }

    resetComponentState() {
        this.currentStep = 'Documents';
        this.clickSignRecord = null;
        this.showModal = false;
        this.isLoading = false;
        this.showObjectSelectionModal = false;
    }

    disconnectedCallback() {
        window.removeEventListener('beforeunload', this.handleUnload.bind(this));
        document.removeEventListener('click', this.handleOutsideClick.bind(this));
    }

    refreshComponent() {
        this.resetComponentState();
        if (this.recordId) {
            this.initializeClickSign();
        }
    }
    
    handleOutsideClick(event) {
        // Logic to handle clicks outside the component
        if (!this.template.contains(event.target)) {
            this.closeModal();
        }
    }

    handleUnload() {
        this.resetComponentState();
    }

    handleObjectSelection(event) {
        console.log('handleObjectSelection');
        this.recordId = event.detail;
        console.log('handleObjectSelection', this.recordId);
        
        this.initializeClickSign();
        this.showObjectSelectionModal = false;

    }

    initializeClickSign() {
        this.isLoading = true;
        getOrCreateClickSign({ recordId: this.recordId })
            .then(result => {
                this.clickSignRecord = result;
                if (this.clickSignRecord != null && this.clickSignRecord.Status__c !== 'Cancelled') {
                    this.showModal = true;
                    this.isLoading = false;
                } else {
                    this.createNewClickSign();
                }
            })
            .catch(error => {
                console.error('Error initializing ClickSign:', error);
                this.showToast('Error', 'Erro ao iniciar o ClickSign.', 'error');
                this.isLoading = false;
            });
    }

    handleContinue() {
        this.showModal = false;
        this.currentStep = this.clickSignRecord.CurrentStep__c;
    }

    handleNewDocument() {
        this.showModal = false;
        this.cancelAndCreateClickSign();
    }

    cancelAndCreateClickSign() {
        this.isLoading = true;
        console.log('cancelAndCreateClickSign');
        cancelAndCreateClickSign({ recordId: this.recordId })
            .then(result => {
                if(result){
                    this.clickSignRecord = result;
                    console.log('(this.clickSignRecord',this.clickSignRecord)
                    this.dispatchEvent(new RefreshEvent());
                    this.isLoading = false;
                }
            })
            .catch(error => {
                console.error('Error creating new ClickSign:', error);
                this.showToast('Error', 'Erro ao criar novo ClickSign.', 'error');
                this.isLoading = false;
            });
    }

    createNewClickSign() {
        this.isLoading = true;
        console.log('createNewClickSign');
        createNewClickSign({ recordId: this.recordId })
            .then(result => {
                this.clickSignRecord = result;
                this.currentStep = 'Documents';
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error creating new ClickSign:', error);
                this.showToast('Error', 'Erro ao criar novo ClickSign.', 'error');
                this.isLoading = false;
            });
    }

    // Computed properties to toggle child components
    get isDocumentsPhase() {
        return this.currentStep === 'Documents';
    }

    get isRecipientsPhase() {
        return this.currentStep === 'Recipients';
    }

    get isPrepareSendPhase() {
        return this.currentStep === 'Prepare & Send';
    }

    get isBackDisabled() {
        return this.currentStep === 'Documents';
    }

    get isNextDisabled() {
        return this.currentStep === 'Prepare & Send';
    }

    handlePhaseChange(event) {
        this.currentStep = event.detail.value;
        this.updateClickSignCurrentStep();
    }

    updateClickSignCurrentStep() {
        this.isLoading = true;
        updateClickSignCurrentStep({ clickSignId: this.clickSignRecord.Id, currentStep: this.currentStep })
            .then(() => {
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error updating ClickSign status:', error);
                this.showToast('Error', 'Erro ao atualizar etapa do ClickSign.', 'error');
                this.isLoading = false;
            });
    }

    handleCancel() {
        this.resetComponentState();
        this.handleCloseModal();
    }

    handleBack() {
        this.isLoading = true;
        setTimeout(() => {
            const currentIndex = this.phases.findIndex((phase) => phase.value === this.currentStep);
            if (currentIndex > 0) {
                this.currentStep = this.phases[currentIndex - 1].value;
                this.updateClickSignCurrentStep();
            }
            this.isLoading = false;
        }, 500); // 500ms delay
    }

    handleNext() {
        this.isLoading = true;
        console.log('clickSign', JSON.stringify(this.clickSignRecord));
        console.log('recordId', this.recordId);
        process({ clickSign: this.clickSignRecord, recordId: this.recordId })
            .then(result => {
                console.log('result', result);
                if (result == 'success') {
                    const currentIndex = this.phases.findIndex((phase) => phase.value === this.currentStep);
                    console.log('currentIndex', currentIndex);
                    console.log('this.phases', this.phases);
                    if (currentIndex < this.phases.length - 1) {
                        this.currentStep = this.phases[currentIndex + 1].value;
                        this.updateClickSignCurrentStep();
                    }
                    console.log('success', this.currentStep);
                }
            })
            .catch(error => {
                console.error('Error processing ClickSign:', error);
                this.showToast('Error', 'Erro ao processar o ClickSign.', 'error');
                this.isLoading = false;
            });
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
        this.updateClickSignCurrentStep();
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({ title, message, variant });
        this.dispatchEvent(event);
    }


    handleCloseModal() {
        this.showModal = false;
        this.showObjectSelectionModal = false;
        if (this.recordId) {
            this.navigateToRecordPage();
        } else {
            this.navigateToListView();
        }
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

    navigateToListView() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'ClickSign__c',
                actionName: 'list'
            }
        });
    }
}
