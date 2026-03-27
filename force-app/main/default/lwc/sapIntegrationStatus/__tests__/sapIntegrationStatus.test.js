import { createElement } from "lwc";
import SapIntegrationStatus from "c/sapIntegrationStatus";
import { registerLdsTestWireAdapter } from "@salesforce/wire-service-jest-util";
import { getRecord } from "lightning/uiRecordApi";

const mockGetRecord = registerLdsTestWireAdapter(getRecord);

const RECORD_ID = "0065g00000TESTID";
const OBJECT_API_NAME = "Opportunity";

function buildRecord(sucesso, statusBody) {
  return {
    fields: {
      SucessoIntegracaoSAP__c: { value: sucesso },
      StatusBodyIntegracaoSAP__c: { value: statusBody }
    }
  };
}

function createComponent(
  recordId = RECORD_ID,
  objectApiName = OBJECT_API_NAME
) {
  const element = createElement("c-sap-integration-status", {
    is: SapIntegrationStatus
  });
  element.recordId = recordId;
  element.objectApiName = objectApiName;
  document.body.appendChild(element);
  return element;
}

afterEach(() => {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
});

// ── Success state ─────────────────────────────────────────────────────────────
describe("success state", () => {
  it("renders success banner when SucessoIntegracaoSAP__c is true", async () => {
    const element = createComponent();
    mockGetRecord.emit(buildRecord(true, null));
    await Promise.resolve();

    const banner = element.shadowRoot.querySelector(".sap-banner_success");
    expect(banner).not.toBeNull();
  });

  it('displays "Integrado ao SAP" label', async () => {
    const element = createComponent();
    mockGetRecord.emit(buildRecord(true, null));
    await Promise.resolve();

    const label = element.shadowRoot.querySelector(".banner-label");
    expect(label.textContent).toBe("Integrado ao SAP");
  });

  it("shows OK badge", async () => {
    const element = createComponent();
    mockGetRecord.emit(buildRecord(true, null));
    await Promise.resolve();

    const badge = element.shadowRoot.querySelector(".status-badge");
    expect(badge.textContent).toBe("OK");
  });

  it("does not render error accordion", async () => {
    const element = createComponent();
    mockGetRecord.emit(buildRecord(true, null));
    await Promise.resolve();

    const accordion = element.shadowRoot.querySelector("lightning-accordion");
    expect(accordion).toBeNull();
  });
});

// ── Failure state ─────────────────────────────────────────────────────────────
describe("failure state", () => {
  const errorBody = '{"codigoHttp":500,"mensagem":"Internal Server Error"}';

  it("renders error banner when SucessoIntegracaoSAP__c is false", async () => {
    const element = createComponent();
    mockGetRecord.emit(buildRecord(false, errorBody));
    await Promise.resolve();

    const banner = element.shadowRoot.querySelector(".sap-banner_error");
    expect(banner).not.toBeNull();
  });

  it('displays "Falha na integração" label', async () => {
    const element = createComponent();
    mockGetRecord.emit(buildRecord(false, errorBody));
    await Promise.resolve();

    const label = element.shadowRoot.querySelector(".banner-label");
    expect(label.textContent).toBe("Falha na integração");
  });

  it("shows ERRO badge", async () => {
    const element = createComponent();
    mockGetRecord.emit(buildRecord(false, errorBody));
    await Promise.resolve();

    const badge = element.shadowRoot.querySelector(".status-badge");
    expect(badge.textContent).toBe("ERRO");
  });

  it("renders accordion with error details", async () => {
    const element = createComponent();
    mockGetRecord.emit(buildRecord(false, errorBody));
    await Promise.resolve();

    const accordion = element.shadowRoot.querySelector("lightning-accordion");
    expect(accordion).not.toBeNull();
  });

  it("displays error body text inside pre", async () => {
    const element = createComponent();
    mockGetRecord.emit(buildRecord(false, errorBody));
    await Promise.resolve();

    const pre = element.shadowRoot.querySelector(".error-pre");
    expect(pre.textContent).toBe(errorBody);
  });
});

// ── Pending state ─────────────────────────────────────────────────────────────
describe("pending state", () => {
  it("renders pending banner when SucessoIntegracaoSAP__c is null", async () => {
    const element = createComponent();
    mockGetRecord.emit(buildRecord(null, null));
    await Promise.resolve();

    const banner = element.shadowRoot.querySelector(".sap-banner_pending");
    expect(banner).not.toBeNull();
  });

  it('displays "Não integrado" label', async () => {
    const element = createComponent();
    mockGetRecord.emit(buildRecord(null, null));
    await Promise.resolve();

    const label = element.shadowRoot.querySelector(".banner-label");
    expect(label.textContent).toBe("Não integrado");
  });

  it("shows PENDENTE badge", async () => {
    const element = createComponent();
    mockGetRecord.emit(buildRecord(null, null));
    await Promise.resolve();

    const badge = element.shadowRoot.querySelector(".status-badge");
    expect(badge.textContent).toBe("PENDENTE");
  });

  it("renders pulse ring animation element", async () => {
    const element = createComponent();
    mockGetRecord.emit(buildRecord(null, null));
    await Promise.resolve();

    const pulse = element.shadowRoot.querySelector(".pulse-ring");
    expect(pulse).not.toBeNull();
  });
});

// ── Wire field mapping ────────────────────────────────────────────────────────
describe("wire field mapping", () => {
  it("requests fields for the given objectApiName", async () => {
    createComponent(RECORD_ID, "Kit_Instalacao__c");
    await Promise.resolve();

    const config = mockGetRecord.getLastConfig();
    expect(config.fields).toContain(
      "Kit_Instalacao__c.SucessoIntegracaoSAP__c"
    );
    expect(config.fields).toContain(
      "Kit_Instalacao__c.StatusBodyIntegracaoSAP__c"
    );
  });

  it("updates fields when objectApiName changes", async () => {
    const element = createComponent(RECORD_ID, "Opportunity");
    await Promise.resolve();

    element.objectApiName = "Account";
    await Promise.resolve();

    const config = mockGetRecord.getLastConfig();
    expect(config.fields).toContain("Account.SucessoIntegracaoSAP__c");
  });
});

// ── Wire error handling ───────────────────────────────────────────────────────
describe("wire error handling", () => {
  it("shows error message when wire returns error", async () => {
    const element = createComponent();
    mockGetRecord.emitError({ body: { message: "Campo não encontrado" } });
    await Promise.resolve();

    const errorDiv = element.shadowRoot.querySelector(".slds-text-color_error");
    expect(errorDiv).not.toBeNull();
    expect(errorDiv.textContent).toBe("Campo não encontrado");
  });

  it("hides banner when wire returns error", async () => {
    const element = createComponent();
    mockGetRecord.emitError({ body: { message: "erro" } });
    await Promise.resolve();

    const banner = element.shadowRoot.querySelector(".sap-banner");
    expect(banner).toBeNull();
  });
});

// ── Loading state ─────────────────────────────────────────────────────────────
describe("loading state", () => {
  it("shows spinner before wire resolves", () => {
    const element = createComponent();
    const spinner = element.shadowRoot.querySelector("lightning-spinner");
    expect(spinner).not.toBeNull();
  });

  it("hides spinner after wire resolves", async () => {
    const element = createComponent();
    mockGetRecord.emit(buildRecord(true, null));
    await Promise.resolve();

    const spinner = element.shadowRoot.querySelector("lightning-spinner");
    expect(spinner).toBeNull();
  });
});
