import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { FlowNavigationNextEvent } from 'lightning/flowSupport';
import searchRecipients from '@salesforce/apex/MessagingComposerController.searchRecipients';
import getMessagingChannels from '@salesforce/apex/MessagingComposerController.getMessagingChannels';
import sendMessageJson from '@salesforce/apex/MessagingComposerController.sendMessageJson';
import getMessagingSessionContext from '@salesforce/apex/MessagingComposerController.getMessagingSessionContext';

const FIXED_TEMPLATES = [
    {
        label: 'Notificação inicial',
        value: 'Notifica_o_inicial',
        text: 'Notificação inicial',
        preview: 'Olá, {{1}}!\nAqui é {{2}} da Enerzee. Tudo bem?'
    },
    {
        label: '1 - Iniciar conversa',
        value: 'Iniciar_conversa',
        text: 'Iniciar conversa',
        preview: 'Olá, {{1}}!\nAqui é {{2}} da Enerzee. Tudo bem?'
    },
    {
        label: '1 - Iniciar conversa - Consultor',
        value: 'Iniciar_conversa_consultor',
        text: 'Iniciar conversa - Consultor',
        preview: 'Olá, {{1}}!\nAqui é {{2}} da Enerzee. Tudo bem?'
    },
    {
        label: '2 - Sessão Inativa - Agente',
        value: 'Sessao_Inativa',
        text: 'Sessão inativa',
        preview:
            'Olá, {{1}}!\nTudo bem?\nAqui é {{2}} do atendimento da Enerzee. Vimos que nossa conversa foi encerrada automaticamente, mas estou aqui para ajudar com o que precisar. Caso ainda tenha alguma dúvida ou informação, é só me chamar!'
    },
    {
        label: '2 - Sessão Inativa - Cliente',
        value: 'Sessao_Inativa_Cliente',
        text: 'Iniciar conversa por inatividade do cliente.',
        preview:
            'Olá, {{1}}!\nTudo bem?\nNossa conversa foi encerrada automaticamente, mas o atendimento da Enerzee segue à disposição para te ajudar.\nSe precisar de algo ou tiver dúvidas, é só responder aqui!'
    },
    {
        label: '2 - Sessão Inativa - Agente - Consultor',
        value: 'sessao_inativa_agente_consultor',
        text: 'Sessão Inativa - Agente - Consultor',
        preview:
            'Olá, {{1}}!\nTudo bem?\nAqui é {{2}} do atendimento da Enerzee. Vimos que nossa conversa foi encerrada automaticamente, mas estou aqui para ajudar com o que precisar. Caso ainda tenha alguma dúvida ou informação, é só me chamar!'
    }
];

export default class MessageSessionOrgnizer extends NavigationMixin(LightningElement) {
    @api recordId;
    @api availableActions; // fornecido pelo Flow Screen
    // Propriedades expostas ao Flow: serão preenchidas no envio para alimentar o subflow
    @api messageDefinitionName;
    @api messagingChannelId;
    @api messagingEndUserId;

    channels = [];
    templates = FIXED_TEMPLATES;
    recipientResults = [];
    selectedRecipient;
    selectedTemplateValue;
    selectedTemplateText;
    selectedChannelId;
    sessionInfo;
    searchTimeout;

    recipientSearch = '';
    isLoading = false;

    connectedCallback() {
        // Pré-seleciona o primeiro template para evitar envio sem template.
        if (this.templates && this.templates.length > 0 && !this.selectedTemplateValue) {
            const first = this.templates[0];
            this.selectedTemplateValue = first.value;
            this.selectedTemplateText = first.preview || first.text || first.label;
        }
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

    handleRecipientSearchInput(event) {
        this.recipientSearch = event.target.value;
        this.scheduleRecipientSearch();
    }

    scheduleRecipientSearch() {
        if (this.searchTimeout) {
            clearTimeout(this.searchTimeout);
        }
        const term = this.recipientSearch ? this.recipientSearch.trim() : '';
        if (!term || term.length < 2) {
            this.recipientResults = [];
            return;
        }
        this.searchTimeout = setTimeout(() => this.handleRecipientSearch(), 300);
    }

    async handleRecipientSearch() {
        const term = this.recipientSearch ? this.recipientSearch.trim() : '';
        if (!term || term.length < 2) {
            this.showToast('Busque por ao menos 2 caracteres.', 'warning');
            return;
        }
        this.isLoading = true;
        try {
            const data = await searchRecipients({ searchTerm: term });
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
            this.recipientResults = this.decorateSelection([record], record.id);
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
        this.selectedTemplateText = template ? template.preview || template.text || template.label : null;
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
        const templateValue = (this.selectedTemplateValue || this.templates?.[0]?.value || '').trim();
        if (!templateValue) {
            this.showToast('Selecione uma mensagem para enviar.', 'warning');
            return;
        }
        // Se o template estava vazio mas existe um default, garante que o combobox reflita o valor usado.
        this.selectedTemplateValue = templateValue;

        if (!this.selectedRecipient) {
            this.showToast('Selecione um destinatário.', 'warning');
            return;
        }
        if (!this.selectedChannelId) {
            this.showToast('Selecione um canal.', 'warning');
            return;
        }

        const endUserId = this.selectedRecipient.messagingEndUserId || this.selectedRecipient.id;

        // Preenche propriedades expostas ao Flow Screen
        this.messageDefinitionName = templateValue;
        this.messagingChannelId = this.selectedChannelId;
        this.messagingEndUserId = endUserId;

        // Se estiver rodando dentro de um Flow, delega para o Next para o subflow executar o envio.
        if (this.availableActions && this.availableActions.includes('NEXT')) {
            this.dispatchEvent(new FlowNavigationNextEvent());
            return;
        }

        // Fallback para uso fora de Flow: envia via Apex diretamente.
        const payload = {
            recordId: this.recordId,
            messageDefinitionName: templateValue,
            messagingChannelId: this.selectedChannelId,
            messagingEndUserId: endUserId,
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
            const response = await sendMessageJson({ requestJson: JSON.stringify(payload) });
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
