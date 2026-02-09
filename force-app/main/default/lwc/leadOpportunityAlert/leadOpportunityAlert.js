import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

const FIELDS = [
    'Opportunity.RecordType.DeveloperName',
    'Opportunity.CreatedDate'
];

export default class LeadOpportunityAlert extends LightningElement {
    @api recordId;
    recordTypeDeveloperName;
    createdDate;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    opportunity({ error, data }) {
        if (data) {
            this.recordTypeDeveloperName = data.fields.RecordType.value.fields.DeveloperName.value;
            this.createdDate = data.fields.CreatedDate.value;
        } else if (error) {
            // Handle error if needed
        }
    }

    get showAlert() {
        return (
            this.recordTypeDeveloperName === 'Solar' &&
            new Date(this.createdDate) < new Date('2025-08-12')
        );
    }
}
