import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord } from 'lightning/uiRecordApi';
import updateViability from '@salesforce/apex/ViabilityController.updateViability';

const FIELDS = [
    'ViabilityStudy__c.EstudoViabilidadeLocal__c',
    'ViabilityStudy__c.Opportunity__c'
];

export default class opportunityViabilityForm extends LightningElement {
    @api recordId;
    id;
    oppId;
    latitude;
    longitude;
    locationAvailable = false;
    AvailableViability = false;
    fileName = '';
    fileData;
    uploadedFiles = 0;
    telhado = '';
    mapLink = '';
    locationButtonDisabled = false;
    isLoading = false;
    isModalOpen = false;
    
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
        } else if (error) {
            this.showNotification('Erro', error.body.message, 'error');
        }
    }

    @api
    setOptions(optionsList) {
        this.options = optionsList.map(option => ({
            label: option,
            value: option.toLowerCase().replace(/\s/g, '_')
        }));
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
        return [{
            location: {
                Latitude: this.latitude,
                Longitude: this.longitude
            },
            title: 'Minha localização'
        }];
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
            let decodedUrl = decodeURIComponent(url);
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
            console.error("Erro ao extrair latitude e longitude:", error);
            return null;
        }
    }
    
    handleExtractAndSave() {
        const coordinates = this.extractLatLng(this.mapLink);
        if (!coordinates) {
            alert('Link inválido! Insira um link do Google Maps contendo coordenadas.');
            return;
        }

        this.latitude = coordinates.latitude;
        this.longitude = coordinates.longitude;
        this.handleCloseModal();
    }
    
    handleGetCurrentLocationClick() {
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(position => {
                this.latitude = position.coords.latitude;
                this.longitude = position.coords.longitude;

                if (this.latitude && this.longitude) {
                    this.locationAvailable = true;
                } else {
                    this.showNotification('Erro', 'Localização inválida.', 'error');
                }
            }, () => {
                this.showNotification('Erro', 'Não foi possível obter a localização.', 'error');
            });
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

    handleUploadFinished(event) {
        this.uploadedFiles = event.detail.files.length;
        this.showNotification('Sucesso', `${this.uploadedFiles} arquivo(s) carregado(s) com sucesso!`, 'success');
    }
    
    async handleUpload() {
        if (this.isDadosDoLocal) {
            if (!this.telhado || this.uploadedFiles === 0) {
                if (!this.telhado){
                    this.showNotification('Atenção', 'Por favor, preencha o campo: Tipo do telhado - Estrutura de fixação, antes de finalizar.', 'warning');
                    return;
                } else if (this.uploadedFiles === 0){
                    this.showNotification('Atenção', 'Por favor, faça o upload de pelo menos um arquivo antes de finalizar.', 'warning');
                    return;
                } else {
                    this.showNotification('Atenção', 'Por favor, preencha todos os campo antes de finalizar.', 'warning');
                    return;
                }
            }
        }

        if (this.id) {
            this.isLoading = true;
            
            try {
                await updateViability({
                    recordId: this.id,
                    latitude: this.latitude,
                    longitude: this.longitude,
                    telhado: this.telhado
                });
    
                this.handleNextStep();
                this.showNotification('Sucesso', 'Registro atualizado com sucesso.', 'success');

            } catch (error) {
                this.showNotification('Erro', `Falha ao atualizar o registro: ${error.body.message}`, 'error');

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