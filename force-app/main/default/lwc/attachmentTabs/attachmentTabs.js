import { LightningElement, api, track } from 'lwc';
import getAttachments from '@salesforce/apex/ActivityDocumentController.getAttachments';

export default class AttachmentTabs extends LightningElement {
    @api sobjectId;
    @track groups = [];
    @track loading = false;

    connectedCallback() {
        this.load();
    }

    async load() {
        if (!this.sobjectId) return;
        this.loading = true;
        try {
            const items = await getAttachments({ sobjectId: this.sobjectId });
            const mapGroups = {};
            (items || []).forEach(it => {
                const key = it.activityName || 'Outros';
                if (!mapGroups[key]) {
                    mapGroups[key] = [];
                }
                mapGroups[key].push(it);
            });
            this.groups = Object.keys(mapGroups).sort().map(name => ({
                name,
                items: mapGroups[name]
            }));
        } catch (error) {
            // opcional: toast
            console.error(error);
        } finally {
            this.loading = false;
        }
    }

    get hasData() {
        return (this.groups || []).length > 0;
    }
}
