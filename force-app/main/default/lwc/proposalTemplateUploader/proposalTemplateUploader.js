import { LightningElement, api, track } from "lwc";

const BASE_URL =
  "https://enerzeeapifile.livelybeach-f3e8be7c.brazilsouth.azurecontainerapps.io/TemplateUpload";

export default class ProposalTemplateUploader extends LightningElement {
  @api recordId;
  @track env = "UAT";

  get envOptions() {
    return [
      { label: "UAT (Homologação)", value: "UAT" },
      { label: "PRD (Produção)", value: "PRD" }
    ];
  }

  get iframeUrl() {
    const envParam = this.env === "PRD" ? "PRD" : "UAT";
    return `${BASE_URL}?env=${envParam}&recordId=${this.recordId}`;
  }

  handleEnvChange(event) {
    this.env = event.detail.value;
    this.refs.templateIframe.setAttribute("src", this.iframeUrl);
  }

  renderedCallback() {
    if (this.refs.templateIframe) {
      this.refs.templateIframe.setAttribute("src", this.iframeUrl);
    }
  }
}
