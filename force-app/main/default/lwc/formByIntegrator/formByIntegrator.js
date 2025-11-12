import { LightningElement, track } from 'lwc';
import createCase from '@salesforce/apex/CommunityFormController.createCase';
import saveFile from '@salesforce/apex/CommunityFormController.saveFile';
import createContentVersion from '@salesforce/apex/CommunityFormController.createContentVersion';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class FormByIntegrator extends LightningElement {
    @track formData = {
        nome: '',
        email: '',
        telefone: '',
        estado: '',
        cidade: '',
        mensagem: '',
        indicadoConsultor: 'false',
        tornarConsultor: false,
        nomeConsultor: '',
        emailConsultor: '',
        beConsultant: 'false',
        consultEndicator: '',
        emailConsult: ''
    };
    @track uploadedFiles = {};
    @track encodedFiles = {};
    @track isLoading = false;
    @track showSuccessMessage = false;

    stateOptions = [
        { label: 'Acre', value: 'AC' },
        { label: 'Alagoas', value: 'AL' },
        { label: 'Amapá', value: 'AP' },
        { label: 'Amazonas', value: 'AM' },
        { label: 'Bahia', value: 'BA' },
        { label: 'Ceará', value: 'CE' },
        { label: 'Distrito Federal', value: 'DF' },
        { label: 'Espírito Santo', value: 'ES' },
        { label: 'Goiás', value: 'GO' },
        { label: 'Maranhão', value: 'MA' },
        { label: 'Mato Grosso', value: 'MT' },
        { label: 'Mato Grosso do Sul', value: 'MS' },
        { label: 'Minas Gerais', value: 'MG' },
        { label: 'Pará', value: 'PA' },
        { label: 'Paraíba', value: 'PB' },
        { label: 'Paraná', value: 'PR' },
        { label: 'Pernambuco', value: 'PE' },
        { label: 'Piauí', value: 'PI' },
        { label: 'Rio de Janeiro', value: 'RJ' },
        { label: 'Rio Grande do Norte', value: 'RN' },
        { label: 'Rio Grande do Sul', value: 'RS' },
        { label: 'Rondônia', value: 'RO' },
        { label: 'Roraima', value: 'RR' },
        { label: 'Santa Catarina', value: 'SC' },
        { label: 'São Paulo', value: 'SP' },
        { label: 'Sergipe', value: 'SE' },
        { label: 'Tocantins', value: 'TO' }
    ];

    yesNoOptions = [
        { label: 'Sim', value: 'true' },
        { label: 'Não', value: 'false' }
    ];

    get showConsultorFields() {
        return this.formData.beConsultant === 'true';
    }

    handleInputChange(event) {
        const field = event.target.name;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.formData[field] = value;
    }

    handleFileChange(event) {
        const fieldName = event.target.name;
        const files = event.target.files;

        if (files.length > 0) {
            this.encodedFiles[fieldName] = [];
            this.uploadedFiles[fieldName] = [];

            Array.from(files).forEach(file => {
                const reader = new FileReader();
                reader.onload = () => {
                    this.encodedFiles[fieldName].push({
                        content: reader.result.split(',')[1],
                        name: file.name
                    });
                    this.uploadedFiles[fieldName].push(file.name);
                };
                reader.readAsDataURL(file);
            });
        }
    }

    handleSubmit() {
        const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox')]
            .reduce((validSoFar, input) => validSoFar && input.checkValidity(), true);

        if (!allValid) {
            this.showToast('Erro', 'Por favor, preencha todos os campos obrigatórios.', 'error');
            return;
        }

        this.isLoading = true;

        const payload = {
            ...this.formData
        };

        createCase({ payload: JSON.stringify(payload) })
            .then(caseId => {
                window.scrollTo(0, 0); // Scroll to the top of the page
                this.showToast('Sucesso', 'Caso criado com sucesso!', 'success');
                return this.uploadFiles(caseId);
            })
            .then(() => {
                this.showSuccessMessage = true; // Show success message
            })
            .catch(error => {
                this.showToast('Erro', 'Erro ao criar caso: ' + error.body.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    uploadFiles(caseId) {
        const listFileId = [];

        const uploadFile = (fileData) => {
            return saveFile({ fileDataMap: fileData, caseId })
                .then(fileId => {
                    console.log(`Arquivo ${fileData.name} carregado com ID: ${fileId}`);
                    listFileId.push(fileId);
                });
        };

        const uploadAllFiles = async () => {
            for (const fieldName of Object.keys(this.encodedFiles)) {
                const files = this.encodedFiles[fieldName];
                for (const fileData of files) {
                    await uploadFile(fileData);
                }
            }
        };

        return uploadAllFiles()
            .then(() => {
                return createContentVersion({ contentVersionId: listFileId, linkedEntityId: caseId });
            })
            .catch(error => {
                this.showToast('Erro', 'Erro ao carregar arquivos: ' + error.body.message, 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}

window.addEventListener("load", function () {
    console.log("Window load event triggered");

    function enviarAltura() {
        console.log("Sending height:", document.documentElement.scrollHeight);
        window.parent.postMessage({ height: document.documentElement.scrollHeight }, "*");
    }

    enviarAltura(); // Enviar altura inicial
    window.addEventListener("resize", function () {
        console.log("Window resize event triggered");
        enviarAltura(); // Atualizar altura quando redimensionar
    });
});