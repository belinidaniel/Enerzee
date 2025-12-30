import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import searchRecipients from '@salesforce/apex/MessagingComposerController.searchRecipients';
import getMessagingSessionContext from '@salesforce/apex/MessagingComposerController.getMessagingSessionContext';
import prepareSessionAndLaunchFlow from '@salesforce/apex/MessagingComposerController.prepareSessionAndLaunchFlow';

const CHANNEL_OPTIONS = [
    { key: 'AFTERSALES', label: '+55 11 4003-8852 (Pós-vendas)', phone: '+55 11 4003-8852', developerName: 'AFTERSALES' },
    { key: 'SALES', label: '+55 11 4003-8344 (vendas)', phone: '+55 11 4003-8344', developerName: 'SALES' }
];

const TYPE_BADGES = {
    Lead: { label: 'Lead', className: 'tag tag-lead' },
    Contact: { label: 'Contact', className: 'tag tag-contact' },
    Account: { label: 'Account', className: 'tag tag-account' },
    Opportunity: { label: 'Opportunity', className: 'tag tag-opportunity' },
    MessagingEndUser: { label: 'Messaging End User', className: 'tag tag-meu' },
    Other: { label: 'Other', className: 'tag tag-other' }
};

const FIXED_TEMPLATES = [
    {
        label: '1 - Iniciar conversa',
        value: '01_Iniciar_conversa',
        text: '01 - Iniciar conversa',
        preview: 'Olá, {{1}}!\nAqui é {{2}} da Enerzee. Tudo bem?'
    },
    {
        label: '2 - Sessão inativa por falta de interação',
        value: '02_Sessao_Inativa',
        text: '02 - Sessão inativa por falta de interação',
        preview:
            'Olá, {{1}}!\nTudo bem?\nNossa conversa foi encerrada automaticamente, mas o atendimento da Enerzee segue à disposição para te ajudar.\nSe precisar de algo ou tiver dúvidas, é só responder aqui!'
    }
];

export default class MessageSessionOrgnizer extends NavigationMixin(LightningElement) {
    @api recordId;
    // Propriedades expostas ao Flow (mantidas para compatibilidade)
    @api messageDefinitionName;
    @api messagingChannelId;
    @api messagingEndUserId;
    @api messagingEndUserRecordTypeDeveloperName;

    channels = CHANNEL_OPTIONS.map((ch) => ({ label: ch.label, value: ch.key }));
    templates = [];
    recipientResults = [];
    selectedRecipient;
    selectedRecipientId;
    selectedTemplateValue;
    selectedTemplateText;
    selectedChannelKey;
    selectedChannelPhone;
    sessionInfo;
    searchTimeout;
    hideChannel = false;

    recipientSearch = '';
    isLoading = false;
    templatesLoading = false; // mantido por compatibilidade de UI

    connectedCallback() {
        const defaultChannel = CHANNEL_OPTIONS[0];
        if (defaultChannel) {
            this.selectedChannelKey = defaultChannel.key;
            this.selectedChannelPhone = defaultChannel.phone;
            this.loadTemplates();
        }
        if (this.recordId) {
            this.loadSessionContext();
        }
    }

    async loadSessionContext() {
        try {
            const info = await getMessagingSessionContext({ recordId: this.recordId });
            if (info) {
                this.sessionInfo = info;
                const mappedChannel = this.resolveChannelKeyFromDeveloperName(info.channelDeveloperName);
                if (mappedChannel) {
                    this.selectedChannelKey = mappedChannel.key;
                    this.selectedChannelPhone = mappedChannel.phone;
                    this.loadTemplates();
                }
                this.selectedRecipient = {
                    id: info.messagingEndUserId,
                    messagingEndUserId: info.messagingEndUserId,
                    name: info.endUserName || 'Cliente',
                    phone: info.phone,
                    type: 'MessagingEndUser',
                    messagingChannelId: info.messagingChannelId,
                    recordTypeDeveloperName: info.messagingEndUserRecordTypeDeveloperName
                };
                this.selectedRecipientId = info.messagingEndUserId;
                this.messagingEndUserRecordTypeDeveloperName = info.messagingEndUserRecordTypeDeveloperName;
                this.recipientResults = this.decorateSelection(
                    [this.selectedRecipient],
                    this.selectedRecipient.id
                );
            }
        } catch (error) {
            this.handleError('Não foi possível identificar a sessão de mensagens.', error);
        }
    }

    resolveChannelKeyFromDeveloperName(developerName) {
        if (!developerName) {
            return null;
        }
        const found = CHANNEL_OPTIONS.find(
            (item) => item.developerName && item.developerName.toLowerCase() === developerName.toLowerCase()
        );
        return found ? { key: found.key, phone: found.phone } : null;
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
            const sorted = [...(data || [])].sort((a, b) => {
                if (a.type === b.type) {
                    return 0;
                }
                if (a.type === 'MessagingEndUser') {
                    return -1;
                }
                if (b.type === 'MessagingEndUser') {
                    return 1;
                }
                return 0;
            });
            this.recipientResults = this.decorateSelection(sorted, this.selectedRecipient?.id);
        } catch (error) {
            this.handleError('Erro ao buscar destinatários', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleRecipientSelect(event) {
        const recordId = event.currentTarget.dataset.id;
        // eslint-disable-next-line no-console
        console.log('MSO handleRecipientSelect clicked id', recordId);
        const record = this.recipientResults.find((rec) => rec.id === recordId);
        if (record) {
            this.selectedRecipient = record;
            this.selectedRecipientId = record.id;
            this.recipientResults = this.decorateSelection([record], record.id);
            this.messagingEndUserRecordTypeDeveloperName =
                record.type === 'MessagingEndUser' ? record.recordTypeDeveloperName || null : null;
            // Preenche messagingEndUserId se vier vazio
            if (!this.selectedRecipient.messagingEndUserId) {
                this.selectedRecipient.messagingEndUserId = this.selectedRecipient.id;
            }
            this.hideChannel = record.type === 'MessagingEndUser' && !!record.messagingChannelId;
            // Se for MEU com canal, mantemos o canal atual (já validado no Apex)
            if (record.messagingChannelDeveloperName) {
                const mapped = CHANNEL_OPTIONS.find(
                    (ch) =>
                        ch.developerName &&
                        ch.developerName.toLowerCase() === record.messagingChannelDeveloperName.toLowerCase()
                );
                if (mapped) {
                    this.selectedChannelKey = mapped.key;
                    this.selectedChannelPhone = mapped.phone;
                }
            }
        }
        // eslint-disable-next-line no-console
        console.log('MSO handleRecipientSelect selectedRecipient', JSON.stringify(this.selectedRecipient));
    }

    handleChannelChange(event) {
        const selectedKey = event.detail.value;
        const channel = CHANNEL_OPTIONS.find((ch) => ch.key === selectedKey);
        this.selectedChannelKey = selectedKey;
        this.selectedChannelPhone = channel ? channel.phone : null;
        this.selectedTemplateValue = null;
        this.selectedTemplateText = null;
        this.loadTemplates();
    }

    loadTemplates() {
        this.templatesLoading = true;
        this.templates = FIXED_TEMPLATES;
        if (this.templates.length > 0) {
            const first = this.templates[0];
            this.selectedTemplateValue = first.value;
            this.selectedTemplateText = first.preview || first.text || first.label;
        }
        this.templatesLoading = false;
    }

    handleTemplateChange(event) {
        const value = event.detail.value;
        this.selectedTemplateValue = value;
        const template = this.templates.find((tpl) => tpl.value === value);
        this.selectedTemplateText = template ? template.preview || template.text || template.label : null;
    }

    get recipientList() {
        return (this.recipientResults || []).map((rec) => {
            const typeMeta = TYPE_BADGES[rec.type] || TYPE_BADGES.Other;
            return {
                ...rec,
                cssClass: `tile ${
                    this.selectedRecipientId === rec.id || this.selectedRecipient?.id === rec.id ? 'selected' : ''
                }`,
                badgeClass: typeMeta.className,
                badgeLabel: typeMeta.label
            };
        });
    }

    get hasRecipients() {
        return (this.recipientResults || []).length > 0;
    }

    get channelOptions() {
        return this.channels;
    }

    get showChannelSelector() {
        return !this.hideChannel;
    }

    async handleSend() {
        const templateValue = (this.selectedTemplateValue || '').trim();
        // Try to recover selected recipient by id or selection flag
        if (!this.selectedRecipient && this.selectedRecipientId) {
            const fromId = (this.recipientResults || []).find((rec) => rec.id === this.selectedRecipientId);
            if (fromId) {
                this.selectedRecipient = fromId;
            }
        }
        if (!this.selectedRecipient) {
            const selectedFromList = (this.recipientResults || []).find((rec) =>
                rec.cssClass && rec.cssClass.includes('tile')
            );

            if (selectedFromList) {
                this.selectedRecipient = selectedFromList;
                this.selectedRecipientId = selectedFromList.id;
            }
        }

        // eslint-disable-next-line no-console
        console.log('MSO handleSend selection from selectedRecipient', JSON.stringify(this.selectedRecipient));
        if (!this.selectedRecipient) {
            this.showToast('Selecione um destinatário', 'warning');
            return;
        }
        const isMessagingEndUser = this.selectedRecipient?.type === 'MessagingEndUser';
        if (!isMessagingEndUser && !this.selectedChannelKey) {
            this.showToast('Selecione um canal', 'warning');
            return;
        }
        if (!templateValue) {
            this.showToast('Selecione uma mensagem', 'warning');
            return;
        }

        this.selectedTemplateValue = templateValue;
        this.messageDefinitionName = templateValue;

        this.isLoading = true;
        try {
            const recipientPayload = this.buildRecipientPayload(this.selectedRecipient);
            // eslint-disable-next-line no-console
            console.log('MSO handleSend calling Apex with', {
                recipient: recipientPayload,
                channelKey: this.selectedChannelKey,
                channelPhone: this.selectedChannelPhone,
                templateValue
            });
            const response = await prepareSessionAndLaunchFlow({
                recipientJson: JSON.stringify(recipientPayload),
                channelKey: this.selectedChannelKey,
                channelPhone: this.selectedChannelPhone,
                selectedMessageComponentName: templateValue
            });

            this.messagingChannelId = response?.messagingChannelId;
            this.messagingEndUserId = response?.messagingEndUserId;
            this.messagingEndUserRecordTypeDeveloperName = response?.messagingEndUserRecordTypeDeveloperName;

            this.showToast('Mensagem enviada via Flow', 'success');
            const sessionId = response?.messagingSessionId;
            if (sessionId) {
                this.navigateToSession(sessionId);
            } else {
                throw new Error('Não foi possível criar/recuperar a sessão de mensagens.');
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

    buildRecipientPayload(recipient) {
        if (!recipient) {
            return null;
        }
        return {
            id: recipient.id,
            messagingEndUserId: recipient.messagingEndUserId || recipient.id,
            messagingChannelId: recipient.messagingChannelId,
            name: recipient.name,
            phone: recipient.phone,
            type: recipient.type,
            detail: recipient.detail,
            recordTypeDeveloperName: recipient.recordTypeDeveloperName
        };
    }
}
