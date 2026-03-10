import { LightningElement, api } from "lwc";

export default class OpportunityProductSelectorEditor extends LightningElement {
  @api products = [];

  handleFieldChange(event) {
    const entryId = event.target.dataset.entryId;
    const fieldName = event.target.dataset.field;
    const value = event.detail?.value ?? event.target?.value ?? "";

    this.dispatchEvent(
      new CustomEvent("fieldchange", {
        detail: { entryId, fieldName, value }
      })
    );
  }

  handleRemoveItem(event) {
    const entryId = event.currentTarget?.dataset?.entryId;
    if (!entryId) {
      return;
    }
    this.dispatchEvent(new CustomEvent("removeitem", { detail: { entryId } }));
  }
}
