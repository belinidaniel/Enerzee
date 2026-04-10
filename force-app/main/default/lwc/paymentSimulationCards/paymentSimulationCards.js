import { LightningElement, api, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { RefreshEvent } from "lightning/refresh";
import { refreshApex } from "@salesforce/apex";
import { getFieldValue, getRecord, updateRecord } from "lightning/uiRecordApi";
import SELECTED_FIELD from "@salesforce/schema/PaymentSimulation__c.Selected__c";
import SELECTED_SIMULATION_FIELD from "@salesforce/schema/Opportunity.SelectedSimulation__c";
import STAGE_NAME_FIELD from "@salesforce/schema/Opportunity.StageName";
import getSimulationCards from "@salesforce/apex/PaymentSimulationCardController.getSimulationCards";
import createManualSimulation from "@salesforce/apex/PaymentSimulationCardController.createManualSimulation";
import loadProposalData from "@salesforce/apex/ProposalConsoleController.loadProposalData";
import sendProposal from "@salesforce/apex/ProposalConsoleController.sendProposal";

const OPPORTUNITY_FIELDS = [STAGE_NAME_FIELD];
const READJUSTMENT_STAGE = "Readequação de Proposta";
const PAYMENT_TYPE_LABELS = {
  Financing: "Financiamento",
  Rental: "Aluguel Solar"
};

export default class PaymentSimulationCards extends LightningElement {
  @api recordId;

  _wiredResult;
  _wiredProposalData;
  cards = [];
  opportunityRecord;
  pendingSimulationId = null;
  isSaving = false;
  isSimulationModalOpen = false;
  isCreatingSimulation = false;
  baseSimulationId = null;
  draftInstallmentCount = null;
  draftInstallmentAmount = null;
  draftProposalLabel = "";
  draftPaymentType = "";
  defaultTemplateId = null;

  @wire(getRecord, { recordId: "$recordId", fields: OPPORTUNITY_FIELDS })
  wiredOpportunity({ data }) {
    this.opportunityRecord = data;
  }

  @wire(loadProposalData, { opportunityId: "$recordId" })
  wiredProposalData(result) {
    this._wiredProposalData = result;
    if (result.data) {
      this.defaultTemplateId = result.data.defaultTemplateId || null;
    } else if (result.error) {
      this.defaultTemplateId = null;
    }
  }

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

  get canSimulateProposal() {
    return this.hasCards && this.stageName === READJUSTMENT_STAGE;
  }

  get stageName() {
    return getFieldValue(this.opportunityRecord, STAGE_NAME_FIELD);
  }

  get simulationModalSaveDisabled() {
    return (
      this.isCreatingSimulation ||
      !this.draftInstallmentCount ||
      !this.draftInstallmentAmount ||
      Number(this.draftInstallmentCount) <= 0 ||
      Number(this.draftInstallmentAmount) <= 0
    );
  }

  get simulationModalPrimaryLabel() {
    return this.isCreatingSimulation
      ? "Salvando..."
      : "Salvar e gerar proposta";
  }

  get draftPaymentTypeLabel() {
    return PAYMENT_TYPE_LABELS[this.draftPaymentType] || this.draftPaymentType;
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

  handleOpenSimulationModal() {
    const selectedOption = this._getSelectedOrFallbackOption();
    if (!selectedOption) {
      this._showToast(
        "Erro ao abrir simulador",
        "Nenhuma simulação base foi encontrada para esta oportunidade.",
        "error"
      );
      return;
    }

    this.pendingSimulationId = null;
    this.baseSimulationId = selectedOption.id;
    this.draftInstallmentCount = selectedOption.installmentCount;
    this.draftInstallmentAmount = selectedOption.installmentAmount;
    this.draftProposalLabel = selectedOption.proposalLabel;
    this.draftPaymentType = selectedOption.paymentType;
    this.isSimulationModalOpen = true;
  }

  handleCloseSimulationModal(forceClose = false) {
    if (this.isCreatingSimulation && !forceClose) {
      return;
    }

    this.isSimulationModalOpen = false;
    this.baseSimulationId = null;
    this.draftInstallmentCount = null;
    this.draftInstallmentAmount = null;
    this.draftProposalLabel = "";
    this.draftPaymentType = "";
  }

  handleInstallmentCountChange(event) {
    this.draftInstallmentCount = event.detail.value;
  }

  handleInstallmentAmountChange(event) {
    this.draftInstallmentAmount = event.detail.value;
  }

  async handleSaveSimulationProposal() {
    if (this.simulationModalSaveDisabled) {
      return;
    }

    this.isCreatingSimulation = true;
    try {
      const saveResult = await createManualSimulation({
        opportunityId: this.recordId,
        baseSimulationId: this.baseSimulationId,
        installmentCount: Number(this.draftInstallmentCount),
        installmentAmount: Number(this.draftInstallmentAmount)
      });

      let toastTitle = "Simulação atualizada";
      let toastVariant = "success";
      let toastMessage = saveResult?.createdNewSimulation
        ? "Nova simulação criada e selecionada com sucesso."
        : "A simulação existente foi mantida como selecionada.";

      if (this.defaultTemplateId) {
        try {
          const proposalResult = await sendProposal({
            opportunityId: this.recordId,
            coverId: this.defaultTemplateId
          });
          toastMessage =
            proposalResult?.message ||
            "Simulação salva e proposta gerada novamente.";
          if (proposalResult?.success === false) {
            toastTitle = "Simulação salva com alerta";
            toastVariant = "warning";
          }
        } catch (proposalError) {
          toastTitle = "Simulação salva com alerta";
          toastVariant = "warning";
          toastMessage =
            "A simulação foi salva, mas não foi possível gerar a proposta: " +
            this._reduceError(proposalError);
        }
      } else {
        toastTitle = "Simulação salva";
        toastVariant = "warning";
        toastMessage =
          "A simulação foi salva, mas nenhum modelo padrão de proposta foi encontrado para regenerar o PDF.";
      }

      await refreshApex(this._wiredResult);
      if (this._wiredProposalData) {
        await refreshApex(this._wiredProposalData);
      }
      this.pendingSimulationId = null;
      this.handleCloseSimulationModal(true);
      this.dispatchEvent(new RefreshEvent());
      this._showToast(toastTitle, toastMessage, toastVariant);
    } catch (error) {
      this._showToast(
        "Erro ao simular proposta",
        this._reduceError(error),
        "error"
      );
    } finally {
      this.isCreatingSimulation = false;
    }
  }

  _getCurrentSelectedSimulationId() {
    if (!this.cards) return null;
    for (const card of this.cards) {
      if (card.selectedSimulationId) return card.selectedSimulationId;
    }
    return null;
  }

  _getSelectedOrFallbackOption() {
    if (!this.cards?.length) {
      return null;
    }

    const currentSelectedId = this._getCurrentSelectedSimulationId();
    let fallbackOption = null;
    for (const card of this.cards) {
      for (const option of card.options || []) {
        const decoratedOption = {
          ...option,
          proposalLabel: card.proposalLabel,
          paymentType: card.paymentType
        };
        if (!fallbackOption) {
          fallbackOption = decoratedOption;
        }
        if (currentSelectedId && option.id === currentSelectedId) {
          return decoratedOption;
        }
      }
    }

    return fallbackOption;
  }

  _showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }

  _reduceError(error) {
    if (Array.isArray(error?.body)) {
      return error.body.map((item) => item.message).join(", ");
    }
    return error?.body?.message || error?.message || "Erro inesperado.";
  }
}
