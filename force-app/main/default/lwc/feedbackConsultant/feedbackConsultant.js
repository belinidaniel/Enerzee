import { LightningElement, track, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { updateRecord, getRecord } from 'lightning/uiRecordApi';
import saveFeedback from '@salesforce/apex/FeedbackController.saveFeedback';

const FIELDS = [
    'Feedback__c.Opportunity_Name__c',
    'Feedback__c.ProposalNumber__c',
    'Feedback__c.OwnerOpportunity__c',
    'Feedback__c.Consultant__r.Name',
    'Feedback__c.Score__c'
];

export default class FeedbackConsultant extends LightningElement {
    @track score = null;
    @track note = '';
    @track feedbackSubmitted = false;
    @api recordId;
    @track opportunityName;
    @track opportunityOwner;
    @track opportunityProposalNumber;
    @track tasks = [];

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    opportunity({ error, data }) {
        if (data) {
            this.opportunityName = data.fields.Opportunity_Name__c.value;
            this.opportunityOwner = data.fields.OwnerOpportunity__c.value;
            this.opportunityProposalNumber = data.fields.ProposalNumber__c.value;
            this.feedbackSubmitted = data.fields.Score__c.value != null ? true : false;
        } else if (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Erro ao carregar dados',
                message: error.body.message,
                variant: 'error',
            }));
        }
    }

    // Rating options for NPS (1-5)
    ratingOptions = [
        { label: '1 - Poor', value: 1 },
        { label: '2 - Fair', value: 2 },
        { label: '3 - Average', value: 3 },
        { label: '4 - Good', value: 4 },
        { label: '5 - Excellent', value: 5 }
    ];

    // Handle star click
    handleStarClick(event) {
        console.log(this.recordId);
        const selectedValue = event.target.dataset.value; // Get the value from the clicked star
        this.score = selectedValue; // Set the score
        this.updateStarClasses();  // Update the classes of stars based on score
    }

    // Update star classes based on the current score
    updateStarClasses() {
        // Loop through the ratingOptions and set the class based on score
        this.ratingOptions = this.ratingOptions.map(option => {
            return {
                ...option,
                className: this.score >= option.value ? 'star-filled' : 'star-empty'
            };
        });
    }

    // Handle note change
    handleNoteChange(event) {
        this.note = event.target.value;
    }

    // Handle form submission
    handleSubmit() {
        saveFeedback({ recordId: this.recordId, score: this.score, notes: this.note })
            .then(() => {
                this.score = '';
                this.note = '';
                this.feedbackSubmitted = true;
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error submitting feedback',
                        message: error.body.message,
                        variant: 'error',
                    }),
                );
            });
    }
}