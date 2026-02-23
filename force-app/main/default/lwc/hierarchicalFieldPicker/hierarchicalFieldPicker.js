import { LightningElement, api, track } from 'lwc';
import getObjectFieldsPage from '@salesforce/apex/DataSourceController.getObjectFieldsPage';
import getEmailField from '@salesforce/apex/DataSourceController.getEmailField';
import ClickSign_SelectField from '@salesforce/label/c.ClickSign_SelectField';
import ClickSign_SelectNameField from '@salesforce/label/c.ClickSign_SelectNameField';
import ClickSign_SelectEmailField from '@salesforce/label/c.ClickSign_SelectEmailField';
import ClickSign_SelectRoleField from '@salesforce/label/c.ClickSign_SelectRoleField';
import ClickSign_SelectedField from '@salesforce/label/c.ClickSign_SelectedField';
import ClickSign_SelectedRelatedField from '@salesforce/label/c.ClickSign_SelectedRelatedField';
import ClickSign_RelationshipFields from '@salesforce/label/c.ClickSign_RelationshipFields';
import ClickSign_LookupFields from '@salesforce/label/c.ClickSign_LookupFields';
import ClickSign_SelectRelatedField from '@salesforce/label/c.ClickSign_SelectRelatedField';

export default class HierarchicalFieldPicker extends LightningElement {
    @api label; // Label for the picklist
    @api options = []; // Case Fields
    @api optionsRelationship = []; // Relationship Fields
    @api optionsRelated = []; // Lookup Fields
    @api selectedValue = ''; // Currently selected value
    @api selectedRelatedField = ''; // Stores the selected related field
    @api objectName;
    @api labelFieldName = ''; // Label of the selected field
    @api labelRelatedField = ''; // Label of the selected related field
    @api relatedObjectName = ''; // Name of the related object (from JSON)
    @api jsonData; // JSON data to populate fields

    @track isDropdownVisible = false; // Tracks dropdown visibility
    @track relatedFields = []; // Stores fields of related object
    @track showRelatedField = false; // Toggle for related field dropdown
    @api isContactInfo = false;
    @api emailField;
    @api labelEmailField;
    @api labelRoleField;
    @api roleValueField;
    @track emailFields = [];
    @track selectedRoleField = '';

    labels = {
        selectField: ClickSign_SelectField,
        selectNameField: ClickSign_SelectNameField,
        selectEmailField: ClickSign_SelectEmailField,
        selectRoleField: ClickSign_SelectRoleField,
        selectedField: ClickSign_SelectedField,
        selectedRelatedField: ClickSign_SelectedRelatedField,
        relationshipFields: ClickSign_RelationshipFields,
        lookupFields: ClickSign_LookupFields,
        selectRelatedField: ClickSign_SelectRelatedField
    };

    connectedCallback() {
        console.log('isContactInfo,', this.isContactInfo);
        document.addEventListener('click', this.closeDropdown.bind(this));

        // If a related field exists, show the related field dropdown
        if (this.labelRelatedField) {
            this.showRelatedField = true;
        }

        // If there's a related object, fetch its fields
        if (this.relatedObjectName) {
            this.fetchRelatedFields(this.relatedObjectName);
        }

        // Parse JSON data and populate fields
        if (this.jsonData) {
            this.populateFieldsFromJson(this.jsonData);
        }

        if (this.roleValueField) {
            this.selectedRoleField = this.roleValueField;
        }
    }

    disconnectedCallback() {
        document.removeEventListener('click', this.closeDropdown.bind(this));
    }

    renderedCallback() {
        this.ensureRelatedObject();
        this.syncSelectValues();
    }

    handleFieldChange(event) {
        const selectedValue = event.target.value;
        const selectedIndex = event.target.selectedIndex;
        const selectedOption = event.target.options[selectedIndex];
        this.labelRelatedField  = '';

        this.selectedValue = selectedValue;
        this.labelFieldName = selectedOption.text; // Store the label of the selected field

        const relatedObjectName = selectedOption.dataset.relatedObject || null;
        this.relatedObjectName = relatedObjectName;
        this.showRelatedField = relatedObjectName !== null;

        if (relatedObjectName || this.isContactInfo) {
            this.fetchRelatedFields(relatedObjectName);
        }
        if(this.isContactInfo){
            this.getEmailField(relatedObjectName);
        }

        if(!this.isContactInfo){
            this.dispatchSelectionEvent();
        }else{
            this.dispatchContactEvent();
        }
    }

    handleRelatedFieldChange(event) {
        const selectedField = event.target.value;
        const selectedIndex = event.target.selectedIndex;
        const selectedOption = event.target.options[selectedIndex];

        this.selectedRelatedField = selectedField;
        this.labelRelatedField = selectedOption.text; // Store the label of the selected related field

        this.dispatchSelectionEvent();
    }

    handleContactChange(event) {
        const selectedField = event.target.value;
        const targetid = event.target.id;
        const selectedIndex = event.target.selectedIndex;
        const selectedOption = event.target.options[selectedIndex];

        console.log('Selected id:', targetid);
        console.log('Selected Field:', selectedField);
        console.log('Selected Index:', selectedIndex);
        
        if (targetid.includes('Name')) {
            console.log('Selected Option--------------------------', selectedOption);
            this.selectedRelatedField = selectedField;
            this.labelRelatedField = selectedOption.text;
        } else if (targetid.includes('Email')) {
            this.emailField = selectedField;
            this.labelEmailField = selectedOption.text;
        } else if (targetid.includes('Role')) {
            this.selectedRoleField = selectedField;
            this.labelRoleField = selectedField;
        }

        this.dispatchContactEvent();
    }

    fetchRelatedFields(relatedObjectName) {
        getObjectFieldsPage({ objectName: relatedObjectName })
            .then((result) => {
                this.relatedFields = result.objectFields.map((field) => ({
                    label: field.label,
                    apiName: field.apiName,
                }));

                // If selectedRelatedField exists, ensure it remains selected
                if (this.selectedRelatedField) {
                    this.showRelatedField = true;
                    
                }
            })
            .catch((error) => {
                console.error('Error fetching related fields:', error);
            });
    }

    getEmailField(relatedObjectName) {
        this.showEmailFields = false;
        console.log('getEmailField', relatedObjectName);
        getEmailField({ objectName: relatedObjectName })
            .then((result) => {
                console.log('getEmailField', JSON.stringify(result));
                this.emailFields = result.map((field) => ({
                    label: field.label,
                    apiName: field.apiName,
                }));
            })
            .catch((error) => {
                console.error('Error fetching related fields:',JSON.stringify(error));
            });
    }

    populateFieldsFromJson(jsonData) {
        const data = JSON.parse(jsonData);
        data.forEach(item => {
            if (item.labelFieldName) {
                this.labelFieldName = item.labelFieldName;
            }
            if (item.relationshipField) {
                this.relatedObjectName = item.relationshipField;
                this.showRelatedField = true;
                this.fetchRelatedFields(this.relatedObjectName);
            }
            if (item.labelRelatedField) {
                this.labelRelatedField = item.labelRelatedField;
            }
        });
    }

    dispatchSelectionEvent() {
        this.dispatchEvent(
            new CustomEvent('selectionchange', {
                detail: {
                    objectName: this.objectName,
                    relatedObject: this.relatedObjectName,
                    fieldName: this.selectedValue,
                    labelFieldName: this.labelFieldName, // Send the field label
                    relatedField: this.selectedRelatedField,
                    labelRelatedField: this.labelRelatedField, // Send the related field label
                },
            })
        );
    }

    dispatchContactEvent() {
        console.log('this.selectedRelatedField',this.selectedRelatedField);
        console.log('this.labelRelatedField',this.labelRelatedField);
        this.dispatchEvent(
            new CustomEvent('selectioncontactchange', {
                detail: {
                    objectName: this.objectName,
                    fieldName: this.selectedValue,
                    relatedField: this.selectedRelatedField,
                    labelRelatedField: this.labelRelatedField,
                    labelFieldName: this.labelFieldName, // Send the field label
                    emailField: this.emailField,
                    labelEmailField: this.labelEmailField, // Send the related field label
                    roleValueField: this.selectedRoleField,
                    labelRoleField: this.labelRoleField // Send the role field label
                },
            })
        );
    }

    ensureRelatedObject() {
        if (this.isContactInfo || this.relatedObjectName || !this.selectedValue) {
            return;
        }
        const relationshipOption = (this.optionsRelationship || []).find(
            (option) => option.apiName === this.selectedValue
        );
        if (relationshipOption && relationshipOption.relatedObject) {
            this.relatedObjectName = relationshipOption.relatedObject;
            this.showRelatedField = true;
            this.fetchRelatedFields(this.relatedObjectName);
        }
    }

    syncSelectValues() {
        const mainSelect = this.template.querySelector('select[data-role="main"]');
        if (mainSelect && this.selectedValue && mainSelect.value !== this.selectedValue) {
            mainSelect.value = this.selectedValue;
        }

        const relatedSelect = this.template.querySelector('select[data-role="related"]');
        if (relatedSelect && this.selectedRelatedField && relatedSelect.value !== this.selectedRelatedField) {
            relatedSelect.value = this.selectedRelatedField;
        }

        const contactNameSelect = this.template.querySelector('select[data-role="contact-name"]');
        if (contactNameSelect && this.selectedRelatedField && contactNameSelect.value !== this.selectedRelatedField) {
            contactNameSelect.value = this.selectedRelatedField;
        }

        const contactEmailSelect = this.template.querySelector('select[data-role="contact-email"]');
        if (contactEmailSelect && this.emailField && contactEmailSelect.value !== this.emailField) {
            contactEmailSelect.value = this.emailField;
        }

        const contactRoleSelect = this.template.querySelector('select[data-role="contact-role"]');
        if (contactRoleSelect && this.selectedRoleField && contactRoleSelect.value !== this.selectedRoleField) {
            contactRoleSelect.value = this.selectedRoleField;
        }
    }

    closeDropdown() {
        this.isDropdownVisible = false;
    }

    stopPropagation(event) {
        event.stopPropagation(); // Prevent event from closing the dropdown when interacting inside it
    }

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

}