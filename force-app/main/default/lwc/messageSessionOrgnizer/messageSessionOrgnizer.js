import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import searchRecipients from '@salesforce/apex/MessagingComposerController.searchRecipients';
import getMessagingChannels from '@salesforce/apex/MessagingComposerController.getMessagingChannels';
import sendMessage from '@salesforce/apex/MessagingComposerController.sendMessage';
import getMessagingSessionContext from '@salesforce/apex/MessagingComposerController.getMessagingSessionContext';

const FIXED_TEMPLATES = [
    {
        label: 'Notificação inicial',
        value: 'Notifica_o_inicial',
        text: 'Notificação inicial'
    },
    {
        label: '1 - Iniciar conversa',
        value: 'Iniciar_conversa',
        text: 'Iniciar conversa'
    },
    {
        label: '1 - Iniciar conversa - Consultor',
        value: 'Iniciar_conversa_consultor',
        text: 'Iniciar conversa - Consultor'
    },
    {
        label: '2 - Sessão Inativa - Agente',
        value: 'Sessao_Inativa',
        text: 'Sessão inativa'
    },
    {
        label: '2 - Sessão Inativa - Cliente',
        value: 'Sessao_Inativa_Cliente',
        text: 'Iniciar conversa por inatividade do cliente.'
    },
    {
        label: '2 - Sessão Inativa - Agente - Consultor',
        value: 'sessao_inativa_agente_consultor',
        text: 'Sessão Inativa - Agente - Consultor'
    }
];

export default class MessageSessionOrgnizer extends NavigationMixin(LightningElement) {
    @api recordId;

    channels = [];
    templates = FIXED_TEMPLATES;
    recipientResults = [];
    selectedRecipient;
    selectedTemplateValue;
    selectedTemplateText;
    selectedChannelId;
    sessionInfo;

    recipientSearch = '';
    isLoading = false;

    connectedCallback() {
        this.loadChannels();
        if (this.recordId) {
            this.loadSessionContext();
        }
    }

    async loadChannels() {
        try {
            const data = await getMessagingChannels();
            this.channels = (data || []).map((channel) => ({
                ...channel,
                label: channel.label,
                value: channel.id
            }));
            if (!this.selectedChannelId && this.channels.length > 0) {
                this.selectedChannelId = this.channels[0].value;
            }
        } catch (error) {
            this.handleError('Erro ao carregar canais', error);
        }
    }

    async loadSessionContext() {
        try {
            const info = await getMessagingSessionContext({ recordId: this.recordId });
            if (info) {
                this.sessionInfo = info;
                this.selectedChannelId = info.messagingChannelId;
                this.selectedRecipient = {
                    id: info.messagingEndUserId,
                    messagingEndUserId: info.messagingEndUserId,
                    name: info.endUserName || 'Cliente',
                    phone: info.phone,
                    type: 'MessagingEndUser',
                    messagingChannelId: info.messagingChannelId
                };
                this.recipientResults = this.decorateSelection(
                    [this.selectedRecipient],
                    this.selectedRecipient.id
                );
            }
        } catch (error) {
            this.handleError('Não foi possível identificar a sessão de mensagens.', error);
        }
    }

    handleRecipientSearchChange(event) {
        this.recipientSearch = event.target.value;
    }

    async handleRecipientSearch() {
        if (!this.recipientSearch || this.recipientSearch.trim().length < 2) {
            this.showToast('Busque por ao menos 2 caracteres.', 'warning');
            return;
        }
        this.isLoading = true;
        try {
            const data = await searchRecipients({ searchTerm: this.recipientSearch });
            this.recipientResults = this.decorateSelection(data || [], this.selectedRecipient?.id);
        } catch (error) {
            this.handleError('Erro ao buscar destinatários', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleRecipientSelect(event) {
        const recordId = event.currentTarget.dataset.id;
        const record = this.recipientResults.find((rec) => rec.id === recordId);
        if (record) {
            this.selectedRecipient = record;
            this.recipientResults = this.decorateSelection(this.recipientResults, record.id);
            if (record.messagingChannelId) {
                this.selectedChannelId = record.messagingChannelId;
            }
        }
    }

    handleChannelChange(event) {
        this.selectedChannelId = event.detail.value;
    }

    handleTemplateChange(event) {
        const value = event.detail.value;
        this.selectedTemplateValue = value;
        const template = this.templates.find((tpl) => tpl.value === value);
        this.selectedTemplateText = template ? template.text : null;
    }

    get recipientList() {
        return (this.recipientResults || []).map((rec) => ({
            ...rec,
            cssClass: `tile ${this.selectedRecipient?.id === rec.id ? 'selected' : ''}`
        }));
    }

    get hasRecipients() {
        return (this.recipientResults || []).length > 0;
    }

    async handleSend() {
        if (!this.selectedTemplateValue) {
            this.showToast('Selecione uma mensagem para enviar.', 'warning');
            return;
        }
        if (!this.selectedRecipient) {
            this.showToast('Selecione um destinatário.', 'warning');
            return;
        }
        if (!this.selectedChannelId) {
            this.showToast('Selecione um canal.', 'warning');
            return;
        }

        const payload = {
            recordId: this.recordId,
            messageDefinitionName: this.selectedTemplateValue,
            messagingChannelId: this.selectedChannelId,
            messagingEndUserId: this.selectedRecipient.messagingEndUserId,
            contactId: this.selectedRecipient.type === 'Contact' ? this.selectedRecipient.id : null,
            leadId: this.selectedRecipient.type === 'Lead' ? this.selectedRecipient.id : null,
            accountId: this.selectedRecipient.type === 'Account' ? this.selectedRecipient.id : null,
            phone: this.selectedRecipient.phone,
            allowedSessionStatus: 'Any',
            requestType: 'SendNotificationMessages',
            enforceConsent: true,
            channelConsentType: 'MessagingEndUser'
        };

        this.isLoading = true;
        try {
            const response = await sendMessage({ request: payload });
            const sessionId = response?.messagingSessionId;
            this.showToast('Mensagem enviada', 'success');
            if (sessionId) {
                this.navigateToSession(sessionId);
            }
        } catch (error) {
            this.handleError('Erro ao enviar mensagem', error);
        } finally {
            this.isLoading = false;
        }
    }

    navigateToSession(sessionId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: sessionId,
                objectApiName: 'MessagingSession',
                actionName: 'view'
            }
        });
    }

    decorateSelection(list, selectedId) {
        return (list || []).map((item) => ({
            ...item,
            cssClass: `tile ${selectedId && item.id === selectedId ? 'selected' : ''}`
        }));
    }

    handleError(title, error) {
        const message = this.reduceError(error);
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant: 'error'
            })
        );
    }

    showToast(message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Mensagem',
                message,
                variant: variant || 'info'
            })
        );
    }

    reduceError(error) {
        if (!error) {
            return 'Erro desconhecido.';
        }
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (error.body && error.body.message) {
            return error.body.message;
        }
        if (error.message) {
            return error.message;
        }
        return 'Erro inesperado.';
    }
}