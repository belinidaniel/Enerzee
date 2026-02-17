import { api, LightningElement, track } from 'lwc';
import recipientsUploadIcon from '@salesforce/resourceUrl/recipientsUploadIcon';
import saveRecipient from '@salesforce/apex/ClickSignController.saveRecipient';
import deleteRecipient from '@salesforce/apex/ClickSignController.deleteRecipient';
import getRecipients from '@salesforce/apex/ClickSignController.getRecipients'; // Backend method to fetch recipients
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LABEL_RECIPIENTS from '@salesforce/label/c.ClickSign_Recipients';
import LABEL_ADD_RECIPIENT from '@salesforce/label/c.ClickSign_AddRecipient';
import LABEL_NO_RECIPIENTS from '@salesforce/label/c.ClickSign_NoRecipients';
import LABEL_NAME from '@salesforce/label/c.ClickSign_FieldName';
import LABEL_EMAIL from '@salesforce/label/c.ClickSign_Email';
import LABEL_ROLE from '@salesforce/label/c.ClickSign_RoleLabel';
import LABEL_SAVE_SUCCESS from '@salesforce/label/c.ClickSign_SaveSuccess';
import LABEL_SAVE_ERROR from '@salesforce/label/c.ClickSign_SaveError';
import LABEL_DELETE_SUCCESS from '@salesforce/label/c.ClickSign_DeleteSuccess';
import LABEL_DELETE_ERROR from '@salesforce/label/c.ClickSign_DeleteError';
import LABEL_MODAL_TITLE from '@salesforce/label/c.ClickSign_ModalTitle';

export default class ClickSignRecipients extends LightningElement {
    @track recipients = [];
    @track isModalOpen = false;
    @track isLoading = false;
    @track recipientName = '';
    @track recipientEmail = '';
    @track recipientRole = '';
    @track recipientDelivery = 'Email';
    @api clickSign;
    @api templateId;
    @api clickSignTemplate;
    @api objectName;
    editingRecipientId = null;

    @track signerType;
    @track userId;
    @track contactId;   
    @track contactsMapping;

    @track jsonContact;

    recipientsUploadIcon = recipientsUploadIcon;
    deliveryOptions = [{ label: 'Email', value: 'Email' }];

    recipientSourceOptions = [
        { label: 'Por Email', value: 'anyContact' },
        { label: 'Contatos do Registro', value: 'recordContacts' },
        { label: 'Usuarios do Salesforce', value: 'salesforceUsers' },
        { label: 'Contatos do Salesforce', value: 'salesforceContacts' }
    ];

    // Role options based on provided values
    roleOptions = [
        { label: 'Assinar como correntista', value: 'account_holder' },
        { label: 'Assinar como contador', value: 'accountant' },
        { label: 'Assinar como administrador', value: 'administrator' },
        { label: 'Assinar para aprovar', value: 'approve' },
        { label: 'Assinar como associado', value: 'associate' },
        { label: 'Assinar como procurador', value: 'attorney' },
        { label: 'Assinar como fiel depositário', value: 'bailee' },
        { label: 'Assinar como comodatário', value: 'borrower' },
        { label: 'Assinar como corretor', value: 'broker' },
        { label: 'Assinar como síndico(a)', value: 'building_manager' },
        { label: 'Assinar como parte compradora', value: 'buyer' },
        { label: 'Assinar como responsável solidário', value: 'co_responsible' },
        { label: 'Assinar como caucionante', value: 'collateral_provider' },
        { label: 'Assinar como comodante', value: 'comforter' },
        { label: 'Assinar como condômino', value: 'condominium_member' },
        { label: 'Assinar como anuído', value: 'consented' },
        { label: 'Assinar como anuente', value: 'consenting' },
        { label: 'Assinar como interveniente anuente', value: 'consenting_intervenor' },
        { label: 'Assinar como consignatário', value: 'consignee' },
        { label: 'Assinar como contratada', value: 'contractee' },
        { label: 'Assinar como contratante', value: 'contractor' },
        { label: 'Assinar como credor', value: 'creditor' },
        { label: 'Assinar como devedor', value: 'debtor' },
        { label: 'Assinar como diretor(a)', value: 'director' },
        { label: 'Assinar como distratado', value: 'distracted' },
        { label: 'Assinar como distratante', value: 'distracting' },
        { label: 'Assinar como empregado', value: 'employee' },
        { label: 'Assinar como empregador', value: 'employer' },
        { label: 'Assinar como endossatário', value: 'endorsee' },
        { label: 'Assinar como endossante', value: 'endorser' },
        { label: 'Assinar como franqueado', value: 'franchisee' },
        { label: 'Assinar como franqueador', value: 'franchisor' },
        { label: 'Assinar como outorgado', value: 'grantee' },
        { label: 'Assinar como outorgante', value: 'grantor' },
        { label: 'Assinar como avalista', value: 'guarantor' },
        { label: 'Assinar como cônjuge do fiador', value: 'guarantor_spouse' },
        { label: 'Assinar como corretor de seguros', value: 'insurance_broker' },
        { label: 'Assinar como segurado', value: 'insured' },
        { label: 'Assinar como intermediário(a)', value: 'intermediary' },
        { label: 'Assinar como interveniente', value: 'intervening' },
        { label: 'Assinar como interveniente garantidor', value: 'intervening_guarantor' },
        { label: 'Assinar como emitente', value: 'issuer' },
        { label: 'Assinar como devedor solidário', value: 'joint_debtor' },
        { label: 'Assinar como advogado', value: 'lawyer' },
        { label: 'Assinar como responsável legal', value: 'legal_guardian' },
        { label: 'Assinar como representante legal', value: 'legal_representative' },
        { label: 'Assinar como mutuante', value: 'lender' },
        { label: 'Assinar como locatário', value: 'lessee' },
        { label: 'Assinar como locador', value: 'lessor' },
        { label: 'Assinar como licenciada', value: 'licensed' },
        { label: 'Assinar como licenciante', value: 'licensor' },
        { label: 'Assinar como gestor', value: 'manager' },
        { label: 'Assinar como proprietário(a)', value: 'owner' },
        { label: 'Assinar como sócio', value: 'partner' },
        { label: 'Assinar como parte', value: 'party' },
        { label: 'Assinar como consignado', value: 'pledged' },
        { label: 'Assinar como presidente', value: 'president' },
        { label: 'Assinar para homologar', value: 'ratify' },
        { label: 'Assinar como corretor de imóveis', value: 'real_estate_broker' },
        { label: 'Assinar para acusar recebimento', value: 'receipt' },
        { label: 'Assinar como morador(a)', value: 'resident' },
        { label: 'Assinar como secretário(a)', value: 'secretary' },
        { label: 'Assinar como afiançado', value: 'secured' },
        { label: 'Assinar como parte vendedora', value: 'seller' },
        { label: 'Assinar como prestador(a) de serviços', value: 'service_provider' },
        { label: 'Apenas assinar', value: 'sign' },
        { label: 'Assinar como fiador', value: 'surety' },
        { label: 'Assinar como vistoriador', value: 'surveyor' },
        { label: 'Assinar como cessionário', value: 'transferee' },
        { label: 'Assinar como cedente', value: 'transferor' },
        { label: 'Assinar como tesoureiro(a)', value: 'treasurer' },
        { label: 'Assinar como validador', value: 'validator' },
        { label: 'Assinar como testemunha', value: 'witness' }
    ];

    labels = {
        LABEL_RECIPIENTS,
        LABEL_ADD_RECIPIENT,
        LABEL_NO_RECIPIENTS,
        LABEL_NAME,
        LABEL_EMAIL,
        LABEL_ROLE,
        LABEL_SAVE_SUCCESS,
        LABEL_SAVE_ERROR,
        LABEL_DELETE_SUCCESS,
        LABEL_DELETE_ERROR,
        LABEL_MODAL_TITLE
    };

    connectedCallback() {
        this.isLoading = true;
        console.log('teeeeeeeeeeste');
        console.log(this.templateId);
        console.log(this.objectName);
        this.loadRecipients();

        if(this.clickSign != null){
            this.recipientSourceOptions = [
                { label: 'Por Email', value: 'anyContact' },
                { label: 'Usuarios do Salesforce', value: 'salesforceUsers' },
                { label: 'Contatos do Salesforce', value: 'salesforceContacts' }
            ];
        
        }
    }

    loadRecipients() {
        this.isLoading = true;
        const recordId = this.clickSign == null ? this.templateId : this.clickSign.Id;
        getRecipients({ recordId: recordId })
            .then((result) => {
                this.recipients = result.map((recipient) => ({
                    Id: recipient.Id,
                    name: recipient.Name || recipient.Contact__r?.Name || recipient.User__r?.Name,
                    email: recipient.Email__c || recipient.Contact__r?.Email || recipient.User__r?.Email,
                    role: recipient.Role__c,
                    roleLabel: this.roleOptions.find(option => option.value === recipient.Role__c)?.label || recipient.Role__c,
                    signerType: recipient.SignerType__c == 'contactId' ? 'Contato Salesforce' : recipient.SignerType__c == 'UserId' ? 'Usuario Salesforce' : recipient.SignerType__c == 'object' ? 'Registro' : recipient.SignerType__c == 'Any' ? 'Qualquer contato' : null,
                    delivery: 'Email' // Static for now
                }));
            })
            .catch((error) => {
                this.showToast('Error', 'Failed to load recipients.', 'error');
                console.error(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    openModal() {
            this.isModalOpen = true
    }

    closeModal() {
        this.isModalOpen = false;
        this.clearModalFields();
    }

    clearModalFields() {
        this.recipientName = '';
        this.recipientEmail = '';
        this.recipientRole = '';
        this.recipientDelivery = 'Email';
        this.editingRecipientId = null;
        this.isRecordInfoSelected = false;
        this.isSearchContactSelected = false;
        this.isSearchUserSelected = false;
        this.isAnyContact = false;
    }

    handleNameChange(event) {
        this.recipientName = event.target.value;
    }

    handleEmailChange(event) {
        this.recipientEmail = event.target.value;
    }

    handleRoleChange(event) {
        this.recipientRole = event.target.value;
    }

    handleDeliveryChange(event) {
        this.recipientDelivery = event.target.value;
    }

    saveRecipient() {
        console.log('isAnyContact:', this.isAnyContact);
        console.log('recipientName:', this.recipientName);
        console.log('recipientEmail:', this.recipientEmail);
        console.log('recipientRole:', this.recipientRole);
        console.log('recipientDelivery:', this.recipientDelivery);
        console.log('editingRecipientId:', this.editingRecipientId);
            
        if (this.isRecordInfoSelected) {
        } else if (this.isSearchContactSelected) {
        } else if (this.isSearchUserSelected){
        } else if (this.isAnyContact) {
        }
        this.save();

    }

    save() {
        if (!this.recipientName || !this.recipientEmail || !this.recipientRole) {
            this.showToast('Error', 'Name, Email Address, and Role are required.', 'error');
            return;
        }

        const existingRecipient = this.recipients.find(recipient => recipient.email === this.recipientEmail);
        if (existingRecipient && existingRecipient.Id !== this.editingRecipientId) {
            this.showToast('Error', 'Recipient with this email already added.', 'error');
            return;
        }

        const roleLabel = this.roleOptions.find(option => option.value === this.recipientRole)?.label || this.recipientRole;

        const newRecipient = {
            name: this.recipientName,
            email: this.recipientEmail,
            role: this.recipientRole,
            roleLabel: roleLabel,
            delivery: this.recipientDelivery,
            signerType: this.signerType,
            userId: this.userId,
            contactId: this.contactId,
            contactsMapping: this.jsonContact,
            Id: this.editingRecipientId || null
        };
        console.log('newRecipient', JSON.stringify(newRecipient));
        console.log('this.clickSign', this.clickSign);
        console.log('this.templateId', this.templateId);

        this.isLoading = true;
        saveRecipient({
            recipient: newRecipient,
            clickSignId: this.clickSign == null ? null : this.clickSign.Id,
            templateId: this.templateId,
        })
            .then((savedRecipient) => {
                console.log('savedRecipient', JSON.stringify(savedRecipient));
                if (this.editingRecipientId) {
                    this.recipients = this.recipients.map((recipient) =>
                        recipient.Id === this.editingRecipientId ? savedRecipient : recipient
                    );
                } else {
                    newRecipient.Id = savedRecipient.Id;
                    this.recipients = [...this.recipients, { ...newRecipient, type: 'Any' }];
                }
                this.showToast('Success', 'Recipient saved successfully.', 'success');
                this.closeModal();
                this.isLoading = false;
            })
            .catch((error) => {
                this.showToast('Error', 'Failed to save recipient.', 'error');
                console.error(error);
                this.isLoading = false;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    isRecordInfoSelected = false;
    isSearchContactSelected = false;
    isSearchUserSelected = false;
    isAnyContact = false;
    handleRecipientSourceChange(event){
        this.signerType =null;

        const source = event.target.value;
        this.isRecordInfoSelected = source === 'recordContacts';
        this.isAnyContact = source === 'anyContact';
        this.isSearchContactSelected = source === 'salesforceContacts';
        this.isSearchUserSelected = source === 'salesforceUsers';
        
        if (this.isAnyContact) {
            this.signerType = 'Any';
        } else if (this.isRecordInfoSelected) {
            this.signerType = 'object';
        } else if (this.isSearchContactSelected) {
            this.signerType = 'contactId';
        } else if (this.isSearchUserSelected) {
            this.signerType = 'UserId';
        }

        console.log('this.signerType', this.signerType);
    }

    editRecipient(event) {
        const recipientId = event.currentTarget.dataset.id;
        const recipient = this.recipients.find((rec) => rec.Id === recipientId);
        if (recipient) {
            this.recipientName = recipient.name;
            this.recipientEmail = recipient.email;
            this.recipientRole = recipient.role;
            this.recipientDelivery = recipient.delivery;
            this.editingRecipientId = recipientId;
            this.openModal();
        }
    }

    handleContactSelected(event){
        // Save each information in a variable
        this.contactId =event.detail[0].id;
        this.recipientEmail =event.detail[0].subtitle;
        this.recipientName =event.detail[0].title;
    }

    handleUserSelected(event) {
        console.log('handleSelected');
        console.log(JSON.stringify(event.detail));

        // Save each information in a variable
        this.userId =event.detail[0].id;
        this.recipientEmail =event.detail[0].subtitle;
        this.recipientName =event.detail[0].title;
    }

    handleContactFieldsChange(event){
        this.jsonContact = '';
        this.jsonContact = JSON.stringify(event.detail[0]);
        console.log('jsonContact',  this.jsonContact);
        const contact = event.detail[0];
        this.recipientName = contact.relatedField != undefined ? contact.labelFieldName +' - '+contact.relatedField : null
        this.recipientEmail = contact.labelRelatedField +'@email.com';
        this.recipientRole = contact.labelRoleField;
        console.log('jsonContact',  this.jsonContact);
    }

    deleteRecipient(event) {
        this.isLoading = true;
        const recipientId = event.currentTarget.dataset.id;
        deleteRecipient({ recipientId :  event.currentTarget.dataset.id }).then(() => {
                this.recipients = this.recipients.filter((recipient) => recipient.Id !== recipientId);
                this.showToast('Success', LABEL_DELETE_SUCCESS, 'success');
                this.isLoading = false;
            }).catch((error) => {
                this.showToast('Error', LABEL_DELETE_ERROR, 'error');
                console.error(error);
            }).finally(() => {
                this.isLoading = false;
            });
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({ title, message, variant });
        this.dispatchEvent(event);
        this.notifyParent(title, message, variant);
    }

    notifyParent(title, message, variant) {
        this.dispatchEvent(
            new CustomEvent('notify', {
                detail: { title, message, variant },
                bubbles: true,
                composed: true
            })
        );
    }

    get hasRecipients() {
        return this.recipients.length > 0;
    }
}