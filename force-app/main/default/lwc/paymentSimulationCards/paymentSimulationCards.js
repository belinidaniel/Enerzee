import { LightningElement, api, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";
import { updateRecord } from "lightning/uiRecordApi";
import SELECTED_FIELD from "@salesforce/schema/PaymentSimulation__c.Selected__c";
import getSimulationCards from "@salesforce/apex/PaymentSimulationCardController.getSimulationCards";

export default class PaymentSimulationCards extends LightningElement {
  @api recordId;

  _wiredResult;
  cards = [];

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

  handleOptionSelect(event) {
    const simulationId = event.detail.simulationId;
    updateRecord({
      fields: {
        Id: simulationId,
        [SELECTED_FIELD.fieldApiName]: true
      }
    })
      .then(() => refreshApex(this._wiredResult))
      .catch((err) => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Erro ao selecionar opção",
            message: err.body?.message,
            variant: "error"
          })
        );
      });
  }
}
