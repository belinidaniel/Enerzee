import { LightningElement } from 'lwc';

export default class OmniChannelAutoLogin extends LightningElement {
    connectedCallback() {
        this.setPresenceStatus();
    }

    setPresenceStatus() {
        const statusId = '0N55e0000008c2cCAA'; // Substitua pelo ID do Status "Available"

        // Método para alterar o status de presença
        if (sforce && sforce.console && sforce.console.presence) {
            sforce.console.presence.setServicePresenceStatus(statusId, (result) => {
                if (result.success) {
                    console.log('Status definido com sucesso: ' + result.statusName);
                } else {
                    console.error('Erro ao definir o status: ', result);
                }
            });
        } else {
            console.error('API de presença do console não está disponível.');
        }
    }
}