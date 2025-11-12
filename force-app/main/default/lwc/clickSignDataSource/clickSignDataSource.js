import { api, LightningElement, track } from 'lwc';
import getObjectList from '@salesforce/apex/DataSourceController.getObjectList';
import getRecords from '@salesforce/apex/DataSourceController.getRecords';
import ClickSign_SelectDataSource from '@salesforce/label/c.ClickSign_SelectDataSource';
import ClickSign_Search from '@salesforce/label/c.ClickSign_Search';
import ClickSign_MostCommonlyUsed from '@salesforce/label/c.ClickSign_MostCommonlyUsed';
import ClickSign_OtherItems from '@salesforce/label/c.ClickSign_OtherItems';
import ClickSign_SearchRecords from '@salesforce/label/c.ClickSign_SearchRecords';
import ClickSign_NoRecordsFound from '@salesforce/label/c.ClickSign_NoRecordsFound';

export default class ClickSignDataSource extends LightningElement {
    @track mostCommonlyUsed = [];
    @track otherItems = [];
    @track allObjects = [];
    @track selectedObject = '';
    @track selectedObjectLabel = '';
    @track selectedObjectIcon = '';
    @track records = [];
    @track showRecordSearch = false;
    @track selectedRecord = null;
    @track isLoading = false; // Tracks loading state
    @api selectRecord = false;
    @api objectName;
    @api disableObjectSelection = false;

    labels = {
        selectDataSource: ClickSign_SelectDataSource,
        search: ClickSign_Search,
        mostCommonlyUsed: ClickSign_MostCommonlyUsed,
        otherItems: ClickSign_OtherItems,
        searchRecords: ClickSign_SearchRecords,
        noRecordsFound: ClickSign_NoRecordsFound
    };

    connectedCallback() {
        this.loadObjects();
    }

    loadObjects() {
        this.isLoading = true;
        getObjectList()
            .then((result) => {
                
                this.allObjects = result.map((object) => ({
                    label: object.label,
                    value: object.apiName,
                    icon: this.getIconForObject(object.apiName),
                    objectName: object.apiName
                }));
                console.log('allObjects',JSON.stringify(this.allObjects))

                this.mostCommonlyUsed = this.allObjects.filter((obj) =>
                    ['account', 'case', 'contact', 'lead', 'opportunity'].includes(obj.value)
                );
                this.otherItems = this.allObjects.filter(
                    (obj) => !['account', 'case', 'contact', 'lead', 'opportunity'].includes(obj.value)
                );
                
                if (this.objectName) {
                    const selectedObject = this.allObjects.find((obj) => obj.value === this.objectName);
                    if (selectedObject) {
                        this.selectedObject = selectedObject.value;
                        this.selectedObjectLabel = selectedObject.label;
                        this.selectedObjectIcon = selectedObject.icon;
                        if (this.selectRecord == "true") {
                            this.showRecordSearch = true;
                        } else {
                            const selectEvent = new CustomEvent('selectobject', { detail: selectedObject });
                            this.dispatchEvent(selectEvent);
                        }
                    }
                }

                this.isLoading = false;

            })
            .catch((error) => {
                console.error('Error fetching object list:', error);
                this.isLoading = false;
            });
    }

    getIconForObject(objectName) {
        const iconMapping = {
            account: 'standard:account',
            case: 'standard:case',
            contact: 'standard:contact',
            lead: 'standard:lead',
            opportunity: 'standard:opportunity',
            default: `standard:account_info`
        };
        return iconMapping[objectName.toLowerCase()] || iconMapping.default;
    }

    handleSearch(event) {
        const searchTerm = event.target.value.toLowerCase();
        if (this.selectedObject) {
            this.searchRecords(searchTerm);
        } else {
            this.mostCommonlyUsed = this.allObjects.filter(
                (obj) =>
                    ['Account', 'Case', 'Contact', 'Lead', 'Opportunity'].includes(obj.label) &&
                    obj.label.toLowerCase().includes(searchTerm)
            );
            this.otherItems = this.allObjects.filter(
                (obj) =>
                    !['Account', 'Case', 'Contact', 'Lead', 'Opportunity'].includes(obj.label) &&
                    obj.label.toLowerCase().includes(searchTerm)
            );
        }
    }

    handleObjectSelection(event) {
        if (this.disableObjectSelection) {
            return;
        }
        const selectedValue = event.currentTarget.dataset.value;
        const selectedObject = this.allObjects.find((obj) => obj.value === selectedValue);

        this.selectedObject = selectedObject.value;
        this.selectedObjectLabel = selectedObject.label;
        this.selectedObjectIcon = selectedObject.icon;

       
        this.records = [];
        if(this.selectRecord == "true"){
            this.showRecordSearch = true;
        }else{
            console.log('selectobject 3',JSON.stringify(selectedObject));
            const selectEvent = new CustomEvent('selectobject', { detail: selectedObject });
            this.dispatchEvent(selectEvent);
            this.showRecordSearch = false;
        }
    }

    handleRecordSelection(event) {
        const selectedRecordId = event.currentTarget.dataset.value;
        this.selectedRecord = this.records.find(record => record.Id === selectedRecordId);
        this.showRecordSearch = false;
        // Dispatch event to parent component
        const selectEvent = new CustomEvent('selectrecord', { detail: selectedRecordId });
        const selectEvent2 = new CustomEvent('selectdetail', { detail: this.selectedRecord});

        this.dispatchEvent(selectEvent);
        this.dispatchEvent(selectEvent2);
    }

    removeObjectSelection() {
        this.selectedObject = '';
        this.selectedObjectLabel = '';
        this.selectedObjectIcon = '';
        this.records = [];
        this.showRecordSearch = false;
    }

    searchRecords(searchTerm) {
        if (!searchTerm || searchTerm.trim() === '') {
            this.records = [];
            return;
        }

        const searchParams = {
            objectName: this.selectedObject,
            searchTerm: searchTerm.trim(),
        };

        getRecords(searchParams)
            .then((result) => {
                this.records = result.map((record) => ({
                    ...record,
                    icon: this.getIconForObject(this.selectedObject),
                    objectName: this.selectedObject,
                    objectLabel: record.Name || record.CaseNumber || record.Id, // Fallback to Id if no Name or CaseNumber
                }));
            })
            .catch((error) => {
                console.error('Error fetching records:', error);
                this.records = []; // Clear records in case of an error
            });
    }
}