import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import syncOpportunity from '@salesforce/apex/VOManualSyncController.syncOpportunity';

export default class VoOpportunitySyncAction extends LightningElement {
    @api recordId;
    isRunning = false;

    @api async invoke() {
        if (this.isRunning) {
            return;
        }

        this.isRunning = true;

        try {
            const response = await syncOpportunity({ opportunityId: this.recordId });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Envio para VO',
                    message: response && response.message ? response.message : 'Envio enfileirado com sucesso.',
                    variant: response && response.success === false ? 'warning' : 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Erro ao enviar para VO',
                    message: this.reduceError(error),
                    variant: 'error'
                })
            );
        } finally {
            this.isRunning = false;
        }
    }

    reduceError(error) {
        if (!error) {
            return 'Erro inesperado ao enviar Opportunity para VO.';
        }

        if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        }

        if (typeof error.message === 'string') {
            return error.message;
        }

        return 'Erro inesperado ao enviar Opportunity para VO.';
    }
}
