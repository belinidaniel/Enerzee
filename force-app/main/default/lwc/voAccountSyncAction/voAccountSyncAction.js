import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import syncAccount from '@salesforce/apex/VOManualSyncController.syncAccount';

export default class VoAccountSyncAction extends LightningElement {
    @api recordId;
    isRunning = false;

    @api async invoke() {
        if (this.isRunning) {
            return;
        }

        this.isRunning = true;

        try {
            const response = await syncAccount({ accountId: this.recordId });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Sincronização VO',
                    message: response && response.message ? response.message : 'Sincronização enfileirada com sucesso.',
                    variant: response && response.success === false ? 'warning' : 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Erro ao sincronizar',
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
            return 'Erro inesperado ao solicitar sincronização com VO.';
        }

        if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        }

        if (typeof error.message === 'string') {
            return error.message;
        }

        return 'Erro inesperado ao solicitar sincronização com VO.';
    }
}
