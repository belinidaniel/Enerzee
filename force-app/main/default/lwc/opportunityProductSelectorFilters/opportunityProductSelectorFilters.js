import { LightningElement, api } from "lwc";

export default class OpportunityProductSelectorFilters extends LightningElement {
  @api searchText = "";
  @api showAllRegions = false;
  @api selectedRegion = "";
  @api selectedStructureType = "";
  @api selectedKitPromotional = "";
  @api regionOptions = [];
  @api structureTypeOptions = [];
  @api kitPromotionalOptions = [];
  @api disabled = false;
  @api disableRegionFilter = false;
  @api selectedCount = 0;
  @api showSelectedOnly = false;

  get selectedToggleLabel() {
    return this.showSelectedOnly
      ? "Voltar aos resultados"
      : `Mostrar selecionados (${this.selectedCount})`;
  }

  get canToggleSelected() {
    return this.selectedCount > 0;
  }

  handleSearchInput(event) {
    this.dispatchEvent(
      new CustomEvent("searchchange", {
        detail: { value: event.detail?.value ?? event.target?.value ?? "" }
      })
    );
  }

  handleShowAllRegionsChange(event) {
    this.dispatchEvent(
      new CustomEvent("allregionschange", {
        detail: { checked: event.target.checked }
      })
    );
  }

  handleRegionFilterChange(event) {
    this.dispatchEvent(
      new CustomEvent("regionchange", {
        detail: { value: event.detail?.value ?? "" }
      })
    );
  }

  handleStructureTypeFilterChange(event) {
    this.dispatchEvent(
      new CustomEvent("structuretypechange", {
        detail: { value: event.detail?.value ?? "" }
      })
    );
  }

  handleKitPromotionalFilterChange(event) {
    this.dispatchEvent(
      new CustomEvent("kitpromotionalchange", {
        detail: { value: event.detail?.value ?? "" }
      })
    );
  }

  handleToggleShowSelected() {
    if (!this.canToggleSelected) {
      return;
    }
    this.dispatchEvent(new CustomEvent("toggleselected"));
  }
}
