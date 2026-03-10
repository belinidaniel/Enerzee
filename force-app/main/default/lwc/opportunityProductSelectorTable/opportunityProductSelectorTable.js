import { LightningElement, api } from "lwc";

export default class OpportunityProductSelectorTable extends LightningElement {
  @api products = [];
  @api columns = [];
  @api selectedRowIds = [];
  @api isLoading = false;
  @api showPagination = false;
  @api isPreviousDisabled = false;
  @api isNextDisabled = false;
  @api currentPageLabel = "";

  get hasProducts() {
    return this.products && this.products.length > 0;
  }

  handleRowSelection(event) {
    this.dispatchEvent(
      new CustomEvent("rowselection", { detail: event.detail })
    );
  }

  handlePreviousPage() {
    this.dispatchEvent(new CustomEvent("previouspage"));
  }

  handleNextPage() {
    this.dispatchEvent(new CustomEvent("nextpage"));
  }
}
