import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchRecipients from '@salesforce/apex/MessagingComposerController.searchRecipients';
import getMessagingChannels from '@salesforce/apex/MessagingComposerController.getMessagingChannels';
import getMessageDefinitions from '@salesforce/apex/MessagingComposerController.getMessageDefinitions';
import sendMessage from '@salesforce/apex/MessagingComposerController.sendMessage';
import getMessagingSessionContext from '@salesforce/apex/MessagingComposerController.getMessagingSessionContext';

export default class MessageSessionOrgnizer extends LightningElement {
    @api recordId;

    channels = [];
    templates = [];
    recipientResults = [];
    selectedRecipient;
    selectedTemplate;
    selectedChannelId;
    sessionInfo;

    recipientSearch = '';
    templateSearch = '';
    isLoading = false;

    connectedCallback() {
        this.loadChannels();
        this.loadTemplates();
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

    async loadTemplates() {
        try {
            const data = await getMessageDefinitions({ searchTerm: null });
            console.log('Templates carregados:', JSON.stringify(data));
            this.templates = (data || []).map((item) => ({ ...item }));
        } catch (error) {
            this.handleError('Erro ao carregar templates', error);
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

    handleTemplateSearchChange(event) {
        this.templateSearch = event.target.value;
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

    handleTemplateSelect(event) {
        const fullName = event.currentTarget.dataset.fullname;
        const template = this.templates.find((tpl) => tpl.fullName === fullName);
        this.selectedTemplate = template;
    }

    get filteredTemplates() {
        const term = (this.templateSearch || '').toLowerCase();
        return (this.templates || [])
            .filter((tpl) => !term || (tpl.fullName && tpl.fullName.toLowerCase().includes(term)))
            .map((tpl) => ({
                ...tpl,
                cssClass: `tile ${this.selectedTemplate?.fullName === tpl.fullName ? 'selected' : ''}`
            }));
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
        if (!this.selectedTemplate) {
            this.showToast('Selecione um template para enviar.', 'warning');
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
            messageDefinitionName: this.selectedTemplate.fullName,
            messagingChannelId: this.selectedChannelId,
            messagingEndUserId: this.selectedRecipient.messagingEndUserId,
            contactId: this.selectedRecipient.type === 'Contact' ? this.selectedRecipient.id : null,
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
            const sessionId = response?.messagingSessionId ? ` (${response.messagingSessionId})` : '';
            this.showToast(`Mensagem enviada${sessionId}`, 'success');
        } catch (error) {
            this.handleError('Erro ao enviar mensagem', error);
        } finally {
            this.isLoading = false;
        }
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
