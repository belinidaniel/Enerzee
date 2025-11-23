import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord } from 'lightning/uiRecordApi';
import { getObjectInfo, getPicklistValuesByRecordType } from 'lightning/uiObjectInfoApi';
import updateViability from '@salesforce/apex/ViabilityController.updateViability';
import VIABILITY_OBJECT from '@salesforce/schema/ViabilityStudy__c';
import ADEQUACY_COST_ENERZEE_FIELD from '@salesforce/schema/ViabilityStudy__c.AdequacyCostEnerzee__c';
import ADEQUACY_COST_CLIENT_FIELD from '@salesforce/schema/ViabilityStudy__c.AdequacyCostClient__c';
import OWN_TEAM_FIELD from '@salesforce/schema/ViabilityStudy__c.OwnTeamThirdParty__c';

const FIELDS = [
    'ViabilityStudy__c.EstudoViabilidadeLocal__c',
    'ViabilityStudy__c.Opportunity__c',
    'ViabilityStudy__c.Consultor__c',
    'ViabilityStudy__c.Consultor__r.Name',
    'ViabilityStudy__c.ApproveDate__c',
    'ViabilityStudy__c.AdequacyCostEnerzee__c',
    'ViabilityStudy__c.AdequacyCostClient__c',
    'ViabilityStudy__c.TechnicalVisitCost__c',
    'ViabilityStudy__c.OwnTeamThirdParty__c',
    'ViabilityStudy__c.VisitResponsibleName__c',
    'ViabilityStudy__c.ServiceResource__c',
    'ViabilityStudy__c.RecordTypeId'
];

export default class opportunityViabilityForm extends NavigationMixin(LightningElement) {
    @api recordId;
    id;
    oppId;
    latitude;
    longitude;
    locationAvailable = false;
    AvailableViability = false;
    uploadedFiles = 0;
    telhado = '';
    mapLink = '';
    locationButtonDisabled = false;
    isLoading = false;
    isModalOpen = false;

    consultorId;
    consultorName;
    approvalDate;
    selectedEnerzeeCosts = [];
    selectedClientCosts = [];
    enerzeeCostOptions = [];
    clientCostOptions = [];
    teamPicklistOptions = [];
    teamSelection;
    visitResponsibleName;
    serviceResourceId;
    technicalVisitCost;

    defaultRecordTypeId;
    activeRecordTypeId;

    options = [
        { label: '', value: '' },
        { label: 'Ao solo', value: 'Ao Solo' },
        { label: 'Cerâmico', value: 'Cerâmico' },
        { label: 'Carport', value: 'Carport' },
        { label: 'Fibrocimento (Metálico)', value: 'Fibrocimento (Metálico)' },
        { label: 'Fibrocimento (Madeira)', value: 'Fibrocimento (Madeira)' },
        { label: 'Metálico', value: 'Metálico' },
        { label: 'Laje', value: 'Laje' },
        { label: 'Zipado', value: 'Zipado' },
        { label: 'Shingle', value: 'Shingle' }
    ];

    currentStep = 'Detalhes da Proposta';
    steps = ['Detalhes da Proposta', 'Localização Fixa', 'Dados do Local', 'Finalizado'];

    @wire(CurrentPageReference)
    getPageReference(pageReference) {
        if (pageReference?.state?.id) {
            this.id = pageReference.state.id;
        }
    }

    @wire(getRecord, { recordId: '$id', fields: FIELDS })
    ViabilityStudy__c({ error, data }) {
        if (data) {
            this.oppId = data.fields.Opportunity__c.value;
            this.AvailableViability = !!data.fields.EstudoViabilidadeLocal__c.value;
            this.consultorId = data.fields.Consultor__c.value;
            this.consultorName = data.fields.Consultor__r?.displayValue || data.fields.Consultor__r?.value?.fields?.Name?.value;
            this.approvalDate = data.fields.ApproveDate__c.value;
            this.selectedEnerzeeCosts = this.parseMultiValue(data.fields.AdequacyCostEnerzee__c.value);
            this.selectedClientCosts = this.parseMultiValue(data.fields.AdequacyCostClient__c.value);
            this.teamSelection = data.fields.OwnTeamThirdParty__c.value;
            this.visitResponsibleName = data.fields.VisitResponsibleName__c.value;
            this.serviceResourceId = data.fields.ServiceResource__c.value;
            this.technicalVisitCost = data.fields.TechnicalVisitCost__c.value;
            const recordTypeId = data.fields.RecordTypeId.value;
            if (recordTypeId) {
                this.activeRecordTypeId = recordTypeId;
            }
        } else if (error) {
            this.showNotification('Erro', error.body?.message || 'Não foi possível carregar a viabilidade.', 'error');
        }
    }

    @wire(getObjectInfo, { objectApiName: VIABILITY_OBJECT })
    handleObjectInfo({ data, error }) {
        if (data) {
            this.defaultRecordTypeId = data.defaultRecordTypeId;
            if (!this.activeRecordTypeId) {
                this.activeRecordTypeId = data.defaultRecordTypeId;
            }
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('Erro ao carregar metadados de ViabilityStudy__c', error);
        }
    }

    @wire(getPicklistValuesByRecordType, { objectApiName: VIABILITY_OBJECT, recordTypeId: '$activeRecordTypeId' })
    wiredPicklists({ error, data }) {
        if (data) {
            this.enerzeeCostOptions = this.normalizePicklist(data.picklistFieldValues[ADEQUACY_COST_ENERZEE_FIELD.fieldApiName]);
            this.clientCostOptions = this.normalizePicklist(data.picklistFieldValues[ADEQUACY_COST_CLIENT_FIELD.fieldApiName]);
            this.teamPicklistOptions = this.normalizePicklist(data.picklistFieldValues[OWN_TEAM_FIELD.fieldApiName]);
        } else if (error && this.activeRecordTypeId) {
            this.showNotification('Erro', 'Não foi possível carregar as opções de picklist.', 'error');
        }
    }

    get consultantSelection() {
        return this.consultorId
            ? [
                  {
                      id: this.consultorId,
                      title: this.consultorName || 'Consultor selecionado',
                      subtitle: ''
                  }
              ]
            : [];
    }

    get hasApprovalDate() {
        return !!this.approvalDate;
    }

    get showIntegratorLink() {
        return this.teamSelection === 'Integrador' && (this.serviceResourceId || this.visitResponsibleName);
    }

    get integratorDisplayName() {
        return this.visitResponsibleName || 'Prestador de Serviço';
    }

    get isDetalhesDaProposta() {
        return this.currentStep === 'Detalhes da Proposta';
    }

    get isLocalizacaoFixa() {
        return this.currentStep === 'Localização Fixa';
    }

    get isDadosDoLocal() {
        return this.currentStep === 'Dados do Local';
    }

    get isFinalizado() {
        return this.currentStep === 'Finalizado';
    }

    get showBackButton() {
        return !this.isDetalhesDaProposta && !this.isFinalizado;
    }

    get showContinueButton() {
        return !this.isDadosDoLocal && !this.isFinalizado;
    }

    get showFinishButton() {
        return this.isDadosDoLocal && !this.isFinalizado;
    }

    get isViabilityAvailable() {
        return !this.AvailableViability;
    }

    get currentLocationAsMarker() {
        return [
            {
                location: {
                    Latitude: this.latitude,
                    Longitude: this.longitude
                },
                title: 'Minha localização'
            }
        ];
    }

    handleNextStep() {
        const currentIndex = this.steps.indexOf(this.currentStep);

        if (this.isLocalizacaoFixa && (!this.latitude || !this.longitude)) {
            this.showNotification('Atenção', 'A localização fixa precisa ser obtida antes de continuar.', 'warning');
            return;
        }

        if (currentIndex < this.steps.length - 1) {
            this.currentStep = this.steps[currentIndex + 1];
        }
    }

    handleOpenModal() {
        this.isModalOpen = true;
    }

    handleCloseModal() {
        this.isModalOpen = false;
    }

    handleInputChange(event) {
        this.mapLink = event.target.value;
    }

    extractLatLng(url) {
        try {
            const decodedUrl = decodeURIComponent(url);
            const regex = /[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)/;
            const match = decodedUrl.match(regex);

            if (match) {
                return {
                    latitude: parseFloat(match[1]),
                    longitude: parseFloat(match[2])
                };
            }
            return null;
        } catch (error) {
            // eslint-disable-next-line no-console
            console.error('Erro ao extrair latitude e longitude:', error);
            return null;
        }
    }

    handleExtractAndSave() {
        const coordinates = this.extractLatLng(this.mapLink);
        if (!coordinates) {
            // eslint-disable-next-line no-alert
            alert('Link inválido! Insira um link do Google Maps contendo coordenadas.');
            return;
        }

        this.latitude = coordinates.latitude;
        this.longitude = coordinates.longitude;
        this.handleCloseModal();
    }

    handleGetCurrentLocationClick() {
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    this.latitude = position.coords.latitude;
                    this.longitude = position.coords.longitude;

                    if (this.latitude && this.longitude) {
                        this.locationAvailable = true;
                    } else {
                        this.showNotification('Erro', 'Localização inválida.', 'error');
                    }
                },
                () => {
                    this.showNotification('Erro', 'Não foi possível obter a localização.', 'error');
                }
            );
        } else {
            this.showNotification('Erro', 'Geolocalização não é suportada pelo seu navegador.', 'error');
        }
    }

    handleChange(event) {
        this.telhado = event.detail.value;
        const evt = new CustomEvent('valuechange', {
            detail: this.telhado
        });
        this.dispatchEvent(evt);
    }

    handleConsultantSelected(event) {
        const detail = event.detail || [];
        if (detail.length) {
            this.consultorId = detail[0].id;
            this.consultorName = detail[0].title;
        } else {
            this.consultorId = null;
            this.consultorName = null;
        }
    }

    handleEnerzeeCostChange(event) {
        this.selectedEnerzeeCosts = [...event.detail.value];
    }

    handleClientCostChange(event) {
        this.selectedClientCosts = [...event.detail.value];
    }

    handleTeamChange(event) {
        this.teamSelection = event.detail.value;
    }

    handleTechnicalVisitCostChange(event) {
        const value = event.target.value;
        this.technicalVisitCost = value === '' ? null : parseFloat(value);
    }

    handleOpenServiceProvider() {
        if (!this.serviceResourceId) {
            return;
        }
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.serviceResourceId,
                objectApiName: 'ServiceResource',
                actionName: 'view'
            }
        });
    }

    handleUploadFinished(event) {
        this.uploadedFiles = event.detail.files.length;
        this.showNotification('Sucesso', `${this.uploadedFiles} arquivo(s) carregado(s) com sucesso!`, 'success');
    }

    parseMultiValue(value) {
        if (!value) {
            return [];
        }
        return value
            .split(';')
            .map((item) => item.trim())
            .filter((item) => item);
    }

    formatMultiValue(values) {
        return values && values.length ? values.join(';') : null;
    }

    normalizePicklist(picklistData) {
        if (!picklistData) {
            return [];
        }
        return picklistData.values.map((entry) => ({ label: entry.label, value: entry.value }));
    }

    async handleUpload() {
        if (this.isDadosDoLocal) {
            if (!this.telhado || this.uploadedFiles === 0) {
                if (!this.telhado) {
                    this.showNotification('Atenção', 'Por favor, preencha o campo: Tipo do telhado - Estrutura de fixação, antes de finalizar.', 'warning');
                    return;
                } else if (this.uploadedFiles === 0) {
                    this.showNotification('Atenção', 'Por favor, faça o upload de pelo menos um arquivo antes de finalizar.', 'warning');
                    return;
                }
            }
            if (this.technicalVisitCost !== null && this.technicalVisitCost < 0) {
                this.showNotification('Atenção', 'O custo da visita técnica não pode ser negativo.', 'error');
                return;
            }
        }

        if (this.id) {
            this.isLoading = true;

            try {
                await updateViability({
                    recordId: this.id,
                    latitude: this.latitude,
                    longitude: this.longitude,
                    telhado: this.telhado,
                    consultorId: this.consultorId,
                    adequacyEnerzeeValues: this.formatMultiValue(this.selectedEnerzeeCosts),
                    adequacyClientValues: this.formatMultiValue(this.selectedClientCosts),
                    technicalVisitCost: this.technicalVisitCost,
                    ownTeamThirdParty: this.teamSelection
                });

                this.handleNextStep();
                this.showNotification('Sucesso', 'Registro atualizado com sucesso.', 'success');
            } catch (error) {
                this.showNotification('Erro', `Falha ao atualizar o registro: ${error.body?.message || error.message}`, 'error');
            } finally {
                this.isLoading = false;
            }
        } else {
            this.showNotification('Erro', 'ID do registro não disponível.', 'error');
        }
    }

    showNotification(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}