import { LightningElement, api, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";
import { updateRecord } from "lightning/uiRecordApi";
import SELECTED_FIELD from "@salesforce/schema/PaymentSimulation__c.Selected__c";
import SELECTED_SIMULATION_FIELD from "@salesforce/schema/Opportunity.SelectedSimulation__c";
import getSimulationCards from "@salesforce/apex/PaymentSimulationCardController.getSimulationCards";

export default class PaymentSimulationCards extends LightningElement {
  @api recordId;

  _wiredResult;
  cards = [];
  pendingSimulationId = null;
  isSaving = false;

  @wire(getSimulationCards, { opportunityId: "$recordId" })
  wiredCards(result) {
    this._wiredResult = result;
    if (result.data) {
      this.cards = result.data;
    } else if (result.error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Erro ao carregar simulações",
          message: result.error.body?.message,
          variant: "error"
        })
      );
    }
  }

  get hasCards() {
    return this.cards && this.cards.length > 0;
  }

  get hasPendingSelection() {
    return !!this.pendingSimulationId;
  }

  handleOptionSelect(event) {
    const simulationId = event.detail.simulationId;
    const currentSelectedId = this._getCurrentSelectedSimulationId();
    if (simulationId === currentSelectedId) {
      return;
    }
    this.pendingSimulationId = simulationId;
  }

  handleCancel() {
    this.pendingSimulationId = null;
  }

  handleSave() {
    if (!this.pendingSimulationId || this.isSaving) {
      return;
    }
    this.isSaving = true;
    const opportunityUpdate = updateRecord({
      fields: {
        Id: this.recordId,
        [SELECTED_SIMULATION_FIELD.fieldApiName]: this.pendingSimulationId
      }
    });
    const simulationUpdate = updateRecord({
      fields: {
        Id: this.pendingSimulationId,
        [SELECTED_FIELD.fieldApiName]: true
      }
    });
    Promise.all([opportunityUpdate, simulationUpdate])
      .then(() => refreshApex(this._wiredResult))
      .then(() => {
        this.pendingSimulationId = null;
        this.isSaving = false;
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Simulação salva",
            message: "A simulação selecionada foi atualizada.",
            variant: "success"
          })
        );
      })
      .catch((err) => {
        this.isSaving = false;
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Erro ao salvar simulação",
            message: err.body?.message,
            variant: "error"
          })
        );
      });
  }

  _getCurrentSelectedSimulationId() {
    if (!this.cards) return null;
    for (const card of this.cards) {
      if (card.selectedSimulationId) return card.selectedSimulationId;
    }
    return null;
  }
}
