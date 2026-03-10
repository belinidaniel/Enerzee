import { LightningElement, api } from "lwc";
import { CloseActionScreenEvent } from "lightning/actions";
import { RefreshEvent } from "lightning/refresh";

export default class OpportunityProductSelectorAction extends LightningElement {
  @api recordId;

  handleClose() {
    this.dispatchEvent(new CloseActionScreenEvent());
  }

  handleAdded() {
    this.dispatchEvent(new RefreshEvent());
  }
}
